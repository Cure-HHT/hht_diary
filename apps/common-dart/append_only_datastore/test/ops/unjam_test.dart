import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/ops/unjam.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';

/// Fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Read every row in [destinationId]'s FIFO store, in
/// `sequence_in_queue` ascending order. Used to assert which rows survived
/// the unjam and which were deleted.
Future<List<Map<String, Object?>>> _readAllFifoRows(
  SembastBackend backend,
  String destinationId,
) async {
  final db = backend.debugDatabase();
  final records =
      await sembast.StoreRef<int, Map<String, Object?>>(
        'fifo_$destinationId',
      ).find(
        db,
        finder: sembast.Finder(
          sortOrders: [sembast.SortOrder('sequence_in_queue')],
        ),
      );
  return records.map((r) => Map<String, Object?>.from(r.value)).toList();
}

/// Set up a destination with a mix of sent / exhausted / pending FIFO rows.
/// Event sequence numbers are assigned contiguously starting at 1, in this
/// order: sent rows first, then exhausted, then pending. So with
/// `sentCount=2, exhaustedCount=3, pendingCount=4` the rows carry
/// `event_id_range.last_seq`es 1, 2 (sent), 3, 4, 5 (exhausted), 6, 7, 8, 9
/// (pending).
///
/// The destination is added to a fresh `DestinationRegistry`, its
/// `startDate` is set to a past date so fillBatch would normally promote,
/// and then its FIFO is seeded directly via `enqueueSingle` with
/// `markFinal(status)` calls to land rows in the three final states.
/// `fill_cursor` is advanced to the last enqueued row's sequence_number
/// so tests have a concrete baseline to compare against post-unjam.
Future<
  ({
    SembastBackend backend,
    DestinationRegistry registry,
    FakeDestination destination,
  })
>
_setupDestinationWithMixedFifo(
  SembastBackend backend, {
  required int sentCount,
  required int exhaustedCount,
  required int pendingCount,
}) async {
  final registry = DestinationRegistry(backend: backend);
  final destination = FakeDestination(id: 'unjam-dest');
  await registry.addDestination(destination);
  // Give the destination a past startDate so it is active; tests that
  // require deactivation call `registry.deactivateDestination(...)` later.
  await registry.setStartDate(destination.id, DateTime.utc(2026, 1, 1));

  var seq = 0;
  // Sent rows.
  for (var i = 0; i < sentCount; i++) {
    seq += 1;
    await enqueueSingle(
      backend,
      destination.id,
      eventId: 'sent-e$seq',
      sequenceNumber: seq,
    );
    await backend.markFinal(destination.id, 'sent-e$seq', FinalStatus.sent);
  }
  // Exhausted rows.
  for (var i = 0; i < exhaustedCount; i++) {
    seq += 1;
    await enqueueSingle(
      backend,
      destination.id,
      eventId: 'exh-e$seq',
      sequenceNumber: seq,
    );
    await backend.markFinal(destination.id, 'exh-e$seq', FinalStatus.exhausted);
  }
  // Pending rows.
  for (var i = 0; i < pendingCount; i++) {
    seq += 1;
    await enqueueSingle(
      backend,
      destination.id,
      eventId: 'pending-e$seq',
      sequenceNumber: seq,
    );
  }
  // fill_cursor tracks the last enqueued row's sequence_number so the
  // test can verify the rewind observably moves it backwards.
  if (seq > 0) {
    await backend.writeFillCursor(destination.id, seq);
  }
  return (backend: backend, registry: registry, destination: destination);
}

