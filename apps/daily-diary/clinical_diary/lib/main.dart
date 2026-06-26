// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00006: Mobile App Build and Release Process
//   REQ-p00008: Single App Architecture
//   REQ-CAL-p00081: Participant Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform, pid;

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/config_defaults.dart';
import 'package:clinical_diary/config/env_profile.dart';
import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/destinations/system_events_destination.dart';
import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:clinical_diary/notifications/local_notification_scheduler.dart';
import 'package:clinical_diary/notifications/ongoing_epistaxis_reminder_service.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_service.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/scope/diary_sync_triggers.dart';
import 'package:clinical_diary/scope/outbound_watermark.dart';
import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/branding_asset_cache.dart';
import 'package:clinical_diary/services/debug_bridge.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/link_sponsor_settings.dart';
import 'package:clinical_diary/services/local_data_reset.dart';
import 'package:clinical_diary/services/notification_service.dart';
import 'package:clinical_diary/services/push_receiver.dart';
import 'package:clinical_diary/services/questionnaire_status_sync.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/settings/local_reset_policy.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
// Prefixed for readability at the call sites that mint event drafts / set
// destination watermarks; the diary scope's DestinationRegistry.setStartDate
// takes the event_sourcing Initiator.
import 'package:event_sourcing/event_sourcing.dart'
    as esd
    show AutomationInitiator, ActionSubmission;
import 'package:event_sourcing/event_sourcing.dart' show SembastBackend;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// SharedPreferences key for the persisted device install UUID.
const _kDeviceIdPrefsKey = 'clinical_diary.device_id';

/// Foreground sync-poll interval in seconds. Default 60s; overridable via
/// `--dart-define=DIARY_SYNC_PERIODIC_SECONDS=<n>`. The push-transport e2e sets
/// a large value so the periodic /state poll cannot fire during the test —
/// a prompt UI update after a portal action then proves it was push-delivered,
/// not poll-delivered. Implements: DIARY-DEV-pluggable-push-transport/D
const int _kSyncPeriodicSeconds = int.fromEnvironment(
  'DIARY_SYNC_PERIODIC_SECONDS',
  defaultValue: 60,
);

// When true (set via --dart-define in integration_test builds), skip the
// firebase_messaging init in _initializeNotifications so the widget tree can
// reach quiescence for pumpAndSettle. Defaults to false, so production
// behavior is unchanged. Mirrors _kDisableLiveStreams in diary_sync_triggers.
const bool _kDisableLiveStreams = bool.fromEnvironment(
  'DIARY_DISABLE_LIVE_STREAMS',
);

void main() async {
  // Security (CUR-1169): silence debugPrint in release builds. Flutter's
  // debugPrint is NOT stripped from release; it forwards to the platform log
  // stream (logcat/oslog), where any logged response body or identifier becomes
  // readable by privileged processes / log collectors. Production observability
  // is server-side (OTel), not device logs, so drop all debug output in release.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  // Catch all errors in the Flutter framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('Stack trace:\n${details.stack}');
  };

  // Catch all errors outside of Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint('Stack trace:\n$stack');
    return true;
  };

  // Run the app in a zone to catch async errors
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Implements: DIARY-DEV-runtime-environment-resolution/A+B
      // Resolve the environment once from the bundled assets/config/env.json
      // pointer (stamped per-env at packaging time). Must run after binding
      // init — EnvProfile.load() reads rootBundle.
      EnvProfile.current = await EnvProfile.load();
      debugPrint('Running with environment: ${EnvProfile.current.name}');

      // Initialize IANA timezone database for DST-aware time calculations
      TimezoneConverter.ensureInitialized();

      try {
        if (kIsWeb) {
          // Web has no native google-services config, so it needs explicit options.
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          // CUR-1436 / CUR-1399: native platforms initialize from the per-flavor
          // google-services.json / GoogleService-Info.plist, which target the
          // cure-hht-admin project the portal sends FCM from. Passing explicit
          // options here would override that native config and initialize against
          // firebase_options.dart's hht-diary-mvp project, so device tokens would
          // be minted in a different project than the sender and pushes would
          // silently never arrive.
          await Firebase.initializeApp();
        }
        debugPrint('Firebase initialized successfully');
      } on FirebaseException catch (e) {
        // CUR-1278: on Android the google-services Gradle plugin's
        // FirebaseInitProvider auto-initializes the [DEFAULT] app before
        // Dart's main() runs (iOS does the same via FirebaseApp.configure()
        // in AppDelegate). The Dart-side Firebase.apps list is NOT eagerly
        // synced from that native registry, so we can't pre-check
        // Firebase.apps.isEmpty — the init call trips the native
        // "already exists" check and surfaces as `duplicate-app`. Treat that
        // as success (the native app is correct); other codes still surface.
        if (e.code == 'duplicate-app') {
          debugPrint('Firebase already initialized by native side');
        } else {
          debugPrint('Firebase initialization error: $e');
        }
      } catch (e, stack) {
        debugPrint('Firebase initialization error: $e');
        debugPrint('Stack trace:\n$stack');
      }

      // Implements: DIARY-DEV-deployment-config-defaults/B — resolve the bundled
      //   per-distribution UI-config defaults once (sibling to env.json). Sponsor
      //   values delivered at link override these; absent asset -> code defaults.
      AppConfig.deploymentUiDefaults = await loadDeploymentUiDefaults();

      // CUR-1307: Force-enable the semantics tree on web so the Flutter
      // accessibility nodes (and their `flt-semantics-identifier`
      // attributes) are emitted into the DOM for Playwright automation.
      if (kIsWeb) SemanticsBinding.instance.ensureSemantics();

      runApp(const ClinicalDiaryApp());
    },
    (error, stack) {
      debugPrint('Uncaught error in zone: $error');
      debugPrint('Stack trace:\n$stack');
    },
  );
}

class ClinicalDiaryApp extends StatefulWidget {
  const ClinicalDiaryApp({super.key});

  @override
  State<ClinicalDiaryApp> createState() => _ClinicalDiaryAppState();
}

