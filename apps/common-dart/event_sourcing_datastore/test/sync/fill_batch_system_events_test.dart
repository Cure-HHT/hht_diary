// Verifies: REQ-d00128-J — fillBatch admission of system events is
// driven entirely by SubscriptionFilter.matches via the
// includeSystemEvents flag. fillBatch holds no hard-drop guard against
// reserved system entry types; that decision lives on the destination's
// filter.
// Verifies: REQ-d00154-F — system events are visible to destinations
// that opt in (e.g. forensic / audit-mirroring destinations) and are
// not visible to destinations that do not.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';

const _user = UserInitiator('demo-user-1');
const _automation = AutomationInitiator(service: 'fill-batch-system-test');
const _installUUID = 'fill-batch-system-test-install';
const _source = Source(
  hopId: 'mobile-device',
  identifier: _installUUID,
  softwareVersion: 'fill-batch-system-test@1.0.0',
);

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<AppendOnlyDatastore> _bootstrap(SembastBackend backend) {
  return bootstrapAppendOnlyDatastore(
    backend: backend,
    source: _source,
    entryTypes: const <EntryTypeDefinition>[],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
    initialViewTargetVersions: const <String, Map<String, int>>{},
  );
}

void main() {
  group('fillBatch — system event admission via SubscriptionFilter', () {
    late SembastBackend backend;
    late AppendOnlyDatastore ds;
    var counter = 0;

    setUp(() async {
      counter += 1;
      backend = await _openBackend('fill-batch-system-$counter.db');
      ds = await _bootstrap(backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00128-J + REQ-d00154-F — a destination that opts
    // in via includeSystemEvents=true sees system audit events flow
    // into its FIFO via fillBatch; a peer destination without the
    // opt-in sees only user events.
    //
    // The setup registers two destinations (with future startDates so
    // the addDestination calls themselves do NOT trigger replay) and
    // then sets each destination's startDate to a past time. Each
    // setStartDate invocation:
    //   1. emits a system.destination_start_date_set audit event;
    //   2. triggers historical replay for that one destination, which
    //      re-uses the same admission logic as fillBatch.
    // After both setStartDate calls, every prior system audit (the
    // two destination_registered events plus the one
    // destination_start_date_set event preceding the second
    // setStartDate) is in the event log past each destination's
    // fill_cursor.
    //
    // Calling fillBatch on each destination then exercises live-path
    // admission. Assertions inspect FIFO contents:
    //   - audit destination's FIFO contains every prior
    //     system.destination_* audit;
    //   - user destination's FIFO contains zero system audits.
    test('REQ-d00128-J: includeSystemEvents=true admits system events through '
        'fillBatch; includeSystemEvents=false drops them', () async {
      // Build two destinations sharing one backend.
      // Audit destination opts in to system events with no entryTypes
      // allow-list (system events bypass entryTypes when the flag is
      // true; user events fall through and are rejected because
      // entryTypes is empty — REQ-d00122-F).
      final auditDest = FakeDestination(
        id: 'audit-mirror',
        filter: const SubscriptionFilter(
          entryTypes: <String>[],
          includeSystemEvents: true,
        ),
      );
      // User destination uses the default (includeSystemEvents=false)
      // and a null entryTypes list (matches all user events).
      final userDest = FakeDestination(
        id: 'user-stream',
        filter: const SubscriptionFilter(),
      );

      // Register both destinations with future start dates so the
      // addDestination calls do not trigger replay.
      final futureStart = DateTime.utc(2099, 1, 1);
      await ds.destinations.addDestination(auditDest, initiator: _automation);
      await ds.destinations.addDestination(userDest, initiator: _automation);
      await ds.destinations.setStartDate(
        'audit-mirror',
        futureStart,
        initiator: _automation,
      );
      await ds.destinations.setStartDate(
        'user-stream',
        futureStart,
        initiator: _automation,
      );

      // Snapshot the audit events the two destinations should now see
      // when their schedules become live: every destination_registered
      // and destination_start_date_set event in the log.
      final auditEvents = await backend.findAllEvents();
      final systemAuditCount = auditEvents
          .where((e) => kReservedSystemEntryTypeIds.contains(e.entryType))
          .length;
      expect(
        systemAuditCount,
        greaterThanOrEqualTo(4),
        reason:
            '2 destination_registered + 2 destination_start_date_set '
            'audits should now be in the event log',
      );

      // Now activate fillBatch by widening the time window. We rewrite
      // the schedule via the backend directly to flip startDate into
      // the past WITHOUT re-running setStartDate (which would emit
      // another audit and trigger replay — both legitimate but they
      // would muddy the assertion). The startDate change does not
      // emit a new audit because it does not go through the registry.
      // fillBatch then walks the log past fill_cursor (which is still
      // -1 because no live promotion has run for either destination)
      // and applies SubscriptionFilter.matches per destination.
      //
      // The clock passed to fillBatch must be at or after every
      // emitted audit's clientTimestamp (audits are stamped with
      // wall-clock now() at emission). Use a clock 24h past real
      // wall-clock time so the time window comfortably contains
      // every prior audit.
      final now = DateTime.now().toUtc().add(const Duration(days: 1));
      final liveSchedule = DestinationSchedule(
        startDate: DateTime.utc(2020, 1, 1),
      );
      await backend.writeSchedule('audit-mirror', liveSchedule);
      await backend.writeSchedule('user-stream', liveSchedule);

      // Promote into FIFOs. FakeDestination's batchCapacity is 1, so
      // each event lands in its own FIFO row; we run fillBatch in a
      // loop until the cursor catches up to the log tail.
      Future<void> runUntilQuiescent(String destId) async {
        // Worst case: one fillBatch per event in the log. Bound the
        // loop generously to avoid infinite-loop risk if the contract
        // regresses.
        for (var i = 0; i < 64; i++) {
          final cursorBefore = await backend.readFillCursor(destId);
          await fillBatch(
            ds.destinations.byId(destId)!,
            backend: backend,
            schedule: liveSchedule,
            source: _source,
            clock: () => now,
          );
          final cursorAfter = await backend.readFillCursor(destId);
          if (cursorAfter == cursorBefore) return;
        }
        fail('fillBatch did not reach quiescence on $destId');
      }

      await runUntilQuiescent('audit-mirror');
      await runUntilQuiescent('user-stream');

      // Resolve eventIds in each FIFO back to their entryType so we
      // can categorize what was admitted.
      Future<List<String>> entryTypesInFifo(String destId) async {
        final fifo = await backend.listFifoEntries(destId);
        final eventIds = fifo.expand((row) => row.eventIds).toSet();
        if (eventIds.isEmpty) return <String>[];
        final all = await backend.findAllEvents();
        return all
            .where((e) => eventIds.contains(e.eventId))
            .map((e) => e.entryType)
            .toList();
      }

      final auditFifoTypes = await entryTypesInFifo('audit-mirror');
      final userFifoTypes = await entryTypesInFifo('user-stream');

      // Audit destination: every event in its FIFO is a reserved
      // system entry type, and the count matches the system-audit
      // count seeded above.
      expect(
        auditFifoTypes,
        isNotEmpty,
        reason:
            'audit destination must receive system events when '
            'includeSystemEvents=true',
      );
      for (final t in auditFifoTypes) {
        expect(
          kReservedSystemEntryTypeIds.contains(t),
          isTrue,
          reason:
              'audit-mirror should only receive reserved system '
              'entry types (entryTypes is []), got $t',
        );
      }
      expect(auditFifoTypes, hasLength(systemAuditCount));

      // User destination: no system events admitted. (Its filter has
      // includeSystemEvents=false; entryTypes is null, so user events
      // are admitted, but the log so far only contains system audits.)
      for (final t in userFifoTypes) {
        expect(
          kReservedSystemEntryTypeIds.contains(t),
          isFalse,
          reason:
              'user-stream must NOT receive reserved system entry '
              'types when includeSystemEvents is false (default), got $t',
        );
      }
    });

    // Verifies: REQ-d00128-J — explicit symmetric assertion that a
    // destination with the default filter (includeSystemEvents=false)
    // never admits system events even when the destination's
    // entryTypes list contains a reserved id by mistake. The
    // includeSystemEvents flag wins; entryTypes is consulted only for
    // user events.
    test('REQ-d00128-J: includeSystemEvents=false rejects system events '
        'even if entryTypes contains a reserved id', () async {
      final dest = FakeDestination(
        id: 'misconfigured',
        // Caller mistakenly listed a reserved id. The flag still
        // governs admission — the reserved id is rejected by matches.
        filter: const SubscriptionFilter(
          entryTypes: [kDestinationRegisteredEntryType],
        ),
      );
      await ds.destinations.addDestination(dest, initiator: _user);
      await ds.destinations.setStartDate(
        'misconfigured',
        DateTime.utc(2020, 1, 1),
        initiator: _user,
      );
      await fillBatch(
        dest,
        backend: backend,
        schedule: await ds.destinations.scheduleOf('misconfigured'),
        source: _source,
        clock: () => DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      final fifo = await backend.listFifoEntries('misconfigured');
      // No FIFO row should reference a reserved system entry type.
      if (fifo.isEmpty) return;
      final eventIds = fifo.expand((row) => row.eventIds).toSet();
      final all = await backend.findAllEvents();
      final admittedTypes = all
          .where((e) => eventIds.contains(e.eventId))
          .map((e) => e.entryType);
      for (final t in admittedTypes) {
        expect(
          kReservedSystemEntryTypeIds.contains(t),
          isFalse,
          reason:
              'destination with includeSystemEvents=false must not '
              'admit reserved system entry types, got $t',
        );
      }
    });
  });
}
