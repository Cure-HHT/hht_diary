import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';

/// Phase 4.3 end-to-end smoke test.
///
/// No new REQs — this asserts the composition of every Phase-4.3 surface:
/// `bootstrapAppendOnlyDatastore` → `EntryService.record` → `fillBatch` →
/// `SyncCycle.call` → drain → `Destination.send` → row marked `sent`.
/// A regression that breaks any of those wires fails this test even if
/// the per-feature tests still pass individually.
void main() {
  test(
    'Phase 4.3 end-to-end: bootstrap → record → fillBatch → drain → sent',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'e2e-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final backend = SembastBackend(database: db);
      addTearDown(backend.close);

      const demoNoteDefn = EntryTypeDefinition(
        id: 'demo_note',
        version: '1',
        name: 'demo_note',
        widgetId: 'widget-demo_note',
        widgetConfig: <String, Object?>{},
      );
      final dest = FakeDestination(
        id: 'primary',
        script: <SendResult>[const SendOk()],
        batchCapacity: 5,
      );

      // Step 1: bootstrap wires the type registry, destination registry,
      // security-context store, and EventStore into AppendOnlyDatastore.
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: const Source(
          hopId: 'mobile-device',
          identifier: 'device-e2e',
          softwareVersion: 'clinical_diary@1.0.0+1',
        ),
        entryTypes: [demoNoteDefn],
        destinations: [dest],
      );
      final typeReg = ds.entryTypes;
      final destReg = ds.destinations;

      // Step 2: open the destination by setting startDate to one hour
      // before the recording clock. Replay runs synchronously inside
      // setStartDate but finds no events (event log is empty), so the
      // side effect is just the schedule write.
      final startDate = DateTime.utc(2026, 4, 22, 9);
      final recordingClock = DateTime.utc(2026, 4, 22, 9, 30);
      // fillBatch's window upper bound is min(endDate, now()); using a
      // later clock than the event's clientTimestamp gives the
      // [startDate, upper] window non-zero margin around the event so
      // a future off-by-one in the boundary check (isAfter vs >=)
      // surfaces here rather than silently dropping the event.
      final fillBatchClock = DateTime.utc(2026, 4, 22, 10);
      await destReg.setStartDate('primary', startDate);

      final schedule = await destReg.scheduleOf('primary');
      expect(schedule.startDate, startDate);

      // Step 3: record one event via EntryService. The fire-and-forget
      // syncCycleTrigger records its calls; we drive sync manually below
      // so the assertions don't race the unawaited trigger.
      final triggerCalls = <DateTime>[];
      final svc = EntryService(
        backend: backend,
        entryTypes: typeReg,
        deviceInfo: const DeviceInfo(
          deviceId: 'device-e2e',
          softwareVersion: 'clinical_diary@1.0.0+1',
          userId: 'user-e2e',
        ),
        syncCycleTrigger: () async {
          triggerCalls.add(DateTime.now());
        },
        clock: () => recordingClock,
      );

      final appended = await svc.record(
        entryType: 'demo_note',
        aggregateId: 'agg-A',
        eventType: 'finalized',
        answers: const <String, Object?>{'title': 'hello'},
      );
      expect(appended, isNotNull);
      expect(appended!.aggregateId, 'agg-A');
      expect(appended.entryType, 'demo_note');
      expect(triggerCalls, hasLength(1));

      // The returned StoredEvent is constructed inside the transaction
      // body; if the underlying append silently dropped the row, the
      // returned object would still be valid. Assert the event log has
      // the event so a broken appendEvent surfaces here.
      final logEvents = await backend.findAllEvents();
      expect(logEvents, hasLength(1));
      expect(logEvents.single.eventId, appended.eventId);

      // Step 4: fillBatch promotes the event log entry into the
      // destination's FIFO. SyncCycle is drain-only (Phase 4 wiring), so
      // the test drives fillBatch explicitly before invoking drain.
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        clock: () => fillBatchClock,
      );

      // FIFO head is now pending — proves fillBatch enqueued the row.
      final pendingHead = await backend.readFifoHead('primary');
      expect(pendingHead, isNotNull);
      expect(pendingHead!.eventIds, [appended.eventId]);
      expect(pendingHead.finalStatus, isNull);

      // Step 5: SyncCycle.call drains the FIFO. The destination's
      // scripted `SendOk` flips the row to sent.
      final sync = SyncCycle(
        backend: backend,
        registry: destReg,
        clock: () => fillBatchClock,
      );
      await sync.call();

      // Step 6: assertions proving the round trip succeeded end-to-end.
      // (a) destination.send was invoked exactly once with the wire
      // payload AND returned the scripted SendOk. Asserted first so a
      // silent failure inside SyncCycle._drainOrSwallow (which catches
      // every drain exception) surfaces with a clearer message than the
      // downstream "row still pending" check would.
      expect(dest.sent, hasLength(1));
      expect(dest.returned, [const SendOk()]);

      // (b) FIFO head is now empty: the only row was marked sent and
      // skipped by readFifoHead's pending-only filter.
      expect(await backend.readFifoHead('primary'), isNull);

      // (c) No exhausted (wedged) rows: drain succeeded.
      expect(await backend.anyFifoWedged(), isFalse);

      // (d) diary_entries materialized view has the entry.
      final entries = await backend.findEntries(entryType: 'demo_note');
      expect(entries, hasLength(1));
      expect(entries.first.entryId, 'agg-A');
      expect(entries.first.isComplete, isTrue);
      expect(entries.first.latestEventId, appended.eventId);

      // (e) fill_cursor advanced past the one event we recorded.
      expect(await backend.readFillCursor('primary'), appended.sequenceNumber);
    },
  );
}
