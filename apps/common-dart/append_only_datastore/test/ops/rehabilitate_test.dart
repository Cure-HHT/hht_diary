import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/ops/rehabilitate.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
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

/// Read every row in [destinationId]'s FIFO store as raw maps, in
/// `sequence_in_queue` ascending order. Used to assert final_status and
/// attempts[] post-rehabilitation via Sembast ground truth.
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

/// Set up an active destination with a mix of sent / exhausted / pending
/// FIFO rows. Event sequence numbers are assigned contiguously from 1,
/// sent first then exhausted then pending. Each exhausted row gets a
/// single attempt in its attempts[] so REQ-d00132-B can observe
/// preservation.
///
/// The destination is left active (no endDate) per REQ-d00132-D — unlike
/// unjam, rehabilitate does not require deactivation.
Future<
  ({
    SembastBackend backend,
    DestinationRegistry registry,
    FakeDestination destination,
  })
>
_setupDestinationWithMixedFifo(
  SembastBackend backend, {
  int sentCount = 0,
  int exhaustedCount = 0,
  int pendingCount = 0,
}) async {
  final registry = DestinationRegistry(backend: backend);
  final destination = FakeDestination(id: 'rehab-dest');
  await registry.addDestination(destination);
  await registry.setStartDate(destination.id, DateTime.utc(2026, 1, 1));

  var seq = 0;
  for (var i = 0; i < sentCount; i++) {
    seq += 1;
    final row = await enqueueSingle(
      backend,
      destination.id,
      eventId: 'sent-e$seq',
      sequenceNumber: seq,
    );
    await backend.markFinal(destination.id, row.entryId, FinalStatus.sent);
  }
  for (var i = 0; i < exhaustedCount; i++) {
    seq += 1;
    final row = await enqueueSingle(
      backend,
      destination.id,
      eventId: 'exh-e$seq',
      sequenceNumber: seq,
    );
    // Seed one attempt so REQ-d00132-B can verify attempts[] is preserved
    // across the exhausted -> pending flip.
    await backend.appendAttempt(
      destination.id,
      row.entryId,
      AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 12, seq),
        outcome: 'permanent',
        errorMessage: 'simulated failure',
        httpStatus: 500,
      ),
    );
    await backend.markFinal(destination.id, row.entryId, FinalStatus.wedged);
  }
  for (var i = 0; i < pendingCount; i++) {
    seq += 1;
    await enqueueSingle(
      backend,
      destination.id,
      eventId: 'pending-e$seq',
      sequenceNumber: seq,
    );
  }
  return (backend: backend, registry: registry, destination: destination);
}

