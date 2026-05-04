import 'package:event_sourcing_datastore/src/destinations/destination_registry.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';
import '../test_support/registry_with_audit.dart';

const Initiator _testInit = AutomationInitiator(service: 'test-bootstrap');

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

void main() {
  group('DestinationRegistry (dynamic lifecycle, REQ-d00129)', () {
    late SembastBackend backend;
    late DestinationRegistry registry;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('registry-dynamic-$dbCounter.db');
      final deps = buildAuditedRegistryDeps(backend);
      registry = DestinationRegistry(
        backend: backend,
        eventStore: deps.eventStore,
      );
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00129-A — addDestination registers at any time; the
    // first addDestination lands a dormant schedule, and all() returns it.
    test(
      'REQ-d00129-A: addDestination registers and seeds a dormant schedule',
      () async {
        final d = FakeDestination(id: 'primary');
        await registry.addDestination(d, initiator: _testInit);

        expect(registry.all().map((x) => x.id), ['primary']);
        expect(registry.byId('primary'), same(d));
        final schedule = await registry.scheduleOf('primary');
        expect(schedule.isDormant, isTrue);
        expect(schedule.startDate, isNull);
        expect(schedule.endDate, isNull);
        // Persisted too (a later process restart recovers the dormant
        // state).
        final persisted = await backend.readSchedule('primary');
        expect(persisted, const DestinationSchedule());
      },
    );

    // Verifies: REQ-d00129-A — duplicate id throws ArgumentError on the
    // second addDestination.
    test(
      'REQ-d00129-A: addDestination with duplicate id throws ArgumentError',
      () async {
        await registry.addDestination(
          FakeDestination(id: 'primary'),
          initiator: _testInit,
        );
        await expectLater(
          registry.addDestination(
            FakeDestination(id: 'primary'),
            initiator: _testInit,
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00129-A — addDestination is allowed AFTER a prior
    // read of the registry (no freeze). This is the behavior change from
    // Phase 4's REQ-d00122-G.
    test('REQ-d00129-A: registry does NOT freeze on first read; subsequent '
        'addDestination succeeds', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      // Read the registry first — under the old contract this would
      // have frozen it.
      registry.all();
      await registry.addDestination(
        FakeDestination(id: 'secondary'),
        initiator: _testInit,
      );
      expect(registry.all().map((d) => d.id), ['primary', 'secondary']);
    });

    // Verifies: REQ-d00129-C — setStartDate assigns once; schedule
    // reflects the new startDate and persists.
    test(
      'REQ-d00129-C: setStartDate assigns a startDate and persists it',
      () async {
        await registry.addDestination(
          FakeDestination(id: 'primary'),
          initiator: _testInit,
        );
        final start = DateTime.utc(2026, 4, 1);
        await registry.setStartDate('primary', start, initiator: _testInit);

        final schedule = await registry.scheduleOf('primary');
        expect(schedule.startDate, start);
        expect(schedule.endDate, isNull);
        expect(schedule.isDormant, isFalse);
        final persisted = await backend.readSchedule('primary');
        expect(persisted?.startDate, start);
      },
    );

    // Verifies: REQ-d00129-C — startDate is immutable once set; a second
    // setStartDate throws StateError.
    test('REQ-d00129-C: setStartDate throws StateError when startDate is '
        'already set', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      await registry.setStartDate(
        'primary',
        DateTime.utc(2026, 4, 1),
        initiator: _testInit,
      );
      await expectLater(
        registry.setStartDate(
          'primary',
          DateTime.utc(2026, 5, 1),
          initiator: _testInit,
        ),
        throwsStateError,
      );
      // Value unchanged.
      final schedule = await registry.scheduleOf('primary');
      expect(schedule.startDate, DateTime.utc(2026, 4, 1));
    });

    // Verifies: REQ-d00129-F — setEndDate with a past endDate on a
    // currently-active destination returns closed.
    test('REQ-d00129-F: setEndDate returns closed when the call transitions '
        'active -> currently-closed', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      // startDate well in the past so the destination is active now.
      await registry.setStartDate(
        'primary',
        DateTime.utc(2020, 1, 1),
        initiator: _testInit,
      );
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final result = await registry.setEndDate(
        'primary',
        past,
        initiator: _testInit,
      );
      expect(result, SetEndDateResult.closed);
      final schedule = await registry.scheduleOf('primary');
      expect(schedule.endDate, past);
    });

    // Verifies: REQ-d00129-F — setEndDate with a future endDate on a
    // currently-active destination returns scheduled.
    test('REQ-d00129-F: setEndDate returns scheduled when endDate is in the '
        'future (active destination)', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      await registry.setStartDate(
        'primary',
        DateTime.utc(2020, 1, 1),
        initiator: _testInit,
      );
      final future = DateTime.now().add(const Duration(hours: 1));
      final result = await registry.setEndDate(
        'primary',
        future,
        initiator: _testInit,
      );
      expect(result, SetEndDateResult.scheduled);
    });

    // Verifies: REQ-d00129-F — overwriting an existing past endDate with
    // another past endDate leaves the classification unchanged and
    // returns applied.
    test('REQ-d00129-F: setEndDate returns applied when classification does '
        'not change relative to now', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      await registry.setStartDate(
        'primary',
        DateTime.utc(2020, 1, 1),
        initiator: _testInit,
      );
      final firstPast = DateTime.now().subtract(const Duration(hours: 2));
      await registry.setEndDate('primary', firstPast, initiator: _testInit);
      // Already closed; overwrite with another past endDate.
      final secondPast = DateTime.now().subtract(const Duration(hours: 1));
      final result = await registry.setEndDate(
        'primary',
        secondPast,
        initiator: _testInit,
      );
      expect(result, SetEndDateResult.applied);
      final schedule = await registry.scheduleOf('primary');
      expect(schedule.endDate, secondPast);
    });

    // Verifies: REQ-d00129-G — deactivateDestination is a setEndDate(now)
    // shorthand; returns closed.
    test('REQ-d00129-G: deactivateDestination returns closed and stamps '
        'endDate at approximately now()', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      await registry.setStartDate(
        'primary',
        DateTime.utc(2020, 1, 1),
        initiator: _testInit,
      );
      final before = DateTime.now();
      final result = await registry.deactivateDestination(
        'primary',
        initiator: _testInit,
      );
      final after = DateTime.now();
      expect(result, SetEndDateResult.closed);
      final schedule = await registry.scheduleOf('primary');
      expect(schedule.endDate, isNotNull);
      expect(
        schedule.endDate!.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        schedule.endDate!.isAfter(after.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    // Verifies: REQ-d00129-H — deleteDestination throws StateError when
    // the destination's allowHardDelete is false.
    test('REQ-d00129-H: deleteDestination throws StateError when '
        'allowHardDelete is false', () async {
      await registry.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _testInit,
      );
      await expectLater(
        registry.deleteDestination('primary', initiator: _testInit),
        throwsStateError,
      );
      // Still registered.
      expect(registry.byId('primary'), isNotNull);
    });

    // Verifies: REQ-d00129-H — when allowHardDelete is true,
    // deleteDestination unregisters + drops FIFO + drops schedule in one
    // transaction.
    test('REQ-d00129-H: deleteDestination drops FIFO store and schedule when '
        'allowHardDelete is true', () async {
      final d = FakeDestination(id: 'purgeable', allowHardDelete: true);
      await registry.addDestination(d, initiator: _testInit);
      // Enqueue one row to populate the FIFO store before the drop.
      await enqueueSingle(
        backend,
        'purgeable',
        eventId: 'e1',
        sequenceNumber: 1,
        wirePayload: <String, Object?>{'x': 'y'},
        wireFormat: 'fake-v1',
        transformVersion: 'fake-v1',
      );
      expect(await backend.readFifoHead('purgeable'), isNotNull);
      expect(await backend.readSchedule('purgeable'), isNotNull);

      await registry.deleteDestination('purgeable', initiator: _testInit);
      // Unregistered in-memory.
      expect(registry.byId('purgeable'), isNull);
      // FIFO store drained.
      expect(await backend.readFifoHead('purgeable'), isNull);
      // Schedule record dropped.
      expect(await backend.readSchedule('purgeable'), isNull);
    });

    // Defensive: deleting a destination that does not exist throws
    // ArgumentError (rather than silently succeeding).
    test(
      'deleteDestination throws ArgumentError when id is not registered',
      () async {
        await expectLater(
          registry.deleteDestination('ghost', initiator: _testInit),
          throwsArgumentError,
        );
      },
    );

    // Defensive: scheduleOf on a never-registered id throws
    // ArgumentError.
    test('scheduleOf throws ArgumentError when id is not registered', () async {
      await expectLater(registry.scheduleOf('ghost'), throwsArgumentError);
    });

    // Defensive: setStartDate and setEndDate both reject unknown ids.
    test(
      'setStartDate / setEndDate reject unknown ids with ArgumentError',
      () async {
        await expectLater(
          registry.setStartDate('ghost', DateTime.now(), initiator: _testInit),
          throwsArgumentError,
        );
        await expectLater(
          registry.setEndDate('ghost', DateTime.now(), initiator: _testInit),
          throwsArgumentError,
        );
      },
    );

    // Verifies: REQ-d00129-C — startDate immutability survives a process
    // restart. A fresh registry bound to the same backend must NOT let
    // setStartDate overwrite a previously-persisted startDate.
    test('REQ-d00129-C: setStartDate remains one-shot immutable across '
        'a fresh registry bound to the same backend (cold-restart)', () async {
      await registry.addDestination(
        FakeDestination(id: 'x', script: []),
        initiator: _testInit,
      );
      final originalStart = DateTime.utc(2026, 1, 1);
      await registry.setStartDate('x', originalStart, initiator: _testInit);

      // Simulate a process restart: construct a new registry over the
      // same backend, re-run bootstrap's addDestination call.
      final restartedDeps = buildAuditedRegistryDeps(backend);
      final restarted = DestinationRegistry(
        backend: backend,
        eventStore: restartedDeps.eventStore,
      );
      await restarted.addDestination(
        FakeDestination(id: 'x', script: []),
        initiator: _testInit,
      );

      // The persisted schedule must be preserved.
      final restored = await restarted.scheduleOf('x');
      expect(restored.startDate, originalStart);

      // Re-assignment is still rejected.
      await expectLater(
        restarted.setStartDate(
          'x',
          DateTime.utc(2027, 1, 1),
          initiator: _testInit,
        ),
        throwsStateError,
      );
    });

    // Verifies: REQ-d00129-F — replacing a future-dated endDate with
    // another future-dated endDate on an active destination does not
    // change the active-vs-closed classification AND does not newly
    // schedule a close (a close is already scheduled); the return code
    // is `applied`, not `scheduled`.
    test(
      'REQ-d00129-F: setEndDate returns applied when replacing a future '
      'endDate with another future endDate on an active destination',
      () async {
        await registry.addDestination(
          FakeDestination(id: 'x', script: []),
          initiator: _testInit,
        );
        await registry.setStartDate(
          'x',
          DateTime.now().subtract(const Duration(hours: 1)),
          initiator: _testInit,
        );

        // First future endDate — scheduled.
        final firstResult = await registry.setEndDate(
          'x',
          DateTime.now().add(const Duration(days: 7)),
          initiator: _testInit,
        );
        expect(firstResult, SetEndDateResult.scheduled);

        // Different future endDate — no state change, already scheduled.
        final secondResult = await registry.setEndDate(
          'x',
          DateTime.now().add(const Duration(days: 14)),
          initiator: _testInit,
        );
        expect(secondResult, SetEndDateResult.applied);
      },
    );
  });
}
