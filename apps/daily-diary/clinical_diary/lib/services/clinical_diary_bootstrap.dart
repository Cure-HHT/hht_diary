// Implements: REQ-d00134-A — single bootstrap entry point composing
//   SembastBackend, bootstrapAppendOnlyDatastore, EntryService, SyncCycle,
//   DiaryEntryReader, and triggers. Inbound poll runs after each tick.

import 'dart:async';

import 'package:clinical_diary/destinations/legacy_questionnaire_submit_destination.dart';
import 'package:clinical_diary/destinations/legacy_sync_destination.dart';
import 'package:clinical_diary/destinations/portal_inbound_poll.dart';
import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:clinical_diary/services/diary_entry_reader.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart'; // includes visibleForTesting
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart' show databaseFactoryIo;
import 'package:sembast_web/sembast_web.dart' show databaseFactoryWeb;

/// The collaborators downstream code needs from the bootstrap.
class ClinicalDiaryRuntime {
  ClinicalDiaryRuntime({
    required this.backend,
    required this.entryService,
    required this.eventStore,
    required this.reader,
    required this.syncCycle,
    required this.fullSync,
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

  /// CUR-1292: Run the same sequence as the periodic trigger —
  /// outbound drain ([SyncCycle]) then [portalInboundPoll]. Used by the
  /// home-screen "tap title to refresh" affordance and the DebugBridge
  /// `/debug/sync` endpoint so a tester can pull tombstones / start_trial
  /// signals on demand without waiting for the next periodic tick.
  /// Honors the same disconnected-predicate as the trigger callback.
  final Future<void> Function() fullSync;

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

  /// Close the database and delete its backing file (native) or IndexedDB
  /// object store (web). After this returns the runtime is unusable and
  /// must not be re-used; the next cold start re-bootstraps from empty
  /// storage. Idempotent — safe to call after [dispose] or after a prior
  /// [deleteDatabaseFiles].
  ///
  /// `databaseFactoryForTest` is for unit-tests that inject a
  /// `databaseFactoryMemory` factory; production calls leave it null and
  /// the platform default (`sembast_web` on web, `sembast_io` elsewhere)
  /// is used.
  ///
  /// REQ-d00004 (local-first persistence): wipes the only physical store
  /// REQ-d00013 (UUID on fresh installation): next cold start mints a new UUID
  /// because the surrounding ResetDataService also clears flutter_secure_storage.
  Future<void> deleteDatabaseFiles({
    @visibleForTesting DatabaseFactory? databaseFactoryForTest,
  }) async {
    final dbPath = _database.path;
    await dispose();
    final factory =
        databaseFactoryForTest ??
        (kIsWeb ? databaseFactoryWeb : databaseFactoryIo);
    try {
      await factory.deleteDatabase(dbPath);
    } catch (e, st) {
      // deleteDatabase throws if the file is already gone — that is the
      // idempotent success case. Log unexpected errors (disk full,
      // permissions, IndexedDB blocked-deletion) so they are visible in
      // debug/profile builds without blocking the reset flow.
      debugPrint(
        '[ClinicalDiaryRuntime] deleteDatabase($dbPath) ignored: $e\n$st',
      );
    }
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
  // CUR-1164 (REQ-p01065-D): When supplied and returns true, the trigger
  // skips outbound sync and inbound poll for that tick. Caller closes over
  // EnrollmentService.disconnectedNotifier so the predicate is sync and
  // O(1). Bootstrap stays neutral — no EnrollmentService dependency.
  bool Function()? isDisconnected,
  // CUR-1292: invoked by [portalInboundPoll] for each survey-aggregate
  // tombstone the device applies. Caller (main.dart) wires this to
  // [TaskService.notifyQuestionnaireCancelled] so the patient sees a
  // passive notification.
  void Function(String aggregateId, String entryType)? onSurveyTombstoned,
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
  // CUR-1311: injectable for unit tests that don't initialize Firebase. When
  // null, the production probe (which calls FirebaseMessaging.instance) is
  // used.
  @visibleForTesting NotificationAuthProbe? notificationAuthProbe,
  // CUR-1311 P1B.5: Hook notification poll into the trigger chain.
  // Called at the end of fullSync() after portalInboundPoll completes.
  Future<void> Function()? onAfterSync,
  // CUR-1398: Hook TaskService.syncTasks into the trigger chain so each
  // periodic / resume / connectivity / FCM tick re-pulls /tasks. Without
  // this, FCM is the only way a foreground patient discovers a newly
  // sent questionnaire — and FCM delivery is best-effort. Optional so
  // existing tests (which don't construct a TaskService) keep working.
  Future<void> Function()? tasksSync,
}) async {
  final client = httpClient ?? http.Client();

  // 1. Storage backend — caller opened the database; we wrap it.
  final backend = SembastBackend(database: sembastDatabase);

  // 2. Load the clinical-diary entry type set (nosebleed types + surveys).
  final entryTypes = await loadClinicalDiaryEntryTypes();

  // 3. Outbound destinations — two transitional shims that translate
  //    canonical event_sourcing_datastore events to the legacy diary
  //    server's existing endpoints. Replaced wholesale by a native
  //    destination once the server cuts over to consume the canonical
  //    `esd/batch@1` wire format.
  //
  //    Entry-type partitioning is by `widgetId` because that field is
  //    the stable contract between an entry type and its UX renderer:
  //    nosebleed-shaped events all render through `epistaxis_form_v1`,
  //    questionnaire-shaped events all render through `survey_renderer_v1`.
  //    URLs are resolved lazily so events recorded before enrollment
  //    stay queued in the FIFO and ship once the base URL becomes
  //    available.
  final nosebleedTypeIds = entryTypes
      .where((t) => t.widgetId == 'epistaxis_form_v1')
      .map((t) => t.id)
      .toList(growable: false);
  final surveyTypeIds = entryTypes
      .where((t) => t.widgetId == 'survey_renderer_v1')
      .map((t) => t.id)
      .toList(growable: false);

  final legacySync = LegacySyncDestination(
    client: client,
    resolveBaseUrl: resolveBaseUrl,
    authToken: authToken,
    entryTypeIds: nosebleedTypeIds,
  );
  final legacyQuestionnaireSubmit = LegacyQuestionnaireSubmitDestination(
    client: client,
    resolveBaseUrl: resolveBaseUrl,
    authToken: authToken,
    entryTypeIds: surveyTypeIds,
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
    destinations: [legacySync, legacyQuestionnaireSubmit],
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
  //    is valid before any trigger fires. The same Source identity that
  //    bootstrapAppendOnlyDatastore stamps on appended events flows
  //    through to fillBatch so any future native destination can mint
  //    its batch envelope from the same identity.
  syncCycle = SyncCycle(
    backend: backend,
    registry: datastore.destinations,
    source: Source(
      hopId: 'mobile-device',
      identifier: deviceId,
      softwareVersion: softwareVersion,
    ),
  );

  // 7. DiaryEntryReader — pure read facade over the materialized view.
  final reader = DiaryEntryReader(backend: backend);

  // 8. Install triggers. Each tick: drain FIFO → inbound poll.
  //    Skip both when the caller's predicate reports disconnected (CUR-1164).
  //
  // CUR-1311: re-probe FCM authorization status at the start of every tick.
  // FCM permission is the only real-time wake-up source (triggers D + E); if
  // the user has denied notifications the periodic timer becomes the only
  // path that surfaces server-side state, so we shorten its cadence from the
  // default 15 min down to 2 min. The probe is reused by installTriggers'
  // periodicInterval callback below.
  final fcmAuthProbe =
      notificationAuthProbe ?? NotificationAuthProbe.firebase();
  await fcmAuthProbe.refresh();

  Future<void> fullSync() async {
    if (isDisconnected != null && isDisconnected()) return;
    await fcmAuthProbe.refresh();
    await syncCycle();
    await portalInboundPoll(
      entryService: entryService,
      eventStore: datastore.eventStore,
      client: client,
      resolveBaseUrl: resolveBaseUrl,
      authToken: authToken,
      onSurveyTombstoned: onSurveyTombstoned,
    );
    // CUR-1398: backstop FCM unreliability — re-pull /tasks on every
    // periodic / resume / connectivity / FCM-triggered tick so a missed
    // notification doesn't leave the home screen stale.
    await tasksSync?.call();
    await onAfterSync?.call();
  }

  final triggerHandles = await installTriggers(
    onTrigger: fullSync,
    periodicInterval: () => fcmAuthProbe.isDenied
        ? const Duration(minutes: 2)
        : const Duration(minutes: 15),
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
    fullSync: fullSync,
    triggerHandles: triggerHandles,
    destinations: datastore.destinations,
    database: sembastDatabase,
  );
}

/// CUR-1311: caches the latest FCM authorization status so the trigger
/// installer can ask synchronously whether to use the short or long poll
/// cadence. Refreshed at bootstrap and at the start of every `fullSync` —
/// the OS gives no native change-callback for permission revocation, so the
/// fast path is "user opens the app or the network comes back".
///
/// Treats `denied` as denied and everything else (`authorized`,
/// `provisional`, `notDetermined`) as authorized: pre-prompt users see the
/// default cadence so we don't churn them with extra polls before they've
/// answered the OS prompt, and provisional (iOS quiet delivery) still gets
/// silent push so it doesn't need the fallback.
class NotificationAuthProbe {
  NotificationAuthProbe._({required this.getSettings});

  /// Production probe — reads `FirebaseMessaging.instance.getNotificationSettings()`.
  factory NotificationAuthProbe.firebase() => NotificationAuthProbe._(
    getSettings: () => FirebaseMessaging.instance.getNotificationSettings(),
  );

  /// Test seam — caller provides the settings future.
  @visibleForTesting
  factory NotificationAuthProbe.forTest(
    Future<NotificationSettings> Function() getSettings,
  ) => NotificationAuthProbe._(getSettings: getSettings);

  final Future<NotificationSettings> Function() getSettings;

  // Starts at `notDetermined` (treated as not-denied below) so a first-launch
  // user does not get the shortened 2-min cadence in the brief window between
  // app start and the first `refresh()`. Bootstrap awaits refresh() before
  // installTriggers, so production reads always see a real OS-reported value.
  AuthorizationStatus _last = AuthorizationStatus.notDetermined;

  /// Re-reads the OS permission. Swallows errors (treating "unknown" as
  /// "not-denied") so a Firebase initialization gap never breaks the
  /// sync loop.
  Future<void> refresh() async {
    try {
      final settings = await getSettings();
      _last = settings.authorizationStatus;
    } catch (_) {
      // Leave _last unchanged; preserves last-known state if any.
    }
  }

  bool get isDenied => _last == AuthorizationStatus.denied;
}
