import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<DestinationRegistry> _mkRegistry(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  final backend = SembastBackend(database: db);
  // Build a minimal EventStore wired with the system entry types so
  // registry mutations can stamp their REQ-d00129-J/K/L/M/N audit
  // events without bootstrapping the full datastore facade.
  final entryTypes = EntryTypeRegistry();
  for (final defn in kSystemEntryTypes) {
    entryTypes.register(defn);
  }
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final eventStore = EventStore(
    backend: backend,
    entryTypes: entryTypes,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'demo-test',
      softwareVersion: 'demo@1.0.0',
    ),
    securityContexts: securityContexts,
  );
  return DestinationRegistry(backend: backend, eventStore: eventStore);
}

Future<AppState> _mkState(String path) async {
  final registry = await _mkRegistry(path);
  return AppState(
    registry: registry,
    policyNotifier: ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy),
  );
}

void main() {
  var counter = 0;
  String nextPath() => 'app-state-${++counter}.db';

  group('AppState selection state', () {
    test('all three selections start null', () async {
      final s = await _mkState(nextPath());
      expect(s.selectedAggregateId, isNull);
      expect(s.selectedEventId, isNull);
      expect(s.selectedFifoRowId, isNull);
    });

    test(
      'selectAggregate sets aggregate and clears event + fifo row',
      () async {
        final s = await _mkState(nextPath());
        s
          ..selectEvent('e-1')
          ..selectAggregate('agg-1');
        expect(s.selectedAggregateId, 'agg-1');
        expect(s.selectedEventId, isNull);
        expect(s.selectedFifoRowId, isNull);
      },
    );

    test('selectEvent clears aggregate and fifo row', () async {
      final s = await _mkState(nextPath());
      s
        ..selectAggregate('agg-1')
        ..selectFifoRow('Primary', 'f-1')
        ..selectEvent('e-1');
      expect(s.selectedEventId, 'e-1');
      expect(s.selectedAggregateId, isNull);
      expect(s.selectedFifoRowId, isNull);
      expect(s.selectedFifoDestinationId, isNull);
    });

    test(
      'selectFifoRow clears aggregate and event; carries destination',
      () async {
        final s = await _mkState(nextPath());
        s
          ..selectAggregate('agg-1')
          ..selectFifoRow('Secondary', 'f-1');
        expect(s.selectedFifoRowId, 'f-1');
        expect(s.selectedFifoDestinationId, 'Secondary');
        expect(s.selectedAggregateId, isNull);
        expect(s.selectedEventId, isNull);
      },
    );

    test('clearSelection resets all three fields and notifies once', () async {
      final s = await _mkState(nextPath());
      s.selectAggregate('agg-1');
      var calls = 0;
      void listener() => calls++;
      s.addListener(listener);
      addTearDown(() => s.removeListener(listener));
      s.clearSelection();
      expect(s.selectedAggregateId, isNull);
      expect(s.selectedEventId, isNull);
      expect(s.selectedFifoRowId, isNull);
      expect(calls, 1);
    });

    test('each selection setter notifies listeners exactly once', () async {
      final s = await _mkState(nextPath());
      var calls = 0;
      void listener() => calls++;
      s.addListener(listener);
      addTearDown(() => s.removeListener(listener));
      s.selectAggregate('agg-1');
      expect(calls, 1);
      s.selectEvent('e-1');
      expect(calls, 2);
      s.selectFifoRow('Primary', 'f-1');
      expect(calls, 3);
    });
  });

  group('AppState destination registry binding', () {
    test('destinations is empty when registry has none', () async {
      final s = await _mkState(nextPath());
      expect(s.destinations, isEmpty);
    });

    test('addDestination persists via registry and notifies', () async {
      final s = await _mkState(nextPath());
      var calls = 0;
      void listener() => calls++;
      s.addListener(listener);
      addTearDown(() => s.removeListener(listener));
      await s.addDestination(DemoDestination(id: 'Primary'));
      expect(s.destinations.length, 1);
      expect(s.destinations.first.id, 'Primary');
      expect(calls, 1);
    });

    test('destinations reflects every registered destination', () async {
      final s = await _mkState(nextPath());
      await s.addDestination(DemoDestination(id: 'a'));
      await s.addDestination(DemoDestination(id: 'b', allowHardDelete: true));
      expect(s.destinations.map((d) => d.id), <String>['a', 'b']);
      expect(s.destinations[1].allowHardDelete, isTrue);
    });
  });

  group('AppState policyNotifier exposure', () {
    test('returns the injected ValueNotifier<SyncPolicy>', () async {
      final policy = ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);
      final registry = await _mkRegistry(nextPath());
      final s = AppState(registry: registry, policyNotifier: policy);
      expect(identical(s.policyNotifier, policy), isTrue);
    });
  });
}