void main() {
  group('unjamDestination()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('unjam-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00131-A — unjam on an active destination throws
    // StateError. Active = endDate null or endDate > now. Must be
    // deactivated first.
    test(
      'REQ-d00131-A: unjam on active destination throws StateError',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 0,
          exhaustedCount: 0,
          pendingCount: 1,
        );
        // Destination is active (startDate in past, endDate null).
        await expectLater(
          unjamDestination(
            setup.destination.id,
            registry: setup.registry,
            backend: backend,
          ),
          throwsStateError,
        );
      },
    );

    // Verifies: REQ-d00131-A — unjam on a destination whose endDate is
    // strictly after `now()` (scheduled-close-in-future) also throws.
    test(
      'REQ-d00131-A: unjam with future endDate still throws StateError',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 0,
          exhaustedCount: 0,
          pendingCount: 1,
        );
        // Set endDate well into the future. The destination is still
        // active at `now()`, so unjam MUST still refuse.
        await setup.registry.setEndDate(
          setup.destination.id,
          DateTime.now().add(const Duration(days: 30)),
        );
        await expectLater(
          unjamDestination(
            setup.destination.id,
            registry: setup.registry,
            backend: backend,
          ),
          throwsStateError,
        );
      },
    );

    // Verifies: REQ-d00131-B+C — inside one transaction, unjam deletes
    // every FIFO row where final_status == pending, and leaves every row
    // where final_status == exhausted untouched. `sent` rows are also
    // preserved (audit trail).
    test('REQ-d00131-B+C: unjam deletes pending rows and preserves '
        'exhausted rows', () async {
      final setup = await _setupDestinationWithMixedFifo(
        backend,
        sentCount: 2,
        exhaustedCount: 3,
        pendingCount: 4,
      );
      await setup.registry.deactivateDestination(setup.destination.id);
      final result = await unjamDestination(
        setup.destination.id,
        registry: setup.registry,
        backend: backend,
      );
      expect(result.deletedPending, 4);

      final rows = await _readAllFifoRows(backend, setup.destination.id);
      expect(rows.length, 5); // 2 sent + 3 exhausted; no pending left
      expect(
        rows
            .where((r) => r['final_status'] == FinalStatus.sent.toJson())
            .length,
        2,
      );
      expect(
        rows
            .where((r) => r['final_status'] == FinalStatus.exhausted.toJson())
            .length,
        3,
      );
      expect(
        rows
            .where((r) => r['final_status'] == FinalStatus.pending.toJson())
            .length,
        0,
      );
    });

    // Verifies: REQ-d00131-D — unjam rewinds fill_cursor to the max of
    // event_id_range.last_seq among rows whose final_status == sent.
    // With sentCount=2 (seq 1-2), the rewind value is 2.
    test(
      "REQ-d00131-D: unjam rewinds fill_cursor to last sent row's last_seq",
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 2,
          exhaustedCount: 3,
          pendingCount: 4,
        );
        await setup.registry.deactivateDestination(setup.destination.id);
        // Pre-unjam cursor was advanced to 9 (the last enqueued seq).
        expect(await backend.readFillCursor(setup.destination.id), 9);

        final result = await unjamDestination(
          setup.destination.id,
          registry: setup.registry,
          backend: backend,
        );
        expect(result.rewoundTo, 2);
        expect(await backend.readFillCursor(setup.destination.id), 2);
      },
    );

    // Verifies: REQ-d00131-D — when no `sent` rows exist, the rewind
    // target is `-1` (pre-start sentinel), regardless of how many
    // exhausted / pending rows sit in the FIFO.
    test(
      'REQ-d00131-D: unjam rewinds fill_cursor to -1 when no sent rows exist',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 0,
          exhaustedCount: 2,
          pendingCount: 2,
        );
        await setup.registry.deactivateDestination(setup.destination.id);
        // Pre-unjam cursor advanced to the last enqueued seq (4).
        expect(await backend.readFillCursor(setup.destination.id), 4);

        final result = await unjamDestination(
          setup.destination.id,
          registry: setup.registry,
          backend: backend,
        );
        expect(result.rewoundTo, -1);
        expect(await backend.readFillCursor(setup.destination.id), -1);
      },
    );

    // Verifies: REQ-d00131-E — UnjamResult carries both deletedPending
    // and rewoundTo, populated from the transaction's observations.
    test(
      'REQ-d00131-E: UnjamResult returns deletedPending and rewoundTo',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 1,
          exhaustedCount: 1,
          pendingCount: 3,
        );
        await setup.registry.deactivateDestination(setup.destination.id);
        final result = await unjamDestination(
          setup.destination.id,
          registry: setup.registry,
          backend: backend,
        );
        expect(result, isA<UnjamResult>());
        expect(result.deletedPending, 3);
        expect(result.rewoundTo, 1); // only one sent row at seq 1
      },
    );
  });
}