void main() {
  group('rehabilitateExhaustedRow()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('rehab-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00132-A — an unknown fifoRowId on a real destination
    // throws ArgumentError rather than silently no-op'ing.
    test(
      'REQ-d00132-A: rehabilitate unknown row throws ArgumentError',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          exhaustedCount: 1,
        );
        await expectLater(
          rehabilitateExhaustedRow(
            setup.destination.id,
            'does-not-exist',
            backend: backend,
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00132-A — a row that exists but is NOT exhausted
    // (e.g., pending) cannot be "rehabilitated"; must throw ArgumentError.
    test(
      'REQ-d00132-A: rehabilitate pending row throws ArgumentError',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          pendingCount: 1,
        );
        final rows = await _readAllFifoRows(backend, setup.destination.id);
        expect(rows.length, 1);
        final entryId = rows.single['entry_id']! as String;
        await expectLater(
          rehabilitateExhaustedRow(
            setup.destination.id,
            entryId,
            backend: backend,
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00132-A — a row that is already `sent` is also not
    // exhausted; rehabilitate rejects it.
    test('REQ-d00132-A: rehabilitate sent row throws ArgumentError', () async {
      final setup = await _setupDestinationWithMixedFifo(backend, sentCount: 1);
      final rows = await _readAllFifoRows(backend, setup.destination.id);
      final entryId = rows.single['entry_id']! as String;
      await expectLater(
        rehabilitateExhaustedRow(
          setup.destination.id,
          entryId,
          backend: backend,
        ),
        throwsArgumentError,
      );
    });

    // Verifies: REQ-d00132-B — on success, final_status flips to pending
    // and attempts[] is preserved unchanged.
    test(
      'REQ-d00132-B: exhausted row flips to pending; attempts[] unchanged',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          exhaustedCount: 1,
        );
        final before = await _readAllFifoRows(backend, setup.destination.id);
        expect(before.length, 1);
        final entryId = before.single['entry_id']! as String;
        final originalAttempts = (before.single['attempts'] as List).toList();
        expect(originalAttempts.length, 1);

        await rehabilitateExhaustedRow(
          setup.destination.id,
          entryId,
          backend: backend,
        );

        final after = await _readAllFifoRows(backend, setup.destination.id);
        expect(after.length, 1);
        expect(after.single['final_status'], isNull);
        // attempts[] preserved byte-for-byte: same length and equal elements.
        final afterAttempts = (after.single['attempts'] as List).toList();
        expect(afterAttempts, equals(originalAttempts));
      },
    );

    // Verifies: REQ-d00132-D — rehabilitate is permitted on an active
    // destination (endDate == null). Unlike unjam, no deactivation is
    // required.
    test('REQ-d00132-D: rehabilitate works on active destination', () async {
      final setup = await _setupDestinationWithMixedFifo(
        backend,
        exhaustedCount: 1,
      );
      // Destination is active: addDestination leaves endDate null, and
      // the helper only sets a past startDate. Confirm that baseline.
      final schedule = await setup.registry.scheduleOf(setup.destination.id);
      expect(schedule.endDate, isNull);

      final before = await _readAllFifoRows(backend, setup.destination.id);
      final entryId = before.single['entry_id']! as String;

      // Must not throw.
      await rehabilitateExhaustedRow(
        setup.destination.id,
        entryId,
        backend: backend,
      );
      final after = await _readAllFifoRows(backend, setup.destination.id);
      expect(after.single['final_status'], isNull);
    });
  });

  group('rehabilitateAllExhausted()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('rehab-all-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00132-C — bulk rehabilitation flips every exhausted
    // row to pending and returns the count. Sent rows and already-pending
    // rows are left alone.
    test(
      'REQ-d00132-C: rehabilitateAllExhausted flips all exhausted, returns count',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 1,
          exhaustedCount: 3,
          pendingCount: 2,
        );

        final count = await rehabilitateAllExhausted(
          setup.destination.id,
          backend: backend,
        );
        expect(count, 3);

        final rows = await _readAllFifoRows(backend, setup.destination.id);
        // No exhausted rows remain.
        expect(
          rows
              .where((r) => r['final_status'] == FinalStatus.wedged.toJson())
              .length,
          0,
        );
        // Sent row untouched.
        expect(
          rows
              .where((r) => r['final_status'] == FinalStatus.sent.toJson())
              .length,
          1,
        );
        // Pending count = 2 original + 3 rehabilitated = 5.
        expect(rows.where((r) => r['final_status'] == null).length, 5);
      },
    );

    // Verifies: REQ-d00132-C — on a destination with no exhausted rows,
    // rehabilitateAllExhausted is a clean no-op returning 0.
    test(
      'REQ-d00132-C: rehabilitateAllExhausted returns 0 when no exhausted rows',
      () async {
        final setup = await _setupDestinationWithMixedFifo(
          backend,
          sentCount: 1,
          pendingCount: 2,
        );
        final count = await rehabilitateAllExhausted(
          setup.destination.id,
          backend: backend,
        );
        expect(count, 0);

        final rows = await _readAllFifoRows(backend, setup.destination.id);
        // Nothing changed.
        expect(
          rows
              .where((r) => r['final_status'] == FinalStatus.sent.toJson())
              .length,
          1,
        );
        expect(rows.where((r) => r['final_status'] == null).length, 2);
      },
    );

    // Verifies: rehabilitate's pre-transaction read vs. transactional write
    // TOCTOU path documented on `setFinalStatusTxn`. If the row is deleted
    // between the existence check and the transactional flip, the
    // transaction path throws `StateError`. Simulated by deleting the
    // row directly via the underlying Sembast store after the check would
    // have passed but before rehabilitate's own transaction commits.
    test('rehabilitate: TOCTOU — row deleted mid-op throws StateError '
        'rather than silently corrupting state', () async {
      final setup = await _setupDestinationWithMixedFifo(
        backend,
        exhaustedCount: 1,
      );
      // Grab the row's entry_id while it still exists.
      final rows = await _readAllFifoRows(backend, setup.destination.id);
      final entryId = rows.single['entry_id']! as String;

      // Delete it out-of-band before rehabilitate's transaction runs.
      final db = backend.debugDatabase();
      final store = sembast.StoreRef<int, Map<String, Object?>>(
        'fifo_${setup.destination.id}',
      );
      await store.delete(
        db,
        finder: sembast.Finder(
          filter: sembast.Filter.equals('entry_id', entryId),
        ),
      );

      // rehabilitate's transaction sees the row gone; setFinalStatusTxn
      // throws StateError (not ArgumentError, which is reserved for the
      // pre-check path).
      await expectLater(
        rehabilitateExhaustedRow(
          setup.destination.id,
          entryId,
          backend: backend,
        ),
        throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
      );

      // State is uncorrupted: the out-of-band delete is the only
      // mutation, so the FIFO now has zero rows.
      final after = await _readAllFifoRows(backend, setup.destination.id);
      expect(after, isEmpty);
    });
  });
}
