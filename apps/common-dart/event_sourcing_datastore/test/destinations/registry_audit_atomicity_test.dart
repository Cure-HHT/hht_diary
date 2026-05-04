// Atomicity test for the in-transaction config-change audit emissions
// added in Phase 4.17c-g. When the audit appendInTxn throws inside the
// registry mutation's transaction, the WHOLE transaction rolls back —
// the schedule write, FIFO mutation, and any other side effect commit
// only when the audit also commits. This is REQ-d00129-N's atomicity
// half: the partial state ("mutation persisted, audit lost") must be
// unobservable.
//
// Verifies: REQ-d00129-N — audit failure rolls back the underlying
// mutation. Tested by registering a `DestinationRegistry` against an
// `EventStore` whose `EntryTypeRegistry` is truncated — only the
// system entry types needed to reach the mutation under test are
// registered, so the FAILING audit append (the one whose entry type
// is intentionally omitted) throws via `_validateAppendInputs`. The
// surrounding `backend.transaction` rolls back: the prior mutation's
// side effects (schedule write, FIFO drop, etc.) do not persist.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';
import '../test_support/registry_with_audit.dart';

const _testInit = AutomationInitiator(service: 'test-bootstrap');

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

/// Build a `DestinationRegistry` whose `EventStore` has an EntryTypeRegistry
/// with NO system entry types registered. Every audit emission throws
/// `ArgumentError` at the registry's pre-I/O validation step, which
/// surfaces synchronously inside the surrounding `backend.transaction`
/// and rolls it back.
DestinationRegistry _buildBrokenRegistry(SembastBackend backend) {
  final deps = buildAuditedRegistryDeps(
    backend,
    auditEntryTypeOverride: const <EntryTypeDefinition>[],
  );
  return DestinationRegistry(backend: backend, eventStore: deps.eventStore);
}

/// Build a `DestinationRegistry` whose `EntryTypeRegistry` covers only
/// the system entry types in [allowed]. Audit emissions for any other
/// system entry type throw `ArgumentError` and roll back the
/// surrounding transaction.
///
/// Used to test mid-flow audit failure: register the entry types
/// needed to land setup mutations (e.g., addDestination + setStartDate),
/// but omit the entry type the mutation under test would emit. The
/// setup mutations succeed, then the mutation under test fails inside
/// its txn, rolling back the underlying schedule/FIFO write.
DestinationRegistry _buildPartialRegistry(
  SembastBackend backend, {
  required Iterable<String> allowed,
}) {
  final allowedSet = allowed.toSet();
  final deps = buildAuditedRegistryDeps(
    backend,
    auditEntryTypeOverride: kSystemEntryTypes
        .where((d) => allowedSet.contains(d.id))
        .toList(),
  );
  return DestinationRegistry(backend: backend, eventStore: deps.eventStore);
}

