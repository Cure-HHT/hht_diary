import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/fill_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';
import '../test_support/registry_with_audit.dart';

const Initiator _testInit = AutomationInitiator(service: 'test-bootstrap');

/// Fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Read every FIFO row on [destinationId] as raw maps, in
/// `sequence_in_queue` ascending order. Lets tests assert the raw
/// Sembast state without round-tripping through the FifoEntry type.
Future<List<Map<String, Object?>>> _readAllFifoRows(
  SembastBackend backend,
  String destinationId,
) async {
  final db = backend.databaseForTesting;
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

/// Append a single event to the event log with a reserved sequence
/// number. Used by the REQ-d00144-F fillBatch-reintegration test so
/// there are real events for fillBatch to re-promote after the
/// tombstone + trail sweep.
Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  required DateTime clientTimestamp,
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: 'agg-1',
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      entryTypeVersion: 1,
      libFormatVersion: 1,
      eventType: 'finalized',
      sequenceNumber: seq,
      data: const <String, dynamic>{},
      metadata: const <String, dynamic>{},
      initiator: const UserInitiator('u'),
      clientTimestamp: clientTimestamp,
      eventHash: 'hash-$eventId',
    );
    await backend.appendEvent(txn, event);
    return event;
  });
}

/// Sentinel passed as [_HeadKind] to `_seedFifo` to request a
/// null-final_status head row (a still-pending drain candidate).
enum _HeadKind {
  /// Do not seed a head row. Useful for REQ-d00144-A rejection cases
  /// where the only seeded row is a `sent` row (which readFifoHead
  /// skips, so the FIFO effectively has no head).
  none,

  /// Head row is left pre-terminal (final_status == null).
  pending,

  /// Head row transitions to FinalStatus.wedged with one seeded
  /// attempt so REQ-d00144-B can assert attempts[] preservation.
  wedged,
}

/// Set up a destination with a seeded FIFO: an optional sent prefix
/// (rows 1..[sentCount]), an optional head row (kind controlled by
/// [headKind]), and an optional trail of null-status rows following
/// the head. Returns the head row's `entry_id` (null when
/// [headKind] == _HeadKind.none) so tests can pass it to
/// `tombstoneAndRefill`.
///
/// Destination is active (no endDate) so we exercise REQ-d00144
/// without the unjam deactivation requirement.
Future<
  ({
    SembastBackend backend,
    DestinationRegistry registry,
    FakeDestination destination,
    String? headEntryId,
  })
>
_seedFifo(
  SembastBackend backend, {
  int sentCount = 0,
  _HeadKind headKind = _HeadKind.pending,
  int trailCount = 0,
}) async {
  final deps = buildAuditedRegistryDeps(backend);
  final registry = DestinationRegistry(
    backend: backend,
    eventStore: deps.eventStore,
  );
  final destination = FakeDestination(id: 'tombstone-dest');
  await registry.addDestination(destination, initiator: _testInit);
  await registry.setStartDate(
    destination.id,
    DateTime.utc(2026, 1, 1),
    initiator: _testInit,
  );

  var seq = 0;
  // Sent prefix rows.
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
  String? headEntryId;
  if (headKind != _HeadKind.none) {
    seq += 1;
    final row = await enqueueSingle(
      backend,
      destination.id,
      eventId: 'head-e$seq',
      sequenceNumber: seq,
    );
    headEntryId = row.entryId;
    if (headKind == _HeadKind.wedged) {
      // Seed one attempt so REQ-d00144-B can assert attempts[] is
      // preserved across the wedged -> tombstoned flip.
      await backend.appendAttempt(
        destination.id,
        headEntryId,
        AttemptResult(
          attemptedAt: DateTime.utc(2026, 4, 22, 12, seq),
          outcome: 'permanent',
          errorMessage: 'simulated failure',
          httpStatus: 500,
        ),
      );
      await backend.markFinal(destination.id, headEntryId, FinalStatus.wedged);
    }
  }
  // Trail rows (all pre-terminal / null final_status).
  for (var i = 0; i < trailCount; i++) {
    seq += 1;
    await enqueueSingle(
      backend,
      destination.id,
      eventId: 'trail-e$seq',
      sequenceNumber: seq,
    );
  }
  // fill_cursor tracks the last enqueued row's sequence_number so the
  // rewind is observable.
  if (seq > 0) {
    await backend.writeFillCursor(destination.id, seq);
  }
  return (
    backend: backend,
    registry: registry,
    destination: destination,
    headEntryId: headEntryId,
  );
}

