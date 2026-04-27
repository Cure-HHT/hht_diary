import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/fill_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/native_destination.dart';
import '../test_support/registry_with_audit.dart';

const Initiator _testInit = AutomationInitiator(service: 'test-bootstrap');

/// Fixture — a fresh in-memory SembastBackend per test.
Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Append a single event to the event log, reserving a sequence number
/// inside the transaction per the reserve-and-increment contract. Returns
/// the appended event with its populated `sequenceNumber`.
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

void main() {
  group('fillBatch()', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('fill-batch-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00128-H — fillBatch with no new matching events is a
    // no-op: no FIFO rows are enqueued, fill_cursor is unchanged, no
    // transient state leaks.
    test(
      'REQ-d00128-H: fillBatch with no new matching events is a no-op',
      () async {
        // Append events to the log so the dormant-schedule early-exit
        // is the only thing preventing a FIFO write (not vacuous).
        await _appendEvent(
          backend,
          eventId: 'e1',
          clientTimestamp: DateTime.utc(2026, 4, 22, 11),
        );
        final dest = FakeDestination(id: 'fake');
        const schedule = DestinationSchedule();
        // Dormant schedule: should be a no-op despite candidates.
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        expect(await backend.readFifoHead('fake'), isNull);
        expect(await backend.readFillCursor('fake'), -1);
      },
    );

    // Verifies: REQ-d00128-H — with an active schedule but an empty event
    // log, fillBatch does not enqueue any rows and does not advance the
    // cursor.
    test(
      'REQ-d00128-H: fillBatch with empty event log does not advance cursor',
      () async {
        final dest = FakeDestination(id: 'fake');
        final schedule = DestinationSchedule(
          startDate: DateTime.utc(2026, 4, 1),
        );
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        expect(await backend.readFifoHead('fake'), isNull);
        expect(await backend.readFillCursor('fake'), -1);
      },
    );

    // Verifies: REQ-d00128-E — fillBatch respects canAddToBatch: 7 events
    // with batchCapacity=3 produces one FIFO row covering the first 3
    // events and advances the cursor to the 3rd event's sequence_number.
    test('REQ-d00128-E: fillBatch respects canAddToBatch boundary', () async {
      final clientTs = DateTime.utc(2026, 4, 22, 10);
      final appended = <StoredEvent>[];
      for (var i = 1; i <= 7; i++) {
        appended.add(
          await _appendEvent(
            backend,
            eventId: 'e$i',
            clientTimestamp: clientTs,
          ),
        );
      }
      final dest = FakeDestination(id: 'fake', batchCapacity: 3);
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));

      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );

      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.eventIds, ['e1', 'e2', 'e3']);
      expect(head.eventIdRange, (firstSeq: 1, lastSeq: 3));
      expect(head.finalStatus, isNull);
      // Cursor advances to the batch's last sequence_number.
      expect(await backend.readFillCursor('fake'), 3);
    });

    // Verifies: REQ-d00128-F — a single-event batch is held until
    // maxAccumulateTime has elapsed: no FIFO row is written yet and the
    // fill_cursor is not advanced.
    test('REQ-d00128-F: fillBatch with 1 candidate and maxAccumulateTime>0 '
        'does not flush yet', () async {
      // Only one event in window.
      final ts = DateTime.utc(2026, 4, 22, 11, 59, 50);
      await _appendEvent(backend, eventId: 'e1', clientTimestamp: ts);

      final dest = FakeDestination(
        id: 'fake',
        batchCapacity: 10,
        maxAccumulateTime: const Duration(minutes: 5),
      );
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      // now - batch.first.clientTimestamp = 10s, well below 5 minutes.
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );
      expect(await backend.readFifoHead('fake'), isNull);
      // Cursor is NOT advanced: the candidate is still a live match that
      // we want to re-evaluate on the next tick.
      expect(await backend.readFillCursor('fake'), -1);
    });

    // Verifies: REQ-d00128-F — once maxAccumulateTime has elapsed, a
    // single-event batch flushes: a FIFO row is written and the
    // fill_cursor advances to the event's sequence_number.
    test('REQ-d00128-F: fillBatch flushes a 1-event batch once '
        'maxAccumulateTime has elapsed', () async {
      final ts = DateTime.utc(2026, 4, 22, 11, 50);
      await _appendEvent(backend, eventId: 'e1', clientTimestamp: ts);

      final dest = FakeDestination(
        id: 'fake',
        batchCapacity: 10,
        maxAccumulateTime: const Duration(minutes: 5),
      );
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      // Clock advanced 10 minutes past the event; age (10min) > 5min.
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.eventIds, ['e1']);
      expect(await backend.readFillCursor('fake'), 1);
    });

    // Verifies: REQ-d00129-I — events with client_timestamp < startDate
    // are NOT enqueued. Fresher matching events still flow through and
    // the cursor advances past the skipped ones.
    test(
      'REQ-d00129-I: fillBatch skips events with client_timestamp < startDate',
      () async {
        // Two events before startDate, one after.
        await _appendEvent(
          backend,
          eventId: 'e-pre1',
          clientTimestamp: DateTime.utc(2026, 3, 15),
        );
        await _appendEvent(
          backend,
          eventId: 'e-pre2',
          clientTimestamp: DateTime.utc(2026, 3, 20),
        );
        await _appendEvent(
          backend,
          eventId: 'e-active',
          clientTimestamp: DateTime.utc(2026, 4, 10),
        );

        final dest = FakeDestination(id: 'fake', batchCapacity: 10);
        final schedule = DestinationSchedule(
          startDate: DateTime.utc(2026, 4, 1),
        );
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );

        final head = await backend.readFifoHead('fake');
        expect(head, isNotNull);
        // Only the in-window event is enqueued.
        expect(head!.eventIds, ['e-active']);
        // Cursor advances to the in-window event's sequence number (3),
        // past the two skipped earlier events.
        expect(await backend.readFillCursor('fake'), 3);
      },
    );

    // Verifies: REQ-d00129-I — events with client_timestamp > endDate
    // (or > now() when endDate is later than now) are NOT enqueued.
    test(
      'REQ-d00129-I: fillBatch skips events with client_timestamp > endDate',
      () async {
        await _appendEvent(
          backend,
          eventId: 'e-active',
          clientTimestamp: DateTime.utc(2026, 4, 10),
        );
        // This event is AFTER endDate and should be skipped.
        await _appendEvent(
          backend,
          eventId: 'e-after',
          clientTimestamp: DateTime.utc(2026, 4, 20),
        );

        final dest = FakeDestination(id: 'fake', batchCapacity: 10);
        final schedule = DestinationSchedule(
          startDate: DateTime.utc(2026, 4, 1),
          endDate: DateTime.utc(2026, 4, 15),
        );
        // now() is well after endDate so the upper bound is endDate.
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );

        final head = await backend.readFifoHead('fake');
        expect(head, isNotNull);
        // Only the in-window event is enqueued.
        expect(head!.eventIds, ['e-active']);
        // Cursor advances to the enqueued batch's last sequence_number
        // (1). The out-of-window event at seq 2 remains past the cursor
        // for the next tick; on that tick fillBatch will filter it out
        // and advance cursor to 2 via the non-matching-tail branch.
        expect(await backend.readFillCursor('fake'), 1);

        // Second call: the tail event is out of window. fillBatch should
        // advance cursor past it and enqueue nothing new.
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        expect(await backend.readFillCursor('fake'), 2);
        // Head unchanged.
        final head2 = await backend.readFifoHead('fake');
        expect(head2, isNotNull);
        expect(head2!.eventIds, ['e-active']);
      },
    );

    // Verifies: REQ-d00128-G — fillBatch advances the fill_cursor to
    // batch.last.sequenceNumber on successful enqueue (single-event
    // batch here; cursor = the single event's sequence number).
    test('REQ-d00128-G: fillBatch advances fill_cursor to '
        'batch.last.sequenceNumber on successful enqueue', () async {
      // One matching event, batchCapacity=1, maxAccumulateTime=0 so it
      // flushes immediately.
      await _appendEvent(
        backend,
        eventId: 'e1',
        clientTimestamp: DateTime.utc(2026, 4, 10),
      );
      final dest = FakeDestination(id: 'fake');
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );
      expect(await backend.readFillCursor('fake'), 1);
      final head = await backend.readFifoHead('fake');
      expect(head, isNotNull);
      expect(head!.eventIdRange.lastSeq, 1);
    });

    // Verifies: REQ-d00128-H — a second fillBatch call immediately after
    // a first with no new matching events is a true no-op: no new FIFO
    // row, cursor unchanged at batch.last.sequenceNumber.
    test(
      'REQ-d00128-H: repeat fillBatch with no new events is idempotent',
      () async {
        await _appendEvent(
          backend,
          eventId: 'e1',
          clientTimestamp: DateTime.utc(2026, 4, 10),
        );
        final dest = FakeDestination(id: 'fake');
        final schedule = DestinationSchedule(
          startDate: DateTime.utc(2026, 4, 1),
        );

        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        final firstCursor = await backend.readFillCursor('fake');
        expect(firstCursor, 1);

        // Second call — no new events. Should not touch the cursor, and
        // should not enqueue a second FIFO row.
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        expect(await backend.readFillCursor('fake'), firstCursor);
        // Head is still the single row from the first call.
        final head = await backend.readFifoHead('fake');
        expect(head, isNotNull);
        expect(head!.eventIds, ['e1']);
      },
    );

    // Verifies: REQ-d00128-H — filter short-circuit: events that do not
    // match destination.filter are never enqueued, and the cursor advances
    // past them so they are not re-evaluated.
    test('REQ-d00128-H: non-matching events advance cursor but enqueue '
        'nothing', () async {
      // Filter only accepts entry_type='epistaxis_event'; append two
      // events of a different type.
      const skippedType = 'survey_event';
      await _appendEvent(
        backend,
        eventId: 'e-other1',
        clientTimestamp: DateTime.utc(2026, 4, 10),
        entryType: skippedType,
      );
      await _appendEvent(
        backend,
        eventId: 'e-other2',
        clientTimestamp: DateTime.utc(2026, 4, 11),
        entryType: skippedType,
      );
      final dest = FakeDestination(
        id: 'fake',
        filter: const SubscriptionFilter(entryTypes: ['epistaxis_event']),
      );
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );
      expect(await backend.readFifoHead('fake'), isNull);
      // Cursor advances past the skipped non-matching events so
      // subsequent fillBatch calls don't rescan them.
      expect(await backend.readFillCursor('fake'), 2);

      // Idempotency (REQ-d00128-H): a repeat call with no new candidates
      // does not re-advance the cursor and does not enqueue anything.
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => DateTime.utc(2026, 4, 22, 12),
      );
      expect(await backend.readFifoHead('fake'), isNull);
      expect(await backend.readFillCursor('fake'), 2);
    });

    // Verifies: REQ-d00128-I — when readFifoHead returns a wedged row,
    // fillBatch returns without enqueueing any new rows, without calling
    // Destination.transform, and without advancing fill_cursor.
    test(
      'REQ-d00128-I: fillBatch is a no-op when FIFO head is wedged',
      () async {
        // Step 1: enqueue one matching event and let fillBatch promote it
        // into a FIFO row, then mark that row wedged. This is the wedge
        // setup the new behavior must respect.
        await _appendEvent(
          backend,
          eventId: 'e1',
          clientTimestamp: DateTime.utc(2026, 4, 22, 11),
        );
        final dest = FakeDestination(id: 'fake', batchCapacity: 10);
        final schedule = DestinationSchedule(
          startDate: DateTime.utc(2026, 4, 1),
        );
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );
        final wedgedRow = await backend.readFifoHead('fake');
        expect(wedgedRow, isNotNull);
        await backend.markFinal('fake', wedgedRow!.entryId, FinalStatus.wedged);

        // Step 2: snapshot post-wedge state.
        final cursorBeforeSecondFill = await backend.readFillCursor('fake');
        final transformCallsBefore = dest.transformCalls;

        // Step 3: append more matching events, then call fillBatch again.
        // The new behavior: it must NOT promote them, NOT advance cursor,
        // NOT call transform.
        await _appendEvent(
          backend,
          eventId: 'e2',
          clientTimestamp: DateTime.utc(2026, 4, 22, 11, 30),
        );
        await _appendEvent(
          backend,
          eventId: 'e3',
          clientTimestamp: DateTime.utc(2026, 4, 22, 11, 45),
        );

        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        );

        // Cursor unchanged.
        expect(await backend.readFillCursor('fake'), cursorBeforeSecondFill);
        // No additional transform calls.
        expect(dest.transformCalls, transformCallsBefore);
        // Head is still the wedged row, with status wedged.
        final headAfter = await backend.readFifoHead('fake');
        expect(headAfter, isNotNull);
        expect(headAfter!.entryId, wedgedRow.entryId);
        expect(headAfter.finalStatus, FinalStatus.wedged);
      },
    );

    // Verifies: REQ-d00128-I (recovery half) — after the wedged head is
    // tombstoned and refilled, the next fillBatch promotes events that
    // arrived during the wedge in one pass against the rewound cursor.
    test('REQ-d00128-I: post-tombstoneAndRefill, fillBatch promotes wedge-era '
        'events in one pass', () async {
      // Setup: destination with batchCapacity=10 (so a single fillBatch
      // can produce one row covering many events).
      final dest = FakeDestination(id: 'fake', batchCapacity: 10);
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      DateTime clock() => DateTime.utc(2026, 4, 22, 12);

      // Phase A: enqueue + wedge a single-event row (e1).
      await _appendEvent(
        backend,
        eventId: 'e1',
        clientTimestamp: DateTime.utc(2026, 4, 22, 10),
      );
      await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);
      final wedged = await backend.readFifoHead('fake');
      expect(wedged, isNotNull);
      await backend.markFinal('fake', wedged!.entryId, FinalStatus.wedged);

      // Phase B: append two MORE matching events while wedged. fillBatch
      // wedge-skips both invocations — no FIFO rows added, no cursor
      // advance.
      await _appendEvent(
        backend,
        eventId: 'e2',
        clientTimestamp: DateTime.utc(2026, 4, 22, 10, 30),
      );
      await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);
      await _appendEvent(
        backend,
        eventId: 'e3',
        clientTimestamp: DateTime.utc(2026, 4, 22, 11),
      );
      await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);

      // Sanity: still only the wedged row in the FIFO.
      expect(await backend.readFifoHead('fake'), isNotNull);
      expect((await backend.readFifoHead('fake'))!.entryId, wedged.entryId);

      // Phase C: operator tombstoneAndRefill — flips wedged -> tombstoned,
      // rewinds fill_cursor. Uses a fresh registry bound to the same
      // backend so the wedge-recovery audit emission has somewhere to
      // land. The destination is registered + scheduled to satisfy the
      // registry's pre-mutation invariants without re-running fillBatch.
      final deps = buildAuditedRegistryDeps(backend);
      final wedgeRecoveryRegistry = DestinationRegistry(
        backend: backend,
        eventStore: deps.eventStore,
      );
      await wedgeRecoveryRegistry.addDestination(dest, initiator: _testInit);
      await wedgeRecoveryRegistry.tombstoneAndRefill(
        'fake',
        wedged.entryId,
        initiator: _testInit,
      );

      // Phase D: next fillBatch. Promotes e1, e2, e3 in ONE pass into
      // ONE FIFO row (batchCapacity=10 admits all three), advances
      // fill_cursor to e3.sequenceNumber.
      await fillBatch(dest, backend: backend, schedule: schedule, clock: clock);

      final fresh = await backend.readFifoHead('fake');
      expect(fresh, isNotNull);
      expect(fresh!.eventIds, ['e1', 'e2', 'e3']);
      expect(fresh.finalStatus, isNull);
      expect(await backend.readFillCursor('fake'), 3);
    });

    // Verifies: REQ-d00152-B+E — when destination.serializesNatively is
    // true, fillBatch builds a fresh BatchEnvelopeMetadata from `source`
    // (mints batch_id, stamps sent_at = now, copies hopId / identifier /
    // softwareVersion) and enqueues via nativeEnvelope:. The destination's
    // transform is NOT called — NativeDestination's transform throws if
    // invoked.
    test('REQ-d00152-B+E: native destination — fillBatch mints envelope '
        'from source, stores envelope_metadata, nulls wire_payload', () async {
      const source = Source(
        hopId: 'mobile-device',
        identifier: 'device-fb-native',
        softwareVersion: 'clinical_diary@1.2.3',
      );
      final clientTs = DateTime.utc(2026, 4, 22, 10);
      await _appendEvent(backend, eventId: 'e1', clientTimestamp: clientTs);
      await _appendEvent(backend, eventId: 'e2', clientTimestamp: clientTs);

      final dest = NativeDestination(id: 'native', batchCapacity: 5);
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      final fillClock = DateTime.utc(2026, 4, 22, 12);

      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        source: source,
        clock: () => fillClock,
      );

      final head = await backend.readFifoHead('native');
      expect(head, isNotNull);
      expect(head!.eventIds, ['e1', 'e2']);
      expect(head.wireFormat, BatchEnvelope.wireFormat);
      expect(
        head.wirePayload,
        isNull,
        reason: 'native rows MUST null wire_payload (REQ-d00119-B)',
      );
      expect(head.envelopeMetadata, isNotNull);
      expect(head.envelopeMetadata!.senderHop, 'mobile-device');
      expect(head.envelopeMetadata!.senderIdentifier, 'device-fb-native');
      expect(
        head.envelopeMetadata!.senderSoftwareVersion,
        'clinical_diary@1.2.3',
      );
      expect(head.envelopeMetadata!.batchFormatVersion, '1');
      expect(
        head.envelopeMetadata!.sentAt,
        fillClock,
        reason: 'fillBatch stamps sent_at from the now() clock at enqueue',
      );
      expect(
        head.envelopeMetadata!.batchId,
        matches(RegExp(r'^[0-9a-f-]{36}$')),
        reason: 'fillBatch mints a fresh v4-UUID batch_id per native batch',
      );
      expect(await backend.readFillCursor('native'), 2);
    });

    // Verifies: REQ-d00152-B+E — fillBatch on a native destination
    // without a `source:` parameter throws ArgumentError. The native
    // branch needs Source to stamp envelope identity; the absence is a
    // caller-bug surfaced loudly rather than a silent partial enqueue.
    test('REQ-d00152-B+E: native destination without source: throws '
        'ArgumentError', () async {
      final clientTs = DateTime.utc(2026, 4, 22, 10);
      await _appendEvent(backend, eventId: 'e1', clientTimestamp: clientTs);

      final dest = NativeDestination(id: 'native');
      final schedule = DestinationSchedule(startDate: DateTime.utc(2026, 4, 1));
      await expectLater(
        fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          clock: () => DateTime.utc(2026, 4, 22, 12),
        ),
        throwsArgumentError,
      );
      // No FIFO row was written, no cursor advance.
      expect(await backend.readFifoHead('native'), isNull);
      expect(await backend.readFillCursor('native'), -1);
    });
  });
}
