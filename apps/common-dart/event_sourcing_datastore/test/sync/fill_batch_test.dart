import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/sync/fill_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';

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
  });
}