void main() {
  group('tombstoneAndRefill()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('tombstone-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00144-A — target must be the current head of the
    // FIFO. A non-head row (e.g., a pre-terminal row behind another
    // pre-terminal row) is rejected with ArgumentError before any
    // transactional mutation runs.
    test(
      'REQ-d00144-A: throws ArgumentError when fifoRowId is not the head',
      () async {
        final setup = await _seedFifo(
          backend,
          headKind: _HeadKind.pending, // head is pre-terminal at seq_in_queue=1
          trailCount: 2,
        );
        // Trail rows exist at seq_in_queue 2 and 3; target the last
        // trail row, which is not the head.
        final rows = await _readAllFifoRows(backend, setup.destination.id);
        final trailRow = rows.last;
        final trailEntryId = trailRow['entry_id']! as String;
        expect(trailEntryId, isNot(equals(setup.headEntryId)));

        await expectLater(
          setup.registry.tombstoneAndRefill(
            setup.destination.id,
            trailEntryId,
            initiator: _testInit,
          ),
          throwsArgumentError,
        );
        // Nothing was mutated.
        final after = await _readAllFifoRows(backend, setup.destination.id);
        expect(after.length, rows.length);
        for (final r in after) {
          expect(r['final_status'], isNull);
        }
      },
    );

    // Verifies: REQ-d00144-A — a `sent` row is not a legal target
    // (readFifoHead skips it, so it can't be the head). Rejected with
    // ArgumentError.
    test('REQ-d00144-A: throws ArgumentError when target is sent', () async {
      final setup = await _seedFifo(
        backend,
        sentCount: 1,
        headKind: _HeadKind.none,
      );
      final rows = await _readAllFifoRows(backend, setup.destination.id);
      final sentEntryId = rows.single['entry_id']! as String;
      expect(rows.single['final_status'], FinalStatus.sent.toJson());
      await expectLater(
        setup.registry.tombstoneAndRefill(
          setup.destination.id,
          sentEntryId,
          initiator: _testInit,
        ),
        throwsArgumentError,
      );
    });

    // Verifies: REQ-d00144-A — a `tombstoned` row is not a legal target
    // (readFifoHead skips it).
    test(
      'REQ-d00144-A: throws ArgumentError when target is tombstoned',
      () async {
        // Seed a FIFO with a wedged head, tombstone it, then try to
        // tombstone again — the second call sees the first call's
        // rewind and no remaining head pointing to the tombstoned row.
        final setup = await _seedFifo(backend, headKind: _HeadKind.wedged);
        final headEntryId = setup.headEntryId!;
        await setup.registry.tombstoneAndRefill(
          setup.destination.id,
          headEntryId,
          initiator: _testInit,
        );
        // The tombstoned row is still in the store but readFifoHead
        // skips it; a second tombstone call against it must reject.
        await expectLater(
          setup.registry.tombstoneAndRefill(
            setup.destination.id,
            headEntryId,
            initiator: _testInit,
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00144-A — an unknown row id rejects with
    // ArgumentError (readFifoHead either returns null or a different
    // entryId; either way target-is-head fails).
    test(
      'REQ-d00144-A: throws ArgumentError when row does not exist',
      () async {
        final setup = await _seedFifo(backend, headKind: _HeadKind.wedged);
        await expectLater(
          setup.registry.tombstoneAndRefill(
            setup.destination.id,
            'does-not-exist',
            initiator: _testInit,
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00144-B — on a wedged head, final_status flips to
    // tombstoned and the row's attempts[] is preserved verbatim.
    test('REQ-d00144-B: wedged head transitions to tombstoned; '
        'attempts preserved', () async {
      final setup = await _seedFifo(backend, headKind: _HeadKind.wedged);
      final headEntryId = setup.headEntryId!;
      final before = await _readAllFifoRows(backend, setup.destination.id);
      final beforeHead = before.single;
      expect(beforeHead['final_status'], FinalStatus.wedged.toJson());
      final originalAttempts = (beforeHead['attempts'] as List).toList();
      expect(originalAttempts.length, 1);

      final result = await setup.registry.tombstoneAndRefill(
        setup.destination.id,
        headEntryId,
        initiator: _testInit,
      );
      expect(result.targetRowId, headEntryId);

      final after = await _readAllFifoRows(backend, setup.destination.id);
      expect(after.length, 1);
      final afterHead = after.single;
      expect(afterHead['final_status'], FinalStatus.tombstoned.toJson());
      // attempts[] preserved byte-for-byte.
      final afterAttempts = (afterHead['attempts'] as List).toList();
      expect(afterAttempts, equals(originalAttempts));
      // entry_id and sequence_in_queue unchanged.
      expect(afterHead['entry_id'], beforeHead['entry_id']);
      expect(afterHead['sequence_in_queue'], beforeHead['sequence_in_queue']);
    });

    // Verifies: REQ-d00144-B — on a null (pre-terminal) head,
    // final_status flips to tombstoned and attempts[] is preserved
    // (empty on a pre-terminal row).
    test(
      'REQ-d00144-B: null head transitions to tombstoned; attempts preserved',
      () async {
        final setup = await _seedFifo(backend, headKind: _HeadKind.pending);
        final headEntryId = setup.headEntryId!;
        final before = await _readAllFifoRows(backend, setup.destination.id);
        final beforeHead = before.single;
        expect(beforeHead['final_status'], isNull);
        expect(beforeHead['attempts'] as List, isEmpty);

        final result = await setup.registry.tombstoneAndRefill(
          setup.destination.id,
          headEntryId,
          initiator: _testInit,
        );
        expect(result.targetRowId, headEntryId);

        final after = await _readAllFifoRows(backend, setup.destination.id);
        expect(after.single['final_status'], FinalStatus.tombstoned.toJson());
        expect(after.single['attempts'] as List, isEmpty);
      },
    );

    // Verifies: REQ-d00144-C — every trail row whose sequence_in_queue
    // is strictly greater than the target's is deleted from the FIFO.
    // The target row itself is not deleted (it is the tombstone).
    test('REQ-d00144-C: trail null rows after target are deleted', () async {
      final setup = await _seedFifo(
        backend,
        headKind: _HeadKind.wedged,
        trailCount: 3,
      );
      final headEntryId = setup.headEntryId!;
      final before = await _readAllFifoRows(backend, setup.destination.id);
      expect(before.length, 4); // 1 wedged head + 3 trail

      final result = await setup.registry.tombstoneAndRefill(
        setup.destination.id,
        headEntryId,
        initiator: _testInit,
      );
      expect(result.deletedTrailCount, 3);

      final after = await _readAllFifoRows(backend, setup.destination.id);
      // Only the tombstoned head remains.
      expect(after.length, 1);
      expect(after.single['entry_id'], headEntryId);
      expect(after.single['final_status'], FinalStatus.tombstoned.toJson());
    });

    // Verifies: REQ-d00144-C — the deleted trail leaves a
    // sequence_in_queue gap visible in the store. With sentCount=1
    // (seq_in_queue 1), head (2) + trail (3, 4, 5), after tombstone:
    // surviving rows have seq_in_queue {1, 2} — the gap [3..5] is
    // never filled (REQ-d00119-E).
    test(
      'REQ-d00144-C: sequence_in_queue gap is visible after trail delete',
      () async {
        final setup = await _seedFifo(
          backend,
          sentCount: 1,
          headKind: _HeadKind.wedged,
          trailCount: 3,
        );
        final headEntryId = setup.headEntryId!;
        await setup.registry.tombstoneAndRefill(
          setup.destination.id,
          headEntryId,
          initiator: _testInit,
        );
        final after = await _readAllFifoRows(backend, setup.destination.id);
        final seqs = after.map((r) => r['sequence_in_queue']! as int).toList();
        expect(seqs, [1, 2]); // sent row + tombstoned head; trail is gone.
      },
    );

    // Verifies: REQ-d00144-D — fill_cursor rewinds to
    // target.event_id_range.first_seq - 1. With sentCount=2 (seq 1,2)
    // and a wedged head at seq 3, the rewind target is 2 (=3-1).
    test('REQ-d00144-D: fill_cursor rewinds to target.first_seq - 1', () async {
      final setup = await _seedFifo(
        backend,
        sentCount: 2,
        headKind: _HeadKind.wedged,
        trailCount: 2,
      );
      final headEntryId = setup.headEntryId!;
      // Pre-tombstone cursor advanced to last enqueued seq (5).
      expect(await backend.readFillCursor(setup.destination.id), 5);

      final result = await setup.registry.tombstoneAndRefill(
        setup.destination.id,
        headEntryId,
        initiator: _testInit,
      );
      expect(result.rewoundTo, 2);
      expect(await backend.readFillCursor(setup.destination.id), 2);
    });

    // Verifies: REQ-d00144-D — when there is no sent prefix, the
    // rewind target is target.first_seq - 1, which is 0 when the head
    // sits at seq 1 (pre-start sentinel is -1, but the canonical
    // formula is first_seq - 1, NOT max(sent) ?? -1).
    test(
      'REQ-d00144-D: fill_cursor rewinds correctly when no sent rows exist',
      () async {
        final setup = await _seedFifo(
          backend,
          headKind: _HeadKind.wedged,
          trailCount: 2,
        );
        final headEntryId = setup.headEntryId!;
        // Pre-tombstone cursor at 3 (last enqueued seq).
        expect(await backend.readFillCursor(setup.destination.id), 3);

        final result = await setup.registry.tombstoneAndRefill(
          setup.destination.id,
          headEntryId,
          initiator: _testInit,
        );
        // head sits at seq 1 (no sent prefix), so rewoundTo = 1 - 1 = 0.
        expect(result.rewoundTo, 0);
        expect(await backend.readFillCursor(setup.destination.id), 0);
      },
    );

    // Verifies: REQ-d00144-E — TombstoneAndRefillResult carries
    // targetRowId, deletedTrailCount, and rewoundTo.
    test(
      'REQ-d00144-E: returns TombstoneAndRefillResult with correct fields',
      () async {
        final setup = await _seedFifo(
          backend,
          sentCount: 2,
          headKind: _HeadKind.wedged,
          trailCount: 4,
        );
        final headEntryId = setup.headEntryId!;

        final result = await setup.registry.tombstoneAndRefill(
          setup.destination.id,
          headEntryId,
          initiator: _testInit,
        );
        expect(result, isA<TombstoneAndRefillResult>());
        expect(result.targetRowId, headEntryId);
        expect(result.deletedTrailCount, 4);
        expect(result.rewoundTo, 2); // head first_seq = 3, so 3-1 = 2
      },
    );

    // Verifies: REQ-d00144-F — end-to-end, production shape: after
    // tombstoneAndRefill, the next fillBatch re-promotes every event
    // covered by the tombstoned target AND by its trail into fresh
    // FIFO rows. With v4-UUID `entry_id`s (Phase 4.7 Task 6.5) the
    // tombstoned audit row and the fresh re-promotion rows coexist
    // even when they cover the same event_ids — their identifiers
    // never collide.
    //
    // Setup: 9 events on the event log. Enqueue three contiguous
    // 3-event batches — the first wedged (events 1-3, head), then
    // two null (events 4-6 and 7-9, trail).
    //
    // Contract:
    //  - fill_cursor rewinds to target.first_seq - 1 = 0 (REQ-d00144-D);
    //  - events 1-9 are re-promoted into fresh FIFO rows starting from
    //    the rewound cursor;
    //  - the tombstoned audit row survives alongside the fresh rows;
    //  - every fresh row has a new UUID entryId distinct from the
    //    tombstoned row's entryId (Task 6.5).
    test(
      'REQ-d00144-F: next fillBatch re-promotes target events AND trail events',
      () async {
        final deps = buildAuditedRegistryDeps(backend);
        final registry = DestinationRegistry(
          backend: backend,
          eventStore: deps.eventStore,
        );
        final destination = FakeDestination(id: 'dst-f', batchCapacity: 3);
        // Register + set startDate BEFORE appending events so the
        // historical-replay branch (REQ-d00129-D) sees zero candidates
        // and does not auto-enqueue rows that would conflict with our
        // controlled seeding below.
        await registry.addDestination(destination, initiator: _testInit);
        await registry.setStartDate(
          destination.id,
          DateTime.utc(2026, 1, 1),
          initiator: _testInit,
        );
        // Seed 9 events on the event log.
        final clientTs = DateTime.utc(2026, 4, 22, 10);
        for (var i = 1; i <= 9; i++) {
          await _appendEvent(
            backend,
            eventId: 'e$i',
            clientTimestamp: clientTs,
          );
        }

        // Directly enqueue three 3-event batches. These land at
        // sequence_in_queue 1, 2, 3 because the FIFO is empty after
        // setStartDate's zero-event replay branch.
        Future<void> enqueueBatch(List<int> seqs) async {
          await backend.transaction((txn) async {
            final events = <StoredEvent>[];
            final all = await backend.findAllEventsInTxn(txn);
            for (final s in seqs) {
              events.add(all.firstWhere((e) => e.sequenceNumber == s));
            }
            final payload = wirePayloadJson({'seqs': seqs});
            await backend.enqueueFifoTxn(
              txn,
              destination.id,
              events,
              wirePayload: payload,
            );
          });
        }

        await enqueueBatch([1, 2, 3]);
        await enqueueBatch([4, 5, 6]);
        await enqueueBatch([7, 8, 9]);
        // Wedge the head batch row.
        final rows0 = await _readAllFifoRows(backend, destination.id);
        expect(rows0.length, 3);
        final headEntryId = rows0.first['entry_id']! as String;
        await backend.appendAttempt(
          destination.id,
          headEntryId,
          AttemptResult(
            attemptedAt: DateTime.utc(2026, 4, 22, 12),
            outcome: 'permanent',
            errorMessage: 'simulated failure',
            httpStatus: 500,
          ),
        );
        await backend.markFinal(
          destination.id,
          headEntryId,
          FinalStatus.wedged,
        );
        // fill_cursor at 9 (last enqueued seq) so the rewind is
        // observable.
        await backend.writeFillCursor(destination.id, 9);

        // Act: tombstone + refill.
        final result = await registry.tombstoneAndRefill(
          destination.id,
          headEntryId,
          initiator: _testInit,
        );
        expect(result.deletedTrailCount, 2);
        // REQ-d00144-D: rewound to target.first_seq - 1 = 1 - 1 = 0.
        // This positions fillBatch to walk events 1..9 again.
        expect(result.rewoundTo, 0);

        // Run fillBatch enough times to drain all events. With
        // batchCapacity=3, three calls cover events 1-3, 4-6, 7-9.
        final schedule = await registry.scheduleOf(destination.id);
        for (var i = 0; i < 3; i++) {
          await fillBatch(
            destination,
            backend: backend,
            schedule: schedule,
            clock: () => DateTime.utc(2026, 4, 22, 13),
          );
        }

        final rows1 = await _readAllFifoRows(backend, destination.id);
        final tombstoned = rows1
            .where((r) => r['final_status'] == FinalStatus.tombstoned.toJson())
            .toList();
        // REQ-d00144-B: tombstoned row survives.
        expect(tombstoned.length, 1);
        expect(tombstoned.single['entry_id'], headEntryId);

        final fresh = rows1.where((r) => r['final_status'] == null).toList();
        // REQ-d00144-F: events 1-9 are re-promoted into fresh rows —
        // three 3-event batches at the destination's batchCapacity.
        expect(fresh.length, 3);
        final coveredIds = <String>{};
        for (final r in fresh) {
          coveredIds.addAll((r['event_ids']! as List).cast<String>());
        }
        expect(coveredIds, {for (var i = 1; i <= 9; i++) 'e$i'});
        // Task 6.5 invariant: every fresh row's entry_id is a UUID
        // distinct from the tombstoned row's entry_id.
        for (final r in fresh) {
          expect(r['entry_id'], isNot(headEntryId));
        }
        // And all four rows (1 tombstoned + 3 fresh) have pairwise-
        // distinct entry_ids.
        final allEntryIds = rows1.map((r) => r['entry_id']! as String).toList();
        expect(allEntryIds.toSet().length, allEntryIds.length);
        // fill_cursor advanced through all 9 user events. The registry
        // emits REQ-d00129-J/K and REQ-d00144-G audit events that
        // consume sequence_number slots in event_log, so the absolute
        // value is offset; assert against the last user event's seq
        // instead of a literal.
        final lastUserSeq = (await backend.findAllEvents())
            .where((e) => e.eventId.startsWith('e'))
            .map((e) => e.sequenceNumber)
            .reduce((a, b) => a > b ? a : b);
        expect(await backend.readFillCursor(destination.id), lastUserSeq);
      },
    );
  });
}