void main() {
  group('DestinationRegistry mutation atomicity (REQ-d00129-N)', () {
    late SembastBackend backend;
    var counter = 0;

    setUp(() async {
      counter += 1;
      backend = await _openBackend('atomicity-$counter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00129-N — addDestination's schedule write rolls
    // back when the audit append fails. The destination must NOT appear
    // persisted (readSchedule returns null afterwards).
    test(
      'addDestination: audit failure rolls back the schedule write',
      () async {
        final registry = _buildBrokenRegistry(backend);
        final dest = FakeDestination(id: 'atomic');

        await expectLater(
          registry.addDestination(dest, initiator: _testInit),
          throwsArgumentError,
        );

        // Schedule did NOT persist — txn rolled back.
        expect(await backend.readSchedule('atomic'), isNull);
        // In-memory state was not updated (we update only after commit).
        expect(registry.byId('atomic'), isNull);
      },
    );

    // Verifies: REQ-d00129-N — setStartDate's schedule write rolls back
    // when the audit append fails. Built via a `DestinationRegistry`
    // bound to an `EntryTypeRegistry` that registers
    // `system.destination_registered` (so addDestination's setup
    // succeeds and the in-memory `_destinations` map is populated) but
    // does NOT register `system.destination_start_date_set` (so
    // setStartDate's audit append throws inside the txn). The
    // surrounding `backend.transaction` rolls back the schedule write;
    // afterwards `schedule.startDate` is still null.
    test('setStartDate: audit failure rolls back the schedule write', () async {
      final registry = _buildPartialRegistry(
        backend,
        allowed: const <String>{kDestinationRegisteredEntryType},
      );

      // Setup: addDestination succeeds because its audit type IS
      // registered. The destination is in the in-memory cache and a
      // dormant schedule is persisted.
      await registry.addDestination(
        FakeDestination(id: 'atomic'),
        initiator: _testInit,
      );
      final scheduleBefore = await backend.readSchedule('atomic');
      expect(scheduleBefore, isNotNull);
      expect(scheduleBefore!.startDate, isNull);

      // Act: setStartDate's audit type is NOT registered, so the
      // audit append throws inside the txn and rolls back the
      // schedule write.
      await expectLater(
        registry.setStartDate(
          'atomic',
          DateTime.utc(2026, 1, 1),
          initiator: _testInit,
        ),
        throwsArgumentError,
      );

      // Assert: persisted schedule is unchanged (startDate still
      // null) — the schedule write rolled back with the audit.
      final scheduleAfter = await backend.readSchedule('atomic');
      expect(scheduleAfter, isNotNull);
      expect(scheduleAfter!.startDate, isNull);
    });

    // Verifies: REQ-d00129-N — deleteDestination's FIFO + schedule
    // drop rolls back when the audit append fails. Built via a
    // `DestinationRegistry` bound to an `EntryTypeRegistry` that
    // registers `system.destination_registered` and
    // `system.destination_start_date_set` (so addDestination +
    // setStartDate setup succeed) but does NOT register
    // `system.destination_deleted` (so deleteDestination's audit
    // append throws inside the txn). The surrounding
    // `backend.transaction` rolls back the FIFO + schedule drops;
    // afterwards the destination is still registered and its FIFO
    // head row + schedule are still present.
    test(
      'deleteDestination: audit failure rolls back FIFO + schedule drop',
      () async {
        final registry = _buildPartialRegistry(
          backend,
          allowed: const <String>{
            kDestinationRegisteredEntryType,
            kDestinationStartDateSetEntryType,
          },
        );

        // Setup: register a deletable destination, set its startDate,
        // and enqueue a FIFO row so the FIFO store is non-empty. Both
        // mutations succeed (their audit types are registered).
        await registry.addDestination(
          FakeDestination(id: 'purgeable', allowHardDelete: true),
          initiator: _testInit,
        );
        await registry.setStartDate(
          'purgeable',
          DateTime.utc(2020, 1, 1),
          initiator: _testInit,
        );
        await enqueueSingle(
          backend,
          'purgeable',
          eventId: 'evt-1',
          sequenceNumber: 1,
        );
        // Sanity: schedule + FIFO head present.
        expect(await backend.readSchedule('purgeable'), isNotNull);
        expect(await backend.readFifoHead('purgeable'), isNotNull);

        // Act: deleteDestination's audit type is NOT registered, so
        // the audit append throws inside the txn and rolls back the
        // FIFO + schedule drops.
        await expectLater(
          registry.deleteDestination('purgeable', initiator: _testInit),
          throwsArgumentError,
        );

        // Assert: destination is still registered (in-memory state
        // is updated only after the txn commits) AND the schedule +
        // FIFO head are still persisted.
        expect(registry.byId('purgeable'), isNotNull);
        expect(await backend.readSchedule('purgeable'), isNotNull);
        expect(await backend.readFifoHead('purgeable'), isNotNull);
      },
    );
  });
}
