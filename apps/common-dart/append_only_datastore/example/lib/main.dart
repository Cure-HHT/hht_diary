import 'dart:async';
import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/app.dart';
import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/demo_destination.dart';
import 'package:append_only_datastore_demo/demo_sync_policy.dart';
import 'package:append_only_datastore_demo/demo_types.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

// Implements: REQ-d00134 — single init point: registers entry types,
// destinations, materializer. Implements: REQ-d00125 — 1-second tick
// drives fillBatch + drain per destination with live policy from
// demoPolicyNotifier. Using drain() directly instead of SyncCycle.call
// because SyncCycle captures policy at construction time (Phase 4
// wiring); the demo needs per-tick policy hot-swap via sliders.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSupportDir = await getApplicationSupportDirectory();
  final demoDir = Directory(
    p.join(appSupportDir.path, 'append_only_datastore_demo'),
  );
  await demoDir.create(recursive: true);
  final dbPath = p.join(demoDir.path, 'demo.db');
  stdout.writeln('[demo] storage: $dbPath');

  final db = await databaseFactoryIo.openDatabase(dbPath);
  final backend = SembastBackend(database: db);

  const source = Source(
    hopId: 'mobile-device',
    identifier: 'demo-device',
    softwareVersion: 'append_only_datastore_demo@0.1.0+1',
  );

  final primary = DemoDestination(id: 'Primary');
  final secondary = DemoDestination(id: 'Secondary', allowHardDelete: true);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary],
    materializers: const <Materializer>[DiaryEntriesMaterializer()],
  );

  // Start both destinations at now so any new event flows immediately.
  // JNY-07 exercises past-startDate historical replay on a separately
  // added destination (Task 13's add-destination dialog).
  final now = DateTime.now().toUtc();
  await datastore.destinations.setStartDate('Primary', now);
  await datastore.destinations.setStartDate('Secondary', now);

  final appState = AppState(
    registry: datastore.destinations,
    policyNotifier: demoPolicyNotifier,
  );

  final tick = Timer.periodic(const Duration(seconds: 1), (_) async {
    try {
      for (final dest in datastore.destinations.all()) {
        final schedule = await datastore.destinations.scheduleOf(dest.id);
        await fillBatch(dest, backend: backend, schedule: schedule);
      }
      for (final dest in datastore.destinations.all()) {
        await drain(dest, backend: backend, policy: demoPolicyNotifier.value);
      }
    } catch (e, s) {
      stderr.writeln('[demo] sync tick error: $e\n$s');
    }
  });

  runApp(
    DemoApp(
      datastore: datastore,
      backend: backend,
      appState: appState,
      dbPath: dbPath,
      tickController: tick,
    ),
  );
}
