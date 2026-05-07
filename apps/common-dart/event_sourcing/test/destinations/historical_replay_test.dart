import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/fill_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/native_destination.dart';
import '../test_support/registry_with_audit.dart';

const Initiator _testInit = AutomationInitiator(service: 'test-bootstrap');

/// Fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Append a single event to the event log, reserving a sequence number
/// inside the transaction. Returns the appended event with its populated
/// `sequenceNumber`.
Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  required DateTime clientTimestamp,
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
  String aggregateId = 'agg-1',
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: 'DiaryEntry',
      entryType: entryType,
      entryTypeVersion: 1,
      libFormatVersion: 1,
      eventType: eventType,
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

/// Read every row in [destinationId]'s FIFO store, in
/// `sequence_in_queue` ascending order, as raw maps. Used to assert the
/// exact batch layout a replay produced.
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

void main() {
  group(
    'runHistoricalReplay() via setStartDate (REQ-d00129-D, REQ-d00130)',
    () {
      late SembastBackend backend;
      late DestinationRegistry registry;
      var dbCounter = 0;

      setUp(() async {
        dbCounter += 1;
        backend = await _openBackend('historical-replay-$dbCounter.db');
        final deps = buildAuditedRegistryDeps(backend);
        registry = DestinationRegistry(
          backend: backend,
          eventStore: deps.eventStore,
        );
      });

      tearDown(() async {
        await backend.close();
      });

      // Verifies: REQ-d00129-D + REQ-d00130-A+B — setStartDate with a past
      // date walks the event_log past fill_cursor in the same transaction
      // and enqueues every matching historical event as batches identical
      // in shape to fillBatch output (destination's canAddToBatch and
      // transform).
      test('REQ-d00129-D: setStartDate with past date batches all matching '
          'historical events', () async {
        // Seed 5 events, all inside the last hour.
        final ts = DateTime.now().subtract(const Duration(minutes: 10));
        for (var i = 1; i <= 5; i++) {
          await _appendEvent(
            backend,
            eventId: 'e$i',
            clientTimestamp: ts.add(Duration(seconds: i)),
          );
        }

        final dest = FakeDestination(id: 'x', batchCapacity: 2);
        await registry.addDestination(dest, initiator: _testInit);

        await registry.setStartDate(
          'x',
          DateTime.now().subtract(const Duration(hours: 1)),
          initiator: _testInit,
        );

        // batchCapacity = 2 → rows of 2, 2, 1 for 5 events.
        final rows = await _readAllFifoRows(backend, 'x');
        expect(rows, hasLength(3));
        expect((rows[0]['event_ids']! as List).cast<String>(), ['e1', 'e2']);
        expect((rows[1]['event_ids']! as List).cast<String>(), ['e3', 'e4']);
        expect((rows[2]['event_ids']! as List).cast<String>(), ['e5']);
        // Every row is pre-terminal (final_status == null); live drain
        // will handle delivery later.
        for (final r in rows) {
          expect(r['final_status'], isNull);
        }
        // fill_cursor advanced to the last replayed event's sequence_number.
        expect(await backend.readFillCursor('x'), 5);
      });

      // Verifies: REQ-d00129-E — setStartDate in the future does NOT
      // replay. Events accumulate in event_log and stay out of the FIFO
      // until wall-clock crosses startDate (then fillBatch picks them up).
      test(
        'REQ-d00129-E: setStartDate in the future leaves FIFO empty',
        () async {
          // Seed 3 events "now".
          final ts = DateTime.now();
          for (var i = 1; i <= 3; i++) {
            await _appendEvent(
              backend,
              eventId: 'e$i',
              clientTimestamp: ts.add(Duration(seconds: i)),
            );
          }
          final dest = FakeDestination(id: 'x', batchCapacity: 10);
          await registry.addDestination(dest, initiator: _testInit);

          await registry.setStartDate(
            'x',
            DateTime.now().add(const Duration(days: 1)),
            initiator: _testInit,
          );

          expect(await backend.readFifoHead('x'), isNull);
          // fill_cursor untouched — replay did not run.
          expect(await backend.readFillCursor('x'), -1);
          // Fall-through check: rows list is empty, not just "head is null".
          expect(await _readAllFifoRows(backend, 'x'), isEmpty);
        },
      );

      // Verifies: REQ-d00130-C — events appended AFTER replay land via
      // the live fillBatch path, not duplicated by replay. We simulate the
      // serialization order (replay transaction completes, then the new
      // record() transaction runs) explicitly: append 3 events, setStartDate
      // (past) — replay enqueues all 3; append 2 more events; run fillBatch
      // — those 2 are enqueued by the live path. No event_id appears in
      // more than one FIFO row; every event is covered exactly once.
      test('REQ-d00130-C: events appended after replay start land via live '
          'fillBatch, not duplicated', () async {
        // Seed 3 events well inside the past-start window.
        final seedTs = DateTime.now().subtract(const Duration(minutes: 30));
        for (var i = 1; i <= 3; i++) {
          await _appendEvent(
            backend,
            eventId: 'e$i',
            clientTimestamp: seedTs.add(Duration(seconds: i)),
          );
        }

        // batchCapacity = 3 → replay enqueues the 3 seeded events as one
        // row; the post-replay fillBatch enqueues the next 2 as a
        // separate row. This gives us a distinguishable "before replay /
        // after replay" FIFO layout that would be violated if replay
        // either missed events or double-enqueued them.
        final dest = FakeDestination(id: 'x', batchCapacity: 3);
        await registry.addDestination(dest, initiator: _testInit);

        // setStartDate(past): replay enqueues the 3 existing events.
        await registry.setStartDate(
          'x',
          DateTime.now().subtract(const Duration(hours: 1)),
          initiator: _testInit,
        );

        // Replay must land a FIFO row with exactly the 3 seeded events,
        // and advance fill_cursor past them. This is the primary
        // REQ-d00130-C assertion — it would break if replay were a no-op
        // or if replay double-enqueued a row.
        final afterReplay = await _readAllFifoRows(backend, 'x');
        expect(afterReplay, hasLength(1));
        expect((afterReplay.single['event_ids']! as List).cast<String>(), [
          'e1',
          'e2',
          'e3',
        ]);
        expect(await backend.readFillCursor('x'), 3);

        // Two more events appended AFTER replay (simulates the concurrent
        // record() serialized after the replay transaction).
        final postTs = DateTime.now().subtract(const Duration(minutes: 5));
        for (var i = 4; i <= 5; i++) {
          await _appendEvent(
            backend,
            eventId: 'e$i',
            clientTimestamp: postTs.add(Duration(seconds: i)),
          );
        }

        // Live fillBatch picks up the two new events. Passes a now-clock
        // that's past every event's timestamp so the window is open.
        final schedule = await registry.scheduleOf('x');
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: DateTime.now,
        );

        // Collect every event_id across all FIFO rows. No id may appear
        // in more than one row, and every appended event must be present.
        final rows = await _readAllFifoRows(backend, 'x');
        final allEventIds = <String>[];
        for (final r in rows) {
          allEventIds.addAll((r['event_ids']! as List).cast<String>());
        }
        expect(
          allEventIds.toSet(),
          {'e1', 'e2', 'e3', 'e4', 'e5'},
          reason: 'every appended event must appear exactly once in the FIFO',
        );
        expect(
          allEventIds,
          hasLength(5),
          reason: 'no event_id may appear in more than one FIFO row',
        );
        // Replay wrote row 0 with the 3 seeded events; live fillBatch
        // wrote row 1 with the 2 post-replay events. Verifying both the
        // row count and the per-row event lists guards against a replay
        // that double-enqueues the seeded events when the live fillBatch
        // runs.
        expect(rows, hasLength(2));
        expect((rows[0]['event_ids']! as List).cast<String>(), [
          'e1',
          'e2',
          'e3',
        ]);
        expect((rows[1]['event_ids']! as List).cast<String>(), ['e4', 'e5']);
        // fill_cursor advances to the last enqueued event's
        // sequence_number. The registry's REQ-d00129-J/K audit emissions
        // are interleaved into the event_log and consume sequence
        // numbers, but never reach the FIFO; the cursor matches the
        // last user event's seq, whatever that ends up being.
        final lastUserEvent = (await backend.findAllEvents()).lastWhere(
          (e) => e.eventId.startsWith('e'),
        );
        expect(await backend.readFillCursor('x'), lastUserEvent.sequenceNumber);
      });

      // Verifies: REQ-d00152-B (replay parity) — historical replay must
      //   honor `serializesNatively` symmetrically with `fillBatch`.
      //   Native destinations never have `transform` invoked; replay
      //   mints `BatchEnvelopeMetadata` from the local `Source` and
      //   enqueues via `nativeEnvelope:` (envelope_metadata column
      //   populated, wire_payload null).
      test('REQ-d00152-B: replay on a native destination skips transform '
          'and stamps envelope metadata', () async {
        // Seed 3 events well inside the past-start window.
        final ts = DateTime.now().subtract(const Duration(minutes: 10));
        for (var i = 1; i <= 3; i++) {
          await _appendEvent(
            backend,
            eventId: 'n$i',
            clientTimestamp: ts.add(Duration(seconds: i)),
          );
        }

        final native = NativeDestination(
          id: 'native',
          batchCapacity: 5,
          script: <SendResult>[],
        );
        await registry.addDestination(native, initiator: _testInit);

        // Calling setStartDate(past) triggers replay. Calling
        // `transform` on a native destination throws by contract;
        // a green test confirms replay correctly took the native branch.
        await registry.setStartDate(
          'native',
          DateTime.now().subtract(const Duration(hours: 1)),
          initiator: _testInit,
        );

        final rows = await _readAllFifoRows(backend, 'native');
        expect(rows, hasLength(1));
        expect((rows[0]['event_ids']! as List).cast<String>(), [
          'n1',
          'n2',
          'n3',
        ]);
        // Native rows: envelope_metadata populated, wire_payload null.
        expect(
          rows[0]['envelope_metadata'],
          isNotNull,
          reason: 'native replay row must carry envelope metadata',
        );
        expect(
          rows[0]['wire_payload'],
          isNull,
          reason:
              'native replay row must NOT carry wire_payload bytes '
              '(library reconstructs at drain time per REQ-d00119-K)',
        );
        final envelope = Map<String, Object?>.from(
          rows[0]['envelope_metadata']! as Map,
        );
        // Source identity flows through the envelope (matches fillBatch).
        expect(envelope['sender_hop'], 'mobile-device');
        expect(envelope['sender_identifier'], 'test-device');
      });

      // Verifies: REQ-d00128-J + REQ-d00154-F + REQ-d00152-B (replay
      //   parity) — a destination with `includeSystemEvents: true`
      //   registered AFTER system audit events have already landed in
      //   the event log catches them up via replay without invoking
      //   `transform`. This is the demo-pane scenario where
      //   `NativeAudit` is set up post-bootstrap with `includeSystemEvents`
      //   enabled and inherits the audits from prior destination
      //   registrations.
      test('REQ-d00152-B + REQ-d00128-J: native audit-mirror picks up prior '
          'system audits via replay', () async {
        // Register a non-native sibling first so the registry emits a
        // `system.destination_registered` audit into the event log.
        final sibling = FakeDestination(id: 'sibling', batchCapacity: 1);
        await registry.addDestination(sibling, initiator: _testInit);

        // Now register a native audit-mirror with `includeSystemEvents:
        // true` and an empty user `entryTypes` allow-list — this is the
        // demo's NativeAudit shape.
        final auditMirror = NativeDestination(
          id: 'audit_mirror',
          filter: const SubscriptionFilter(
            entryTypes: <String>[],
            includeSystemEvents: true,
          ),
          batchCapacity: 10,
          script: <SendResult>[],
        );
        await registry.addDestination(auditMirror, initiator: _testInit);

        // setStartDate(past) triggers replay over every prior system
        // audit. With the previous-buggy code, `transform` would be
        // called and throw because the native destination throws by
        // contract. With the fix in place, replay enqueues a row with
        // envelope metadata, no wire_payload.
        await registry.setStartDate(
          'audit_mirror',
          DateTime.now().subtract(const Duration(hours: 1)),
          initiator: _testInit,
        );

        final rows = await _readAllFifoRows(backend, 'audit_mirror');
        expect(
          rows,
          isNotEmpty,
          reason:
              'replay must enqueue prior system audits onto the '
              'audit-mirror native destination',
        );
        for (final r in rows) {
          expect(
            r['envelope_metadata'],
            isNotNull,
            reason:
                'every native audit-mirror row must carry envelope '
                'metadata',
          );
          expect(
            r['wire_payload'],
            isNull,
            reason: 'native rows must NOT carry wire_payload bytes',
          );
        }
      });
    },
  );
}