class _ClinicalDiaryAppState extends State<ClinicalDiaryApp> {
  @override
  Widget build(BuildContext context) {
    // Wrap with EnvironmentBanner to show DEV/QA ribbon in non-production
    // builds. The themed [MaterialApp] is built inside [AppRoot] once the
    // event-sourcing scope is up, so its theme/locale/text-scale can be driven
    // by the settings projection.
    return EnvironmentBanner(
      show: EnvProfile.current.showBanner,
      flavorName: EnvProfile.current.name,
      child: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final EnrollmentService _enrollmentService = EnrollmentService();
  final TaskService _taskService = TaskService();

  /// The reactive composition root: the native `event_sourcing` diary scope
  /// (`diary_es.db`). Mounted into the tree via [ReActionScope] so reaction
  /// widgets can resolve a `LocalScope`, and the sole outbound sync runtime.
  DiaryScopeRuntime? _diaryScope;

  /// CUR-1169 I2a: foreground drain triggers (app-resume / connectivity /
  /// periodic) for the new-stack native outbound sync. The post-action-submit
  /// drain is wired through the bootstrap's `syncCycleTrigger`; these cover the
  /// remaining trigger sources. Disposed with the runtime.
  DiarySyncTriggerHandles? _diarySyncTriggers;
  // Local-stack push transport (AppEnv.local only). The receiver rides the
  // portal /api/v1/user/push WS and forwards frames into [_localPushController],
  // which the diary_sync_triggers FCM stream-factory seam reads — so the receipt
  // path is identical to FCM. See lib/services/push_receiver.dart.
  // Implements: DIARY-DEV-pluggable-push-transport/D
  StreamController<RemoteMessage>? _localPushController;
  LocalSocketPushReceiver? _localPushReceiver;

  /// HTTP client owned by the native outbound [DiaryServerDestination]. Closed
  /// on [dispose] so the destination's transport is torn down cleanly.
  http.Client? _diaryIngestClient;

  /// Content-addressed cache for *Sponsor* branding asset bytes, rooted at a
  /// stable on-device support dir (`<appSupport>/branding_cache/`). It lives
  /// OUTSIDE the documents dir the local-data-reset wipes and is never on that
  /// wipe's delete list, so cached branding assets are retained after
  /// participation ends (and across a factory reset), per the asset REQ.
  /// Null on web (path_provider has no web impl) — the logo then falls back to
  /// the app default brand.
  // Implements: DIARY-DEV-sponsor-branding-assets/D
  BrandingAssetCache? _brandingAssetCache;

  /// The participant identity most recently adopted as the diaryScope recording
  /// credential, so synced day-markers are keyed by `participantId`. Null until
  /// the participant links. Tracked here (not read back off the principal) to
  /// avoid redundant `setCredential` calls on every reconcile tick.
  String? _adoptedSyncIdentity;

  /// Native outbound FIFO wedge check (the new `diary_es.db` store), forwarded
  /// to [HomeScreen] so its banner reflects a stuck native sync the legacy
  /// `runtime.backend` cannot see. DIARY-DEV-native-outbound-sync/B.
  Future<bool> Function()? _nativeFifoWedged;

  /// Builds the on-demand [HealthProbeContext] for Service Mode, capturing the
  /// new-stack backend + destination registry + enrollment/clock/version. Set
  /// only when the event-sourcing scope booted (same gate as
  /// [_nativeFifoWedged]); null leaves the Service Mode easter egg inert.
  Future<HealthProbeContext> Function()? _serviceModeContextBuilder;

  /// Persistent device install UUID, minted on first launch and reused
  /// thereafter. Forwarded to [HomeScreen] for the export payload.
  String? _deviceId;
  MobileNotificationService? _notificationService;
  Object? _bootstrapError;
  DebugBridge? _debugBridge;

  /// Schedules the Ongoing Epistaxis (nosebleed) Reminder notifications off the
  /// device-local `diary_incomplete` projection. Null on web/local-stack, where
  /// it is backed by a no-op scheduler. Disposed with the runtime.
  // Implements: DIARY-PRD-notification-ongoing-epistaxis/A
  OngoingEpistaxisReminderService? _epistaxisReminderService;

  /// Schedules the daily Yesterday Entry Reminder. Re-evaluated from the sync
  /// triggers and fed the resolved config from the settings projection.
  // Implements: DIARY-PRD-notification-yesterday-entry/A
  YesterdayReminderService? _yesterdayReminderService;

  @override
  void initState() {
    super.initState();
    _initializeRuntime();
    _initializeNotifications();
  }

  /// Bootstrap the event-sourcing runtime: open Sembast DB, mint or read the
  /// device ID, and compose the native [DiaryScopeRuntime].
  Future<void> _initializeRuntime() async {
    try {
      // Content-addressed sponsor-branding cache. path_provider has no web
      // implementation, so the file-backed cache is native-only; web uses an
      // in-process (per-session) cache.
      if (kIsWeb) {
        // Web has no filesystem: back the branding cache with an in-process
        // (per-session) map so the sponsor logo still fetches-once + verifies +
        // renders in the browser. Implements: DIARY-DEV-sponsor-branding-assets/A+B+C
        _brandingAssetCache = BrandingAssetCache.inMemory();
      } else {
        // Root the branding cache under the support dir (a stable on-device
        // location SEPARATE from the documents dir the local-data-reset wipes),
        // so cached branding assets are retained for posterity after
        // participation ends. Implements: DIARY-DEV-sponsor-branding-assets/D
        final supportDir = await getApplicationSupportDirectory();
        _brandingAssetCache = BrandingAssetCache(
          cacheDir: Directory('${supportDir.path}/branding_cache'),
        );
      }

      final deviceId = await _readOrMintDeviceId();

      String softwareVersion;
      try {
        final pkg = await PackageInfo.fromPlatform();
        softwareVersion = pkg.buildNumber.isNotEmpty
            ? 'clinical_diary@${pkg.version}+${pkg.buildNumber}'
            : 'clinical_diary@${pkg.version}';
      } catch (_) {
        softwareVersion = 'clinical_diary@0.0.0';
      }

      // Build the native `event_sourcing` reactive composition root. Backed by
      // the `diary_es.db` Sembast store and driving the sole outbound sync
      // (DiaryServerDestination + SystemEventsDestination). Failures route to
      // _bootstrapError via the enclosing try/catch.
      final DiaryScopeRuntime diaryScope;
      Future<bool> Function()? nativeFifoWedged;
      Future<HealthProbeContext> Function()? serviceModeContextBuilder;
      {
        final Database esDb;
        if (kIsWeb) {
          esDb = await databaseFactoryWeb.openDatabase('diary_es.db');
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          esDb = await databaseFactoryIo.openDatabase(
            '${docsDir.path}/diary_es.db',
          );
        }
        // CUR-1169 I2a: the end-state NATIVE outbound destination. Ships the
        // canonical esd/batch@1 BatchEnvelope to the diary-server event-sourcing
        // ingest. The ingest endpoint is the native handler the diary-server
        // rebuild (evs-portal Beta topology) will expose; until then the POST
        // simply retries (SendTransient) — diary entries already do not sync
        // post-cluster and the app is greenfield. Resolve URL + JWT lazily so
        // the destination picks up enrollment the moment the participant links,
        // with no bootstrap-time restart.
        final ingestClient = http.Client();
        _diaryIngestClient = ingestClient;
        // Native ingest endpoint: <backend>/api/v1/ingest/batch. Returns null
        // pre-enrollment, which both destinations treat as "skip this cycle".
        Future<Uri?> resolveIngestUrl() async {
          final base = await _enrollmentService.getBackendUrl();
          if (base == null) return null;
          return Uri.parse('$base/api/v1/ingest/batch');
        }

        final destination = DiaryServerDestination(
          client: ingestClient,
          resolveIngestUrl: resolveIngestUrl,
          authToken: _enrollmentService.getJwtToken,
        );
        // Second outbound queue: ships system/FCM aggregates (FcmToken token
        // registration + InboundMessage receipts) to the SAME ingest endpoint.
        // It is activated at LINK time (not the trial-start watermark) so push
        // routing tokens reach the portal as soon as the device links.
        final systemDestination = SystemEventsDestination(
          client: ingestClient,
          resolveIngestUrl: resolveIngestUrl,
          authToken: _enrollmentService.getJwtToken,
        );

        // The native outbound FIFO lives in this (new) store; capture a wedge
        // check for the home-screen banner — the legacy runtime.backend can't
        // see it. DIARY-DEV-native-outbound-sync/B.
        final esBackend = SembastBackend(database: esDb);
        nativeFifoWedged = esBackend.hasFifoWedged;

        // Register the dynamic `<id>_survey` entry types into the NATIVE scope so
        // a `submit_questionnaire` dispatch finalizes a `<id>_survey` DiaryEntry
        // event that ships through `DiaryServerDestination`. The nosebleed types
        // are registered internally by `bootstrapDiaryScope`; only the dynamic
        // (data-driven) survey types are passed in here.
        // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/N
        final surveyEntryTypes = await loadSurveyEntryTypes();

        try {
          diaryScope = await bootstrapDiaryScope(
            backend: esBackend,
            deviceId: deviceId,
            softwareVersion: softwareVersion,
            localUserId: deviceId, // stable per-install id; recording is never
            // enrollment-gated
            extraEntryTypes: surveyEntryTypes,
            outboundDestinations: [destination, systemDestination],
          );
        } catch (_) {
          ingestClient.close();
          _diaryIngestClient = null;
          await esDb.close();
          rethrow;
        }

        // Build the on-demand Service Mode probe context against the new
        // event-sourcing stack. Captured here where the backend + destination
        // registry are in scope; evaluated only when the User opens Service
        // Mode (zero steady-state cost). Reachable regardless of link/token
        // state — `everLinked`/`linked`/`tokenLive` are reported, not gated on.
        // Implements: DIARY-PRD-device-health-diagnostics/A — on-demand,
        //   no-network/no-sign-in/no-link diagnostic context.
        final probeBackend = esBackend;
        final probeScope = diaryScope;
        serviceModeContextBuilder = () async {
          final pkg = await PackageInfo.fromPlatform();
          final linked = await _enrollmentService.isEnrolled();
          final token = await _enrollmentService.getJwtToken();
          var iana = 'unknown';
          try {
            iana = (await FlutterTimezone.getLocalTimezone()).identifier;
          } on Exception {
            iana = 'unknown';
          }
          final now = DateTime.now();
          return HealthProbeContext(
            backend: probeBackend,
            destinationIds: probeScope.bundle.destinations
                .all()
                .map((d) => d.id)
                .toList(),
            everLinked: linked,
            linked: linked,
            tokenLive: (token ?? '').isNotEmpty,
            clock: ClockInfo(
              deviceNow: now,
              ianaZone: iana,
              utcOffsetMinutes: now.timeZoneOffset.inMinutes,
            ),
            version: VersionInfo(
              appVersion: pkg.version,
              buildNumber: pkg.buildNumber,
              platform: defaultTargetPlatform.name,
              os: kIsWeb ? 'web' : Platform.operatingSystem,
            ),
            deviceId: deviceId,
          );
        };

        // Install the foreground drain triggers (app-resume / connectivity /
        // periodic). The post-action-submit drain is already wired through the
        // bootstrap's syncCycleTrigger; these route into the same SyncCycle.
        //
        // The native destination is NOT activated at install. Each tick first
        // reconciles the scope with portal state (_reconcileDiaryScope): adopt
        // the participant identity for synced aggregates, and activate the
        // destination at the trial-start watermark once the trial has started.
        // Implements: DIARY-DEV-native-outbound-sync/C
        // Seed the disconnected / not-participating notifiers from persisted
        // prefs so the sync gate is correct from the first tick of this session
        // (e.g. a participant marked not-participating in a prior session whose
        // JWT was already forgotten, so the /state poll below cannot re-derive it).
        await _enrollmentService.seedLifecycleNotifiers();

        // On the local-stack, push rides a WS instead of FCM. A stable
        // broadcast controller feeds the diary_sync_triggers FCM stream-factory
        // seam; the LocalSocketPushReceiver (started at the link transition in
        // _reconcileDiaryScope, once a backend URL + JWT exist) forwards frames
        // into it. Created here so the trigger install wiring is fixed even
        // though the receiver connects later.
        // Implements: DIARY-DEV-pluggable-push-transport/D
        final isLocalPush = EnvProfile.current.env == AppEnv.local;
        if (isLocalPush) {
          _localPushController = StreamController<RemoteMessage>.broadcast();
        }

        // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
        // Reconciles portal-reported task statuses against the device-local
        // questionnaire_status view after each task sync, idempotently minting
        // record_questionnaire_finalized for newly-finalized tasks.
        final qStatusSync = QuestionnaireStatusSync(
          scope: diaryScope.scope,
          enableUnlock: false,
        );

        final syncCycle = diaryScope.syncCycle;
        if (syncCycle != null) {
          try {
            _diarySyncTriggers = await installDiarySyncTriggers(
              // Foreground-only poll. Portal-originated lifecycle changes
              // (trial-start, disconnect, not-participating) reach the diary
              // via this /user/state reconcile, kept as the BACKUP path. 60s
              // keeps the foreground experience near-live; push is the PRIMARY
              // trigger (onFcmReceipt below, CUR-1436) — FCM in the cloud, the
              // local-push WS on the local-stack. The interval is overridable
              // via --dart-define=DIARY_SYNC_PERIODIC_SECONDS so the push-
              // transport e2e can stretch the poll and isolate the push path
              // (a prompt UI update under a long poll can only be push-driven).
              periodicInterval: const Duration(seconds: _kSyncPeriodicSeconds),
              onFcmReceipt: _recordFcmReceipt,
              // Local-stack: read pushes from the local-push WS controller
              // instead of FirebaseMessaging. No onOpenedApp (no tray).
              fcmOnMessageStreamFactory: isLocalPush
                  ? () => _localPushController!.stream
                  : null,
              fcmOnOpenedStreamFactory: isLocalPush
                  ? () => const Stream<RemoteMessage>.empty()
                  : null,
              onTrigger: () async {
                await _reconcileDiaryScope(diaryScope);
                // Re-evaluate the daily Yesterday reminder on every trigger
                // (app-resume / periodic / connectivity / push) so a newly
                // recorded day cancels it and a new day re-schedules it.
                // Implements: DIARY-PRD-notification-yesterday-entry/D
                unawaited(_yesterdayReminderService?.reevaluate());
                // Pause outbound sync while the participant is disconnected or
                // not-participating (DIARY-DEV-participant-state-poll/B). The
                // reconcile above refreshed both notifiers from /state.
                if (_enrollmentService.disconnectedNotifier.value ||
                    _enrollmentService.notParticipatingNotifier.value) {
                  return;
                }
                await syncCycle.call();
                // CUR-1398: re-pull /tasks on every periodic / resume /
                // connectivity / FCM-triggered tick so a slow/dropped push
                // doesn't leave the home screen stale. Gated by the same
                // disconnected / not-participating short-circuit above.
                // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
                await _taskService.syncTasks(_enrollmentService);
                try {
                  await qStatusSync.reconcile(_taskService.tasks);
                } catch (e, stack) {
                  debugPrint(
                    '[TaskSync] questionnaire status reconcile failed: $e\n$stack',
                  );
                }
              },
            );
          } catch (e, stack) {
            debugPrint('[Bootstrap] diary sync triggers failed: $e\n$stack');
          }
          // Reconcile once at boot so a link / trial-start that happened while
          // the app was closed is picked up without waiting for a trigger.
          unawaited(_reconcileDiaryScope(diaryScope));
        }
      }

      // Reminder services: observe the device-local diary projections and
      // schedule the Ongoing Epistaxis and daily Yesterday Entry reminders. The
      // native plugin has no web implementation, and the local-stack runs
      // web/Linux without a tray, so both use a no-op scheduler.
      // Implements: DIARY-PRD-notification-ongoing-epistaxis/A
      // Implements: DIARY-PRD-notification-yesterday-entry/A
      try {
        final LocalNotificationScheduler scheduler;
        if (kIsWeb || EnvProfile.current.env == AppEnv.local) {
          scheduler = const NoOpLocalNotificationScheduler();
        } else {
          final flutterScheduler = FlutterLocalNotificationScheduler();
          // A tapped reminder opens the app; routing is by payload. The home
          // screen already surfaces the Yesterday banner, so a tap needs no
          // extra navigation today — kept as a seam for future deep-linking.
          await flutterScheduler.initialize(onTap: _onReminderTapped);
          scheduler = flutterScheduler;
        }
        final reminderService = OngoingEpistaxisReminderService(
          viewSource: diaryScope.scope.viewSource,
          scheduler: scheduler,
        );
        await reminderService.start();
        _epistaxisReminderService = reminderService;

        _yesterdayReminderService = YesterdayReminderService(
          viewSource: diaryScope.scope.viewSource,
          scheduler: scheduler,
        );
        // Re-evaluate once at boot so a missed day surfaces without waiting for
        // a trigger; config arrives via the settings ViewBuilder in build().
        unawaited(_yesterdayReminderService!.reevaluate());
      } catch (e, stack) {
        debugPrint('[Bootstrap] reminder services failed: $e\n$stack');
      }

      if (mounted) {
        setState(() {
          _deviceId = deviceId;
          _diaryScope = diaryScope;
          _nativeFifoWedged = nativeFifoWedged;
          _serviceModeContextBuilder = serviceModeContextBuilder;
        });
      }

      // Start the local-only HTTP debug bridge. Loopback-bound and gated
      // on AppEnv.local + !kIsWeb (shelf needs dart:io). Failure to bind
      // is logged and swallowed so a port collision does not block app
      // bring-up.
      if (EnvProfile.current.env == AppEnv.local && !kIsWeb) {
        try {
          final bridge = DebugBridge(
            scope: diaryScope,
            // Closure over _taskService + _enrollmentService so the
            // bridge can fire a /tasks poll without holding the
            // services as fields.
            onTaskSync: () => _taskService.syncTasks(_enrollmentService),
          );
          await bridge.start();
          _debugBridge = bridge;
        } catch (e, stack) {
          debugPrint('[DebugBridge] start failed: $e\n$stack');
        }
        _emitShutdownHelp();
      }
    } catch (e, stack) {
      debugPrint('[Bootstrap] Runtime init failed: $e\n$stack');
      if (mounted) {
        setState(() => _bootstrapError = e);
      }
    }
  }

  /// Reconcile the diary scope with portal state on each sync tick (and once at
  /// boot). Two effects, both safe to repeat:
  ///
  ///  1. Adopt the participant identity for synced aggregates. Day-markers are
  ///     keyed by the recording principal's userId (`dayAggregateId`), and the
  ///     ingest edge requires `participantId` as the cross-wire key
  ///     (DIARY-DEV-participant-ingest/D). Once linked, switch the diaryScope
  ///     credential from the device-local id to the participantId so day-markers
  ///     recorded from then on are participant-keyed. Pre-link entries keep the
  ///     local id and stay local (the watermark below never ships them).
  ///  2. Gate the native destination on the trial-start watermark
  ///     (DIARY-DEV-native-outbound-sync/C). The destination stays inactive
  ///     until the portal reports Trial Start; then it is activated at
  ///     `trial_started_at` so only at-or-after-Trial-Start entries ship.
  ///     `setStartDate` is monotonically non-increasing, so activating once is
  ///     enough and repeat ticks are no-ops.
  Future<void> _reconcileDiaryScope(DiaryScopeRuntime diaryScope) async {
    try {
      final participantId = await _enrollmentService.getUserId();
      if (participantId != null &&
          participantId.isNotEmpty &&
          participantId != _adoptedSyncIdentity) {
        diaryScope.authSession.setCredential(participantId);
        _adoptedSyncIdentity = participantId;
        // Record the link as a first-class, mobile-authored fact in the diary's
        // own event log (DIARY-DEV-shared-events-catalog/A surface P4). Identity
        // only — the JWT/install-id stay in secure storage (state-in-event-log/B).
        await _recordParticipantLinkedOnce(diaryScope, participantId);
        // Activate the system-events destination at link (monotonic): FCM
        // tokens and receipts must reach the portal as soon as the device is
        // linked, independent of the trial-start watermark that gates clinical
        // diary entries. Epoch start = drain all system events once linked.
        // Implements: DIARY-DEV-native-outbound-sync/C
        final sysSchedule = await diaryScope.bundle.destinations.scheduleOf(
          SystemEventsDestination.destinationId,
        );
        if (sysSchedule.startDate == null) {
          await diaryScope.bundle.destinations.setStartDate(
            SystemEventsDestination.destinationId,
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            initiator: const esd.AutomationInitiator(
              service: 'system-events-link-activation',
            ),
          );
        }
        // Re-register the routing token now that the participant id is known: a
        // token minted pre-link could not be recorded (no participant-scoped
        // aggregate id yet), so record it once here at the link transition.
        if (EnvProfile.current.env == AppEnv.local) {
          // Local-stack: connect the local-push WS and register the deviceId as
          // the routing token (the receiver also registers it on connect).
          // Implements: DIARY-DEV-pluggable-push-transport/D
          await _startLocalPushReceiver();
        } else {
          final currentToken = _notificationService?.currentToken;
          if (currentToken != null) {
            await _registerFcmToken(currentToken);
          }
        }
        // Apply the portal-requested sponsor settings carried in the /link
        // response (set-once-at-link), through the diary's normal apply path.
        // Implements: DIARY-BASE-sponsor-requested-settings/A+B
        final enrollment = await _enrollmentService.getEnrollment();
        await applyLinkSponsorSettings(
          diaryScope.scope,
          enrollment?.sponsorSettings,
        );
      }
    } catch (e, stack) {
      debugPrint('[Reconcile] identity adoption failed: $e\n$stack');
    }

    try {
      final base = await _enrollmentService.getBackendUrl();
      final token = await _enrollmentService.getJwtToken();
      if (base == null || token == null) return; // not linked yet.

      final res = await (_diaryIngestClient ?? http.Client()).get(
        Uri.parse('$base/api/v1/user/state'),
        headers: <String, String>{'authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, Object?>;

      // Lifecycle propagation (DIARY-DEV-participant-state-poll/B). BOTH the
      // disconnected and not-participating states END the device link: the diary
      // forgets its session credential and stops syncing, so resuming requires
      // re-establishing the link with a NEW linking code — there is no silent
      // resume (DIARY-PRD-participant-reconnection/E,
      // DIARY-PRD-participant-reactivate/D; disconnect also releases the device
      // binding, DIARY-PRD-participant-disconnection/G). The two differ only in
      // UI messaging + Sponsor-rule retention (surfaced from the persisted flag);
      // credential handling is identical. A successful re-link clears both flags
      // (EnrollmentService.enroll) and the buffered disconnected-period entries
      // ship on the next drain (reconnection/F). not-participating supersedes
      // disconnected (latest lifecycle event wins).
      if (body['is_not_participating'] == true) {
        final firstDetectedAt = await _enrollmentService
            .getNotParticipatingAt();
        await _enrollmentService.setNotParticipating(
          true,
          at: firstDetectedAt ?? DateTime.now(),
        );
        await _enrollmentService.setDisconnected(false);
        // Return control to the participant: unlock the sponsor-applied settings
        // (clinical values kept; ui.* allow-sets revert to default). Idempotent —
        // a re-run finds nothing locked once this has applied.
        // Implements: DIARY-BASE-sponsor-requested-settings/E
        await unlockSponsorSettings(diaryScope.scope);
        await _enrollmentService.clearEnrollment(); // forget the JWT
        return;
      }
      if (body['is_disconnected'] == true) {
        await _enrollmentService.setDisconnected(true);
        await _enrollmentService.setNotParticipating(false);
        await _enrollmentService.clearEnrollment(); // forget the JWT
        return;
      }
      await _enrollmentService.setNotParticipating(false);
      await _enrollmentService.setDisconnected(false);

      // Trial-start watermark: activate the native destination once at Trial
      // Start (monotonic; skip the write when already activated).
      final schedule = await diaryScope.bundle.destinations.scheduleOf(
        DiaryServerDestination.destinationId,
      );
      if (schedule.startDate != null) return; // already activated (monotonic).
      final startedAtRaw = body['trial_started_at'];
      if (startedAtRaw is! String) return; // trial not started -> stay local.
      // The portal emits trial_started_at in UTC. Tolerate a missing timezone
      // designator: DateTime.parse() treats a tz-less string as LOCAL, so
      // `.toUtc()` would shift the watermark by the device's offset (in the
      // Americas, hours into the future), silently gating ALL outbound sync.
      // Treat a naive timestamp as UTC. Forward-compatible with a server that
      // already appends 'Z'.
      final hasTz =
          startedAtRaw.endsWith('Z') ||
          RegExp(r'[+-]\d\d:?\d\d$').hasMatch(startedAtRaw);
      final watermark = DateTime.tryParse(
        hasTz ? startedAtRaw : '${startedAtRaw}Z',
      )?.toUtc();
      if (watermark == null) return;

      // Floor the watermark at the device link time so entries recorded BEFORE
      // linking — keyed by the device-local identity, not the participantId —
      // are never enqueued for the portal. Such a `<deviceUuid>:<date>` aggregate
      // id cannot pass the ingest edge's `{participantId}:` ownership check; a
      // permanent 403 would wedge the FIFO and halt all sync. Trial Start can
      // precede the link (the coordinator may Start Trial before the device
      // links), so the trial-start watermark alone is not a safe floor.
      // Implements: DIARY-DEV-native-outbound-sync/C
      final linkedAt = await _participantLinkedAt(diaryScope);
      final effectiveStart = effectiveClinicalStartWatermark(
        trialStartedAt: watermark,
        linkedAt: linkedAt,
      );

      await diaryScope.bundle.destinations.setStartDate(
        DiaryServerDestination.destinationId,
        effectiveStart,
        initiator: const esd.AutomationInitiator(
          service: 'trial-start-watermark',
        ),
      );
    } catch (e, stack) {
      debugPrint(
        '[Reconcile] state poll / watermark gating failed: $e\n$stack',
      );
    }
  }

  /// Record `participant_linked` into the diary's own event log exactly once,
  /// at the link transition. Restart-safe: skips if the `Participant` aggregate
  /// already carries the event. The portal does not receive this today (no
  /// cross-post path; the portal learns "connected" from the /link redemption) —
  /// it is a mobile-authored audit fact (identity only, no token), produced now
  /// and ready for the future edge/core cross-post.
  Future<void> _recordParticipantLinkedOnce(
    DiaryScopeRuntime diaryScope,
    String participantId,
  ) async {
    try {
      final existing = await diaryScope.bundle.eventStore.backend
          .findEventsForAggregate(participantId);
      if (existing.any((e) => e.entryType == 'participant_linked')) return;
      final enrollment = await _enrollmentService.getEnrollment();
      await diaryScope.scope.actionSubmitter.submit(
        esd.ActionSubmission(
          actionName: 'record_participant_linked',
          // snake_case keys per ParticipantLinkedPayload.fromJson. The redeemed
          // linking code rides along for traceability (no longer a secret); the
          // session JWT is NOT carried (it stays in secure storage).
          rawInput: <String, Object?>{
            'user_id': participantId,
            'participant_id': participantId,
            'linked_at': DateTime.now().toUtc().toIso8601String(),
            if (enrollment?.linkingCode != null)
              'linking_code': enrollment!.linkingCode,
          },
        ),
      );
    } catch (e, stack) {
      debugPrint('[Reconcile] record participant_linked failed: $e\n$stack');
    }
  }

  /// The device link time — the `participant_linked` event timestamp (UTC) — or
  /// null if not yet linked / not recorded. Used to floor the outbound watermark
  /// so pre-link entries never ship (see [effectiveClinicalStartWatermark]).
  Future<DateTime?> _participantLinkedAt(DiaryScopeRuntime diaryScope) async {
    final pid = _adoptedSyncIdentity;
    if (pid == null || pid.isEmpty) return null;
    final events = await diaryScope.bundle.eventStore.backend
        .findEventsForAggregate(pid);
    for (final e in events) {
      if (e.entryType == 'participant_linked') {
        return e.clientTimestamp.toUtc();
      }
    }
    return null;
  }

  /// Prints clean-shutdown instructions to stdout on local-flavor desktop boot,
  /// so whoever launched a detached `flutter run` doesn't have to remember how
  /// to stop it cleanly. Clean stops run the app's dispose path (which flushes
  /// the Sembast stores); a `kill -9` does not.
  void _emitShutdownHelp() {
    debugPrint(
      '\n'
      '[diary][local] clean shutdown (runs dispose -> flushes diary_es.db):\n'
      '[diary][local]   - close the app window, OR\n'
      '[diary][local]   - press q if attached, OR `echo q > /tmp/diary.in`\n'
      '[diary][local]     when launched detached via the run FIFO (graceful quit).\n'
      '[diary][local]   force-stop (skips DB flush, last resort): kill $pid\n',
    );
  }

  /// Full local factory reset: tear down the live runtimes (closing both
  /// Sembast stores), wipe all on-device state, then re-bootstrap so the app
  /// comes back up at first-launch state with a freshly-minted device id.
  ///
  /// The hard participation gate lives in [HomeScreen] (a participant must end
  /// participation before this is reachable); this method assumes the gate has
  /// already allowed the reset.
  // Implements: DIARY-BASE-local-data-reset/A
  Future<void> _resetAllData() async {
    // 1. Capture the documents path (mirrors _initializeRuntime). path_provider
    //    has no web implementation, so the file wipe is io-only; on web the
    //    Sembast stores are IndexedDB-backed and there are no files to delete.
    String? documentsPath;
    if (!kIsWeb) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        documentsPath = docsDir.path;
      } catch (e, stack) {
        debugPrint('[Reset] documents-dir lookup failed: $e\n$stack');
      }
    }

    // 2. Dispose the native diary scope (closes the EventStore so the file
    //    unlocks), plus the sync-trigger handles + ingest client — mirrors
    //    dispose(). The scope itself is disposed in step 3's block below.
    try {
      await _diarySyncTriggers?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] sync-trigger dispose failed: $e\n$stack');
    }
    _diarySyncTriggers = null;
    try {
      await _epistaxisReminderService?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] epistaxis reminder dispose failed: $e\n$stack');
    }
    _epistaxisReminderService = null;
    try {
      await _yesterdayReminderService?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] yesterday reminder dispose failed: $e\n$stack');
    }
    _yesterdayReminderService = null;
    _diaryIngestClient?.close();
    _diaryIngestClient = null;
    try {
      await _diaryScope?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] diary scope dispose failed: $e\n$stack');
    }

    // 3. Wipe all local state (store files + enrollment + tasks + prefs).
    if (documentsPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await wipeLocalData(
        documentsPath: documentsPath,
        enrollmentService: _enrollmentService,
        taskService: _taskService,
        prefs: prefs,
      );
    }

    // 4. Show the loading scaffold, then re-bootstrap a fresh runtime. The new
    //    device id (minted by _readOrMintDeviceId against the now-empty prefs)
    //    re-keys HomeScreen, forcing a fresh State against the new runtime.
    if (mounted) {
      setState(() {
        _diaryScope = null;
        _nativeFifoWedged = null;
        _serviceModeContextBuilder = null;
        _deviceId = null;
      });
    }
    await _initializeRuntime();
  }

  Future<String> _readOrMintDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var existing = prefs.getString(_kDeviceIdPrefsKey);
    if (existing == null || existing.isEmpty) {
      existing = const Uuid().v4();
      await prefs.setString(_kDeviceIdPrefsKey, existing);
    }
    return existing;
  }

  /// Initialize FCM notification service for token registration / permissions /
  /// topic subscription. FCM messages drive the diary reconcile via the native
  /// sync triggers (`installDiarySyncTriggers`); any FCM data messages that need
  /// to surface tasks flow through TaskService.handleFcmMessage.
  Future<void> _initializeNotifications() async {
    // Tasks are poll-based and independent of the push transport, so load +
    // sync them regardless of environment (a local web/desktop diary that is
    // already linked must still restore + refresh its task list).
    // Load persisted tasks from storage
    await _taskService.loadTasks();
    // REQ-CAL-p00081: Poll for tasks on app start (FCM fallback)
    unawaited(_taskService.syncTasks(_enrollmentService));

    // CUR-1436/CUR-1447: a `questionnaire_assigned` FCM nudge carries only
    // {type, flowToken} — the authoritative task list comes from
    // `/user/tasks`. Inject the sync trigger so handleFcmMessage (sync) can
    // fire a sync without TaskService holding the EnrollmentService. Mirrors
    // the `tasksSync` / `onTaskSync` closures used elsewhere. Set before the
    // local-stack early-return so WS-delivered nudges trigger a sync too.
    _taskService.onSyncRequested = () =>
        _taskService.syncTasks(_enrollmentService);

    // On the local-stack (AppEnv.local) the diary is web/Linux and has no FCM;
    // push arrives over the LocalSocketPushReceiver WS instead (wired in
    // _initializeRuntime). Skip ONLY the firebase_messaging init.
    // Implements: DIARY-DEV-pluggable-push-transport/D
    final profile = await EnvProfile.load();
    if (profile.env == AppEnv.local || _kDisableLiveStreams) {
      debugPrint(
        '[local] AppEnv.local — skipping FCM init; push rides the '
        'local-push WS',
      );
      return;
    }

    _notificationService = MobileNotificationService(
      onDataMessage: _taskService.handleFcmMessage,
      onTokenRefresh: _registerFcmToken,
    );

    try {
      await _notificationService!.initialize();
      debugPrint('[Main] Notification service initialized');
    } catch (e, stack) {
      debugPrint('[Main] Notification service init failed: $e');
      debugPrint('[Main] Stack:\n$stack');
    }
  }

  /// Platform tag for the `participant_fcm_tokens` row. On the local-stack the
  /// diary is web or a desktop OS (no FCM concept of ios/android); the portal's
  /// LocalSocketPushChannel routes by participantId so the tag is informational.
  String _pushPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem; // linux / macos / windows
  }

  /// Connects the local-stack push receiver (AppEnv.local) and registers this
  /// device's routing id. Idempotent: returns early if already started, or when
  /// the backend URL / participant JWT are not yet available (pre-link).
  /// Implements: DIARY-DEV-pluggable-push-transport/D
  Future<void> _startLocalPushReceiver() async {
    if (_localPushReceiver != null) return;
    final base = await _enrollmentService.getBackendUrl();
    final token = await _enrollmentService.getJwtToken();
    final deviceId = _deviceId;
    if (base == null || token == null || token.isEmpty || deviceId == null) {
      return;
    }
    final wsBase = base.replaceFirst(RegExp('^http'), 'ws');
    final receiver = LocalSocketPushReceiver(
      socket: WebSocketPushSocket.connect(
        Uri.parse('$wsBase/api/v1/user/push'),
      ),
      authToken: _enrollmentService.getJwtToken,
    );
    _localPushReceiver = receiver;
    receiver.messages.listen((m) => _localPushController?.add(m));
    await receiver.start();
    // The deviceId is the local routing token (the WS connection is keyed by
    // participantId; the token value is informational for the projection).
    await _registerFcmToken(deviceId);
    debugPrint('[local] local-push receiver connected to $wsBase');
  }

  /// Record an FCM token mint/refresh as a `fcm_token_registered` event in the
  /// diary's OWN event log, dispatched through the EVS ActionDispatcher.
  ///
  /// Called on initial token retrieval and on token refresh. The token aggregate
  /// id is participant-scoped (`{participantId}:fcm:{platform}`) so the portal
  /// `/ingest` accepts it (ownership is enforced on the `{participantId}:` prefix,
  /// and the JWT userId IS the participantId) and the portal projects one active
  /// token per participant+platform. Until linked there is no participant id, so
  /// the registration is deferred and re-run at the link transition.
  ///
  /// REQ-CAL-p00082: Participant Alert Delivery
  // Implements: DIARY-DEV-inbound-event-on-receipt/A
  Future<void> _registerFcmToken(String token) async {
    final participantId = await _enrollmentService.getUserId();
    if (participantId == null || participantId.isEmpty) {
      debugPrint('[FCM] not linked yet — deferring token registration');
      return;
    }
    final scope = _diaryScope;
    if (scope == null) return;
    final platform = _pushPlatform();
    try {
      await scope.scope.actionSubmitter.submit(
        esd.ActionSubmission(
          actionName: 'register_fcm_token',
          rawInput: <String, Object?>{
            'aggregateId': '$participantId:fcm:$platform',
            'token': token,
            'platform': platform,
            'registered_at': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
      debugPrint('[FCM] token recorded as fcm_token_registered ($platform)');
    } catch (e, st) {
      debugPrint('[FCM] register_fcm_token dispatch failed: $e\n$st');
    }
  }

  /// Record an inbound FCM message as a `fcm_message_received` event in the
  /// diary's OWN event log, echoing the portal-minted `flowToken` (if any) so
  /// the portal can stitch assigned -> delivered -> received. Dispatched
  /// through the EVS action submitter. Best-effort: failures are logged
  /// and swallowed and never block the sync drain.
  ///
  /// The receipt aggregate id is participant-scoped
  /// (`{participantId}:rcv:{uuid}`) so the portal `/ingest` accepts it
  /// (ownership is enforced on the `{participantId}:` prefix). Until linked
  /// there is no participant id, so the receipt is skipped.
  // Implements: DIARY-DEV-inbound-event-on-receipt/B
  // Implements: DIARY-DEV-outgoing-intent-correlation/D — echo the portal-minted flowToken.
  Future<void> _recordFcmReceipt(RemoteMessage message) async {
    final participantId = await _enrollmentService.getUserId();
    if (participantId == null || participantId.isEmpty) return;
    final scope = _diaryScope;
    if (scope == null) return;
    final data = message.data;
    try {
      await scope.scope.actionSubmitter.submit(
        esd.ActionSubmission(
          actionName: 'record_fcm_message_received',
          rawInput: <String, Object?>{
            'aggregateId': '$participantId:rcv:${const Uuid().v4()}',
            'received_at': DateTime.now().toUtc().toIso8601String(),
            'channel': 'fcm',
            'message_type': (data['type'] as String?) ?? 'unknown',
            if (data['flowToken'] is String) 'flowToken': data['flowToken'],
          },
        ),
      );
    } catch (e, st) {
      debugPrint('[FCM] record_fcm_message_received dispatch failed: $e\n$st');
    }
  }

  /// Called after the user successfully links to a study.
  /// Registers the cached FCM token with the diary server now that
  /// the JWT and backend URL are available.
  ///
  /// REQ-CAL-p00082: Participant Alert Delivery
  void _onPostEnrollment() {
    final token = _notificationService?.currentToken;
    if (token != null) {
      _registerFcmToken(token);
    }
    // Reconcile the new-stack scope immediately on link so portal-delivered
    // sponsor settings (incl. branding.* via the /link sponsor_settings batch)
    // are applied to the diary's settings log right now — the reactive app root
    // then renders sponsor branding live, instead of waiting for the next
    // periodic/resume reconcile (or an app relaunch).
    final diaryScope = _diaryScope;
    if (diaryScope != null) {
      unawaited(_reconcileDiaryScope(diaryScope));
    }
    // REQ-CAL-p00081: Discover tasks immediately after linking
    unawaited(_taskService.syncTasks(_enrollmentService));
  }

  /// Called when a local reminder notification is tapped (foreground or launch).
  /// Tapping opens the app; the home screen already surfaces the Yesterday
  /// banner when yesterday is unrecorded, so no extra navigation is needed today.
  /// Kept as a seam for future deep-linking by [payload].
  // Implements: DIARY-PRD-notification-yesterday-entry/A
  void _onReminderTapped(String? payload) {
    debugPrint('[Reminder] notification tapped: $payload');
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    // Null the fields BEFORE disposing/closing so the receiver's forwarding
    // listener (`_localPushController?.add`) becomes a no-op rather than adding
    // to a closing controller (StateError: Cannot add event after closing).
    final localPushReceiver = _localPushReceiver;
    final localPushController = _localPushController;
    _localPushReceiver = null;
    _localPushController = null;
    unawaited(localPushReceiver?.dispose());
    unawaited(localPushController?.close());
    _taskService.dispose();
    unawaited(_debugBridge?.stop());
    unawaited(
      _epistaxisReminderService?.dispose().catchError(
        (Object e, StackTrace st) =>
            debugPrint('[EpistaxisReminder] dispose error: $e\n$st'),
      ),
    );
    unawaited(
      _yesterdayReminderService?.dispose().catchError(
        (Object e, StackTrace st) =>
            debugPrint('[YesterdayReminder] dispose error: $e\n$st'),
      ),
    );
    // Tear down the native outbound sync triggers + HTTP client before
    // disposing the scope they drive.
    unawaited(
      _diarySyncTriggers?.dispose().catchError(
        (Object e, StackTrace st) =>
            debugPrint('[DiarySyncTriggers] dispose error: $e\n$st'),
      ),
    );
    _diaryIngestClient?.close();
    _diaryScope?.dispose().catchError(
      (Object e, StackTrace st) =>
          debugPrint('[DiaryScope] dispose error: $e\n$st'),
    );
    super.dispose();
  }

  /// Folds the settings view rows into a `{key: SettingPayload}` map.
  // Tracks the corrective value most recently submitted for each picked setting,
  // so reconciliation submits at most once per out-of-set transition.
  String? _reconciledLangTarget;
  String? _reconciledFontTarget;

  /// Conditionally corrects the participant's language/font pick when it falls
  /// outside the resolved allow-set: dispatches a single `set_user_setting` to the
  /// allow-set default. A no-op when the pick is already allowed.
  // Implements: DIARY-DEV-deployment-config-defaults/E
  void _reconcileUiPicks(
    DiaryScopeRuntime diaryScope,
    UserPreferences prefs,
    SponsorUiConfig cfg,
  ) {
    final langFix = reconcilePick(
      current: prefs.languageCode,
      allowed: cfg.availableLanguages,
      fallback: cfg.defaultLanguage,
    );
    final fontFix = reconcilePick(
      current: prefs.selectedFont,
      allowed: cfg.availableFonts,
      fallback: cfg.defaultFont,
    );

    if (langFix == null) _reconciledLangTarget = null;
    if (fontFix == null) _reconciledFontTarget = null;

    if (langFix != null && langFix != _reconciledLangTarget) {
      _reconciledLangTarget = langFix;
      _submitUserSetting(diaryScope, prefLanguageCode, langFix);
    }
    if (fontFix != null && fontFix != _reconciledFontTarget) {
      _reconciledFontTarget = fontFix;
      _submitUserSetting(diaryScope, prefSelectedFont, fontFix);
    }
  }

  void _submitUserSetting(
    DiaryScopeRuntime diaryScope,
    String key,
    Object? value,
  ) {
    // Dispatch after the current frame so we never submit during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        diaryScope.scope.actionSubmitter.submit(
          esd.ActionSubmission(
            actionName: 'set_user_setting',
            rawInput: <String, Object?>{'key': key, 'value': value},
          ),
        ),
      );
    });
  }

  static Map<String, SettingPayload> _settingsByKey(
    ViewState<Map<String, Object?>> state,
  ) {
    final rows = switch (state) {
      Ready<Map<String, Object?>>(:final rows) => rows,
      Stale<Map<String, Object?>>(:final lastRows) => lastRows,
      _ => const <Map<String, Object?>>[],
    };
    final out = <String, SettingPayload>{};
    for (final row in rows) {
      final payload = SettingPayload.fromJson(row);
      out[payload.key] = payload;
    }
    return out;
  }

  /// Wraps [home] in the themed [MaterialApp]. When [prefs] is supplied the
  /// theme/locale/text-scale are driven by the settings projection; the
  /// pre-bootstrap loading/error screens pass null and get plain defaults.
  // Implements: DIARY-DEV-reactive-read-path/A — the app-root presentation
  //   layer holds no authoritative preference state; it is rebuilt from the
  //   settings projection.
  Widget _buildMaterialApp({
    required Widget home,
    UserPreferences? prefs,
    ClinicalRules? clinicalRules,
    SponsorUiConfig? sponsorUiConfig,
  }) {
    final effectivePrefs = prefs ?? const UserPreferences();
    final effectiveRules = clinicalRules ?? const ClinicalRules();
    final effectiveUiConfig = sponsorUiConfig ?? SponsorUiConfig.codeDefault;
    final font = effectivePrefs.selectedFont;
    final largerText = effectivePrefs.largerTextAndControls;
    final languageCode = effectivePrefs.languageCode;
    return MaterialApp(
      title: EnvProfile.current.title,
      // Show Flutter debug banner in debug mode (top-right corner).
      // Environment ribbon (DEV/QA) shows in top-left corner.
      debugShowCheckedModeBanner: kDebugMode,
      // CUR-528: Use theme with selected font.
      theme: AppTheme.getLightThemeWithFont(fontFamily: font),
      darkTheme: AppTheme.getDarkThemeWithFont(fontFamily: font),
      // CUR-424: Always light mode for alpha partners (dark mode stored but a
      // no-op).
      themeMode: ThemeMode.light,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Wrap all routes with ResponsiveWebFrame to constrain width on web.
      // CUR-488: Apply text scale factor for larger text preference.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final textScaleFactor = largerText
            ? mediaQuery.textScaler.scale(1.2)
            : 1.0;
        // AppPreferencesScope is inserted ABOVE the Navigator (here in builder)
        // so EVERY route — not just `home` — reads the current preferences via
        // AppPreferencesScope.of(context). Placing it around `home` only would
        // leave pushed routes (settings, calendar, recording) reading defaults.
        return SponsorUiConfigScope(
          config: effectiveUiConfig,
          child: AppPreferencesScope(
            preferences: effectivePrefs,
            child: ClinicalRulesScope(
              rules: effectiveRules,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(textScaleFactor),
                ),
                child: ResponsiveWebFrame(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return _buildMaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to initialize storage: $_bootstrapError'),
            ),
          ),
        ),
      );
    }
    final deviceId = _deviceId;
    final diaryScope = _diaryScope;
    if (deviceId == null || diaryScope == null) {
      return _buildMaterialApp(
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    // CUR-1169 B3.1: mount the LocalScope, then drive the themed MaterialApp
    // (theme/locale/text-scale) and the in-tree [AppPreferencesScope] off the
    // event-sourced settings projection. No app-root preference state remains.
    return ReActionScope(
      scope: diaryScope.scope,
      child: ViewBuilder<Map<String, Object?>>(
        viewName: settingsViewName,
        mapper: (r) => r,
        aggregateIdOf: (r) => r['aggregateId'] as String,
        builder: (context, state) {
          final settingsMap = _settingsByKey(state);
          final prefs = userPreferencesFromSettings(settingsMap);
          // Derive sponsor branding from the diary's own event-sourced settings
          // projection (the `branding.*` keys delivered set-once-at-link). No
          // public branding pull — reactive to the same settings stream.
          // Implements: DIARY-GUI-participation-status-badge/B
          final sponsorBranding = SponsorBrandingConfig.fromSettings(
            settingsMap,
          );
          // trialStart comes from the participant-lifecycle projection (I2c,
          // portal-gated); null until then — the lock then applies to all dates
          // past its threshold rather than only post-trial-start dates.
          final clinicalRules = ClinicalRules.fromSettings(
            settingsMap,
            trialStart: null,
          );
          // Resolve sponsor/deployment UI config (animation gate + font/language
          // allow-sets) and reconcile the participant's picks against it.
          // Implements: DIARY-DEV-deployment-config-defaults/A
          final sponsorUiConfig = SponsorUiConfig.fromSettings(
            settingsMap,
            deploymentDefaults: AppConfig.deploymentUiDefaults,
          );
          _reconcileUiPicks(diaryScope, prefs, sponsorUiConfig);
          // Feed the resolved Reminder Schedule (sponsor-over-personal-over-empty)
          // to the reminder service off the same settings projection.
          // Implements: DIARY-PRD-notification-ongoing-epistaxis/G+I+J
          _epistaxisReminderService?.updateSchedule(
            resolveEpistaxisReminderSchedule(settingsMap),
          );
          // Feed the resolved Yesterday reminder config (sponsor-over-personal)
          // plus the clinical lock gate so a locked day is never reminded.
          // Implements: DIARY-PRD-notification-yesterday-entry/F
          unawaited(
            _yesterdayReminderService?.updateConfig(
              config: resolveYesterdayReminderConfig(settingsMap),
              gate: clinicalRules.gate,
            ),
          );
          return _buildMaterialApp(
            prefs: prefs,
            clinicalRules: clinicalRules,
            sponsorUiConfig: sponsorUiConfig,
            // AppPreferencesScope is now provided above the Navigator inside
            // _buildMaterialApp's builder, so it covers HomeScreen AND every
            // pushed route. `home` is just the HomeScreen.
            home: HomeScreen(
              // A fresh device id after a factory reset re-keys HomeScreen so
              // its State is rebuilt from scratch against the new scope.
              key: ValueKey(deviceId),
              diaryScope: diaryScope,
              deviceId: deviceId,
              enrollmentService: _enrollmentService,
              taskService: _taskService,
              // Implements: DIARY-DEV-native-outbound-sync/B — surface a wedged
              //   native outbound FIFO (new diary_es.db store) in the banner.
              nativeFifoWedged: _nativeFifoWedged,
              // Implements: DIARY-GUI-service-mode-entry/A — builder forwarded
              //   to the tap-version-7x entry in the logo menu.
              serviceModeContextBuilder: _serviceModeContextBuilder,
              onEnrolled: _onPostEnrollment,
              onResetAllData: _resetAllData,
              // Implements: DIARY-BASE-local-data-reset/C — the sponsor-
              //   controllable layer of the reset gate, read from the
              //   event-sourced settings projection (default true).
              resetSettingAllowsReset: allowLocalResetSetting(settingsMap),
              sponsorBranding: sponsorBranding,
              // Implements: DIARY-DEV-sponsor-branding-assets/D — the logo is
              //   rendered from this content-addressed cache (JWT-gated
              //   fetch-once, verified, retained after participation ends).
              brandingAssetCache: _brandingAssetCache,
            ),
          );
        },
      ),
    );
  }
}
