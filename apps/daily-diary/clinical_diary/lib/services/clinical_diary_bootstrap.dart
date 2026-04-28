// Implements: REQ-d00134-A — single bootstrap entry point composing
//   SembastBackend, bootstrapAppendOnlyDatastore, EntryService, SyncCycle,
//   DiaryEntryReader, and triggers. Inbound poll runs after each tick.

import 'dart:async';

import 'package:clinical_diary/destinations/portal_inbound_poll.dart';
import 'package:clinical_diary/destinations/primary_diary_server_destination.dart';
import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:clinical_diary/services/diary_entry_reader.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart'; // includes visibleForTesting
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

/// The collaborators downstream code needs from the bootstrap.
class ClinicalDiaryRuntime {
  ClinicalDiaryRuntime({
    required this.backend,
    required this.entryService,
    required this.eventStore,
    required this.reader,
    required this.syncCycle,
    required this.triggerHandles,
    required this.destinations,
    required Database database,
  }) : _database = database;

  /// The Sembast-backed storage backend. Exposed so callers (e.g. the home
  /// screen wedge banner) can call [SembastBackend.anyFifoWedged] without
  /// re-wrapping the database.
  final SembastBackend backend;
  final EntryService entryService;

  /// The append-only datastore's [EventStore]. Exposed so callers (e.g.
  /// the import-data flow) can ingest StoredEvents directly via
  /// [EventStore.ingestEvent].
  final EventStore eventStore;
  final DiaryEntryReader reader;
  final SyncCycle syncCycle;
  final TriggerHandles triggerHandles;

  /// The destination registry. Exposed so callers can activate destinations
  /// (via [DestinationRegistry.setStartDate]) and inspect their schedules.
  final DestinationRegistry destinations;

  final Database _database;
  bool _disposed = false;

  /// Cancels all installed triggers and closes the underlying Sembast
  /// database. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await triggerHandles.dispose();
    await _database.close();
  }
}

/// Wire up the full clinical-diary runtime from a caller-opened Sembast
/// [Database].
///
/// The caller opens the database (this function does not choose between
/// in-memory and file-backed storage so tests can inject a `sembast_memory`
/// database without special-casing here). Ownership of the database
/// thereafter belongs to the returned [ClinicalDiaryRuntime]: its
/// [ClinicalDiaryRuntime.dispose] closes the database. Callers MUST NOT
/// call `database.close()` themselves.
///
/// Optional `@visibleForTesting` parameters let integration tests inject
/// silent/fake trigger factories (lifecycle, timer, connectivity, FCM) so the
/// production Firebase and connectivity stacks are not invoked.
Future<ClinicalDiaryRuntime> bootstrapClinicalDiary({
  required Database sembastDatabase,
  required Future<String?> Function() authToken,
  required Future<Uri?> Function() resolveBaseUrl,
  required String deviceId,
  required String softwareVersion,
  required String userId,
  http.Client? httpClient,
  // --- test seams for trigger factories (use production defaults when omitted) ---
  // These use the concrete function-type signatures (not the @visibleForTesting
  // typedefs from triggers.dart) so this production file avoids @visibleForTesting
  // scope warnings while still being structurally compatible with them.
  @visibleForTesting
  WidgetsBindingObserver Function(
    VoidCallback onResumed,
    ValueChanged<bool> onForegroundChange,
  )?
  lifecycleObserverFactory,
  @visibleForTesting
  Timer Function(Duration interval, VoidCallback onTick)? periodicTimerFactory,
  @visibleForTesting
  Stream<List<ConnectivityResult>> Function()? connectivityStreamFactory,
  @visibleForTesting
  Stream<RemoteMessage> Function()? fcmOnMessageStreamFactory,
  @visibleForTesting Stream<RemoteMessage> Function()? fcmOnOpenedStreamFactory,
}) async {
  final client = httpClient ?? http.Client();

  // 1. Storage backend — caller opened the database; we wrap it.
  final backend = SembastBackend(database: sembastDatabase);

  // 2. Load the clinical-diary entry type set (nosebleed types + surveys).
  final entryTypes = await loadClinicalDiaryEntryTypes();

  // 3. Primary outbound destination. URL is resolved lazily so that events
  //    recorded before enrollment stay queued in the FIFO and ship once the
  //    base URL becomes available.
  final primaryDestination = PrimaryDiaryServerDestination(
    client: client,
    resolveBaseUrl: resolveBaseUrl,
    authToken: authToken,
  );

  // 4. Bootstrap the append-only datastore (registers entry types, wires
  //    destination registry, emits registry-initialized audit event).
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: 'mobile-device',
      identifier: deviceId,
      softwareVersion: softwareVersion,
    ),
    entryTypes: entryTypes,
    destinations: [primaryDestination],
    materializers: const [DiaryEntriesMaterializer(promoter: identityPromoter)],
    initialViewTargetVersions: {
      'diary_entries': {for (final t in entryTypes) t.id: t.registeredVersion},
    },
  );

  // 5. EntryService — forward-declare the SyncCycle so the closure can
  //    capture the late variable; syncCycle is assigned in step 6.
  late SyncCycle syncCycle;
  Future<void> syncCycleTrigger() async => syncCycle();

  final entryService = EntryService(
    backend: backend,
    entryTypes: datastore.entryTypes,
    syncCycleTrigger: syncCycleTrigger,
    deviceInfo: DeviceInfo(
      deviceId: deviceId,
      softwareVersion: softwareVersion,
      userId: userId,
    ),
  );

  // 6. SyncCycle — assigned after EntryService so the forward declaration
  //    is valid before any trigger fires.
  syncCycle = SyncCycle(backend: backend, registry: datastore.destinations);

  // 7. DiaryEntryReader — pure read facade over the materialized view.
  final reader = DiaryEntryReader(backend: backend);

  // 8. Install triggers. Each tick: drain FIFO → inbound poll.
  final triggerHandles = await installTriggers(
    onTrigger: () async {
      await syncCycle();
      await portalInboundPoll(
        entryService: entryService,
        client: client,
        resolveBaseUrl: resolveBaseUrl,
        authToken: authToken,
      );
    },
    lifecycleObserverFactory: lifecycleObserverFactory,
    periodicTimerFactory: periodicTimerFactory,
    connectivityStreamFactory: connectivityStreamFactory,
    fcmOnMessageStreamFactory: fcmOnMessageStreamFactory,
    fcmOnOpenedStreamFactory: fcmOnOpenedStreamFactory,
  );

  // 9. Return the composed runtime.
  return ClinicalDiaryRuntime(
    backend: backend,
    entryService: entryService,
    eventStore: datastore.eventStore,
    reader: reader,
    syncCycle: syncCycle,
    triggerHandles: triggerHandles,
    destinations: datastore.destinations,
    database: sembastDatabase,
  );
}
