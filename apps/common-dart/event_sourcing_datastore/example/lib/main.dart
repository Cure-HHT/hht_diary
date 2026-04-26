import 'dart:async';
import 'dart:io';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/dual_demo_app.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class _PaneRuntime {
  _PaneRuntime({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.dbPath,
    required this.tick,
    required this.policyNotifier,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final String dbPath;
  final Timer tick;
  final ValueNotifier<SyncPolicy> policyNotifier;
}

/// Bootstraps one datastore with its own destinations and starts a
/// 1-second sync tick. The optional [bridge] is wired into the Native
/// destination's `send()` so mobile's outgoing wire stream lands in
/// portal's `EventStore.ingestBatch`. The portal pane passes
/// `bridge: null` so its Native destination's `send()` is a no-op
/// simulator (existing behavior).
// Implements: REQ-d00134 — single init point: registers entry types,
// destinations, materializer. Implements: REQ-d00125 — 1-second tick
// drives fillBatch + drain per destination with live policy from
// the per-pane policyNotifier.
Future<_PaneRuntime> _bootstrapPane({
  required String dbPath,
  required Source source,
  DownstreamBridge? bridge,
}) async {
  final db = await databaseFactoryIo.openDatabase(dbPath);
  final backend = SembastBackend(database: db);
  final policyNotifier = ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);

  final primary = DemoDestination(
    id: 'Primary',
    filter: const SubscriptionFilter(
      entryTypes: <String>[
        'demo_note',
        'red_button_pressed',
        'green_button_pressed',
      ],
    ),
  );
  final secondary = DemoDestination(
    id: 'Secondary',
    allowHardDelete: true,
    filter: const SubscriptionFilter(
      entryTypes: <String>['green_button_pressed', 'blue_button_pressed'],
    ),
  );
  final native = NativeDemoDestination(id: 'Native', bridge: bridge);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, native],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      // DiaryEntriesMaterializer.appliesTo gates on aggregateType == 'DiaryEntry',
      // so only demo_note (the sole entry type with aggregateType 'DiaryEntry'
      // in the demo) needs a target version in the diary_entries view.
      // Action-button entry types route through different aggregate types
      // and never reach this materializer's promoter.
      'diary_entries': <String, int>{'demo_note': 1},
    },
  );

  final now = DateTime.now().toUtc();
  for (final id in <String>['Primary', 'Secondary', 'Native']) {
    final schedule = await datastore.destinations.scheduleOf(id);
    if (schedule.startDate == null) {
      await datastore.destinations.setStartDate(
        id,
        now,
        initiator: const AutomationInitiator(service: 'demo-bootstrap'),
      );
    }
  }

  final appState = AppState(
    registry: datastore.destinations,
    policyNotifier: policyNotifier,
  );

  // Implements: REQ-d00125-C, REQ-d00126-B+D — SyncCycle owns the
  // reentrancy guard and per-cycle policy resolution; we do per-pane
  // fillBatch in this tick body since SyncCycle covers drain + inbound
  // poll only.
  final syncCycle = SyncCycle(
    backend: backend,
    registry: datastore.destinations,
    policyResolver: () => policyNotifier.value,
  );
  final tick = Timer.periodic(const Duration(seconds: 1), (_) async {
    try {
      final destinations = datastore.destinations.all();
      for (final dest in destinations) {
        final schedule = await datastore.destinations.scheduleOf(dest.id);
        await fillBatch(
          dest,
          backend: backend,
          schedule: schedule,
          source: source,
        );
      }
      await syncCycle();
    } catch (e, s) {
      stderr.writeln('[demo:${source.hopId}] sync tick error: $e\n$s');
    }
  });

  return _PaneRuntime(
    datastore: datastore,
    backend: backend,
    appState: appState,
    dbPath: dbPath,
    tick: tick,
    policyNotifier: policyNotifier,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSupportDir = await getApplicationSupportDirectory();
  final demoDir = Directory(
    p.join(appSupportDir.path, 'event_sourcing_datastore_demo'),
  );
  await demoDir.create(recursive: true);

  final mobileDbPath = p.join(demoDir.path, 'demo.db');
  final portalDbPath = p.join(demoDir.path, 'demo_portal.db');
  stdout
    ..writeln('[demo] mobile storage: $mobileDbPath')
    ..writeln('[demo] portal storage: $portalDbPath');

  // Portal must be bootstrapped first so the bridge can capture its
  // EventStore before mobile's NativeDemoDestination is constructed.
  final portal = await _bootstrapPane(
    dbPath: portalDbPath,
    source: const Source(
      hopId: 'portal',
      identifier: 'demo-portal',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
  );

  final bridge = DownstreamBridge(portal.datastore.eventStore);

  final mobile = await _bootstrapPane(
    dbPath: mobileDbPath,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'demo-device',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
    bridge: bridge,
  );

  final entryTypeLookup = _RegistryLookup(mobile.datastore.entryTypes);

  runApp(
    DualDemoApp(
      top: DemoPaneConfig(
        datastore: mobile.datastore,
        backend: mobile.backend,
        appState: mobile.appState,
        entryTypeLookup: entryTypeLookup,
        dbPath: mobile.dbPath,
        tickController: mobile.tick,
        policyNotifier: mobile.policyNotifier,
        paneLabel: 'MOBILE',
      ),
      bottom: DemoPaneConfig(
        datastore: portal.datastore,
        backend: portal.backend,
        appState: portal.appState,
        entryTypeLookup: entryTypeLookup,
        dbPath: portal.dbPath,
        tickController: portal.tick,
        policyNotifier: portal.policyNotifier,
        paneLabel: 'PORTAL',
      ),
    ),
  );
}

class _RegistryLookup implements EntryTypeDefinitionLookup {
  const _RegistryLookup(this.registry);
  final EntryTypeRegistry registry;
  @override
  EntryTypeDefinition? lookup(String entryTypeId) => registry.byId(entryTypeId);
}
