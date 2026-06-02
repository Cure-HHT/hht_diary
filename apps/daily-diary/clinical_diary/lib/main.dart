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
import 'dart:io' show Platform, pid;

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/destinations/legacy_questionnaire_submit_destination.dart';
import 'package:clinical_diary/destinations/legacy_sync_destination.dart';
import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/scope/diary_sync_triggers.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/debug_bridge.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/local_data_reset.dart';
import 'package:clinical_diary/services/notification_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/settings/local_reset_policy.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart' show SembastBackend;
// Prefixed to disambiguate the new-stack AutomationInitiator from the legacy
// `event_sourcing_datastore` AutomationInitiator imported above; the new diary
// scope's DestinationRegistry.setStartDate takes the new-stack Initiator.
import 'package:event_sourcing/event_sourcing.dart'
    as esd
    show AutomationInitiator;
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show AutomationInitiator;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Flavor name from build configuration.
/// APP_FLAVOR (--dart-define) takes priority over FLUTTER_APP_FLAVOR (--flavor).
/// This allows local dev to use --dart-define=APP_FLAVOR=local while keeping
/// --flavor dev for the Android build (which has no 'local' product flavor).
const String appFlavor = String.fromEnvironment('APP_FLAVOR') != ''
    ? String.fromEnvironment('APP_FLAVOR')
    : String.fromEnvironment('FLUTTER_APP_FLAVOR');

/// SharedPreferences key for the persisted device install UUID.
const _kDeviceIdPrefsKey = 'clinical_diary.device_id';

void main() async {
  // Security (CUR-1169): silence debugPrint in release builds. Flutter's
  // debugPrint is NOT stripped from release; it forwards to the platform log
  // stream (logcat/oslog), where any logged response body or identifier becomes
  // readable by privileged processes / log collectors. Production observability
  // is server-side (OTel), not device logs, so drop all debug output in release.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  // Initialize flavor from native platform configuration
  F.appFlavor = Flavor.values.firstWhere(
    (f) => f.name == appFlavor,
    orElse: () => Flavor.dev, // Default to dev if not specified
  );
  debugPrint('Running with flavor: ${F.name}');
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

      // Initialize IANA timezone database for DST-aware time calculations
      TimezoneConverter.ensureInitialized();

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
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

      // CUR-546: Load Callisto feature flags by default for demo
      try {
        await FeatureFlagService.instance.loadFromServer('callisto');
      } catch (e, stack) {
        debugPrint('Feature flag loading error: $e');
        debugPrint('Stack trace:\n$stack');
      }

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
      show: F.showBanner,
      flavorName: F.name,
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
  ClinicalDiaryRuntime? _runtime;

  /// CUR-1169 I1: the new reactive composition root, built alongside (not
  /// replacing) [_runtime]. Mounted into the tree via [ReActionScope] so
  /// reaction widgets can resolve a `LocalScope` during the transition.
  DiaryScopeRuntime? _diaryScope;

  /// CUR-1169 I2a: foreground drain triggers (app-resume / connectivity /
  /// periodic) for the new-stack native outbound sync. The post-action-submit
  /// drain is wired through the bootstrap's `syncCycleTrigger`; these cover the
  /// remaining trigger sources. Disposed with the runtime.
  DiarySyncTriggerHandles? _diarySyncTriggers;

  /// HTTP client owned by the native outbound [DiaryServerDestination]. Closed
  /// on [dispose] so the destination's transport is torn down cleanly.
  http.Client? _diaryIngestClient;

  /// Native outbound FIFO wedge check (the new `diary_es.db` store), forwarded
  /// to [HomeScreen] so its banner reflects a stuck native sync the legacy
  /// `runtime.backend` cannot see. DIARY-DEV-native-outbound-sync/B.
  Future<bool> Function()? _nativeFifoWedged;

  /// Persistent device install UUID, minted on first launch and reused
  /// thereafter. Forwarded to [HomeScreen] for the export payload.
  String? _deviceId;
  MobileNotificationService? _notificationService;
  Object? _bootstrapError;
  DebugBridge? _debugBridge;

  @override
  void initState() {
    super.initState();
    _initializeRuntime();
    _initializeNotifications();
  }

  /// Bootstrap the event-sourcing runtime: open Sembast DB, mint or read the
  /// device ID, and compose the [ClinicalDiaryRuntime].
  Future<void> _initializeRuntime() async {
    try {
      // Cross-platform Sembast: io for native (file-backed), web for browser
      // (IndexedDB-backed via sembast_web). path_provider has no web
      // implementation, so the docs-dir lookup is io-only.
      final DatabaseFactory factory;
      final String dbPath;
      if (kIsWeb) {
        factory = databaseFactoryWeb;
        dbPath = 'diary.db'; // IndexedDB store name
      } else {
        factory = databaseFactoryIo;
        final docsDir = await getApplicationDocumentsDirectory();
        dbPath = '${docsDir.path}/diary.db';
      }
      final db = await factory.openDatabase(dbPath);

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

      final userId = await _enrollmentService.getUserId() ?? 'pre-enrollment';

      final runtime = await bootstrapClinicalDiary(
        sembastDatabase: db,
        authToken: _enrollmentService.getJwtToken,
        // The participant's backend URL is resolved from their linking code at
        // enrollment time and persisted by EnrollmentService. Resolve it
        // lazily on every use so the destination + inbound poll automatically
        // pick up the URL the moment the participant links, without requiring a
        // bootstrap-time restart. Returns null pre-enrollment, which the
        // destination + inbound poll handle as "skip this cycle".
        resolveBaseUrl: () async {
          final base = await _enrollmentService.getBackendUrl();
          if (base == null) return null;
          // Trailing slash so the destination's `.resolve('events')` (and
          // the inbound poll's `.resolve('inbound')`) produce
          // `<backend>/api/v1/user/events` / `…/inbound`.
          return Uri.parse('$base/api/v1/user/');
        },
        deviceId: deviceId,
        softwareVersion: softwareVersion,
        userId: userId,
        // CUR-1164: Skip outbound sync + inbound poll while disconnected.
        // Closure over the notifier value keeps the check sync.
        isDisconnected: () => _enrollmentService.disconnectedNotifier.value,
        // CUR-1398: include task-sync in every periodic / resume /
        // connectivity / FCM-triggered tick so foreground state stays
        // correct even when FCM delivery is slow or fails. Cold-start sync
        // is still done separately in _initializeNotifications.
        tasksSync: () => _taskService.syncTasks(_enrollmentService),
      );

      // Activate both legacy-shim destinations once at first install.
      // The startDate is "today" on first install: there are no events
      // recorded before the app exists, so anchoring the destination
      // there is the correct watermark. setStartDate is monotonically
      // non-increasing (REQ-d00129-C) — read the current schedule and
      // skip the write when the destination is already activated so a
      // process restart is a no-op. Each activation runs in its own
      // try/catch so a failure on one destination does not prevent the
      // other from coming online.
      const initiator = AutomationInitiator(service: 'mobile-bootstrap');
      final activationStartAt = DateTime.now().toUtc();
      for (final destinationId in <String>[
        LegacySyncDestination.destinationId,
        LegacyQuestionnaireSubmitDestination.destinationId,
      ]) {
        try {
          final schedule = await runtime.destinations.scheduleOf(destinationId);
          if (schedule.startDate != null) continue;
          await runtime.destinations.setStartDate(
            destinationId,
            activationStartAt,
            initiator: initiator,
          );
        } catch (e, stack) {
          debugPrint(
            '[Bootstrap] activation($destinationId) failed: $e\n$stack',
          );
        }
      }

      // CUR-1169 I1: build the new reactive composition root alongside the
      // old runtime. Backed by a SEPARATE Sembast store (diary_es.db) so it
      // shares nothing with the legacy store; mirrors the web/native factory
      // selection above. Reuses the already-computed deviceId/softwareVersion.
      // Failures route to _bootstrapError via the enclosing try/catch, exactly
      // like the old runtime.
      final DiaryScopeRuntime diaryScope;
      Future<bool> Function()? nativeFifoWedged;
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
        final destination = DiaryServerDestination(
          client: ingestClient,
          // Native ingest endpoint: <backend>/api/v1/ingest/batch. Returns null
          // pre-enrollment, which the destination treats as "skip this cycle".
          resolveIngestUrl: () async {
            final base = await _enrollmentService.getBackendUrl();
            if (base == null) return null;
            return Uri.parse('$base/api/v1/ingest/batch');
          },
          authToken: _enrollmentService.getJwtToken,
        );

        // The native outbound FIFO lives in this (new) store; capture a wedge
        // check for the home-screen banner — the legacy runtime.backend can't
        // see it. DIARY-DEV-native-outbound-sync/B.
        final esBackend = SembastBackend(database: esDb);
        nativeFifoWedged = esBackend.hasFifoWedged;

        try {
          diaryScope = await bootstrapDiaryScope(
            backend: esBackend,
            deviceId: deviceId,
            softwareVersion: softwareVersion,
            localUserId: deviceId, // stable per-install id; recording is never
            // enrollment-gated
            outboundDestination: destination,
          );
        } catch (_) {
          ingestClient.close();
          _diaryIngestClient = null;
          await esDb.close();
          rethrow;
        }

        // Implements: DIARY-DEV-native-outbound-sync/C
        // Activate the native destination at the trial-start watermark so
        // pre-trial events stay local (parity with the legacy destinations,
        // which anchor at first-install "now"). Greenfield: no events exist
        // before the app does, so "now" at first activation IS the trial start.
        // setStartDate is monotonically non-increasing — skip the write when
        // already activated so a process restart is a no-op.
        const watermarkInitiator = esd.AutomationInitiator(
          service: 'mobile-bootstrap',
        );
        try {
          final schedule = await diaryScope.bundle.destinations.scheduleOf(
            DiaryServerDestination.destinationId,
          );
          if (schedule.startDate == null) {
            await diaryScope.bundle.destinations.setStartDate(
              DiaryServerDestination.destinationId,
              DateTime.now().toUtc(),
              initiator: watermarkInitiator,
            );
          }
        } catch (e, stack) {
          debugPrint(
            '[Bootstrap] native destination activation failed: $e\n$stack',
          );
        }

        // Install the foreground drain triggers (app-resume / connectivity /
        // periodic). The post-action-submit drain is already wired through the
        // bootstrap's syncCycleTrigger; these route into the same SyncCycle.
        final syncCycle = diaryScope.syncCycle;
        if (syncCycle != null) {
          try {
            _diarySyncTriggers = await installDiarySyncTriggers(
              onTrigger: syncCycle.call,
            );
          } catch (e, stack) {
            debugPrint('[Bootstrap] diary sync triggers failed: $e\n$stack');
          }
        }
      }

      if (mounted) {
        setState(() {
          _runtime = runtime;
          _deviceId = deviceId;
          _diaryScope = diaryScope;
          _nativeFifoWedged = nativeFifoWedged;
        });
      }

      // Start the local-only HTTP debug bridge. Loopback-bound and gated
      // on Flavor.local + !kIsWeb (shelf needs dart:io). Failure to bind
      // is logged and swallowed so a port collision does not block app
      // bring-up.
      if (F.appFlavor == Flavor.local && !kIsWeb) {
        try {
          final bridge = DebugBridge(
            runtime: runtime,
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

    // 2. Dispose both runtimes (closes both EventStores so the files unlock),
    //    plus the I2a sync-trigger handles + ingest client — mirrors dispose().
    try {
      await _runtime?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] runtime dispose failed: $e\n$stack');
    }
    try {
      await _diarySyncTriggers?.dispose();
    } catch (e, stack) {
      debugPrint('[Reset] sync-trigger dispose failed: $e\n$stack');
    }
    _diarySyncTriggers = null;
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
        _runtime = null;
        _diaryScope = null;
        _nativeFifoWedged = null;
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
  /// topic subscription. Per the cutover plan we no longer hook FCM messages
  /// into a sync trigger — `installTriggers` (set up by the bootstrap) covers
  /// that path. Any FCM data messages that need to surface tasks still flow
  /// through TaskService.handleFcmMessage as before.
  Future<void> _initializeNotifications() async {
    // Load persisted tasks from storage
    await _taskService.loadTasks();

    // REQ-CAL-p00081: Poll for tasks on app start (FCM fallback)
    unawaited(_taskService.syncTasks(_enrollmentService));

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

  /// Register the FCM token with the diary server.
  ///
  /// Called on initial token retrieval and on token refresh.
  /// REQ-CAL-p00082: Participant Alert Delivery
  Future<void> _registerFcmToken(String token) async {
    final jwt = await _enrollmentService.getJwtToken();
    if (jwt == null) {
      debugPrint('[FCM] No JWT — user not linked yet, skipping');
      return;
    }

    final backendUrl = await _enrollmentService.getBackendUrl();
    if (backendUrl == null) {
      debugPrint('[FCM] No backend URL — user not linked yet, skipping');
      return;
    }

    final platform = Platform.isIOS ? 'ios' : 'android';
    final url = '$backendUrl/api/v1/user/fcm-token';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'fcm_token': token, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        debugPrint('[FCM] Token registered with diary server ($platform)');
      } else {
        debugPrint('[FCM] Token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
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
    // REQ-CAL-p00081: Discover tasks immediately after linking
    unawaited(_taskService.syncTasks(_enrollmentService));
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    _taskService.dispose();
    unawaited(_debugBridge?.stop());
    _runtime?.dispose();
    // CUR-1169 I2a: tear down the native outbound sync triggers + HTTP client
    // before disposing the scope they drive.
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
  }) {
    final effectivePrefs = prefs ?? const UserPreferences();
    final effectiveRules = clinicalRules ?? const ClinicalRules();
    final font = effectivePrefs.selectedFont;
    final largerText = effectivePrefs.largerTextAndControls;
    final languageCode = effectivePrefs.languageCode;
    return MaterialApp(
      title: F.title,
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
        return AppPreferencesScope(
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
    final runtime = _runtime;
    final deviceId = _deviceId;
    final diaryScope = _diaryScope;
    if (runtime == null || deviceId == null || diaryScope == null) {
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
          // trialStart comes from the participant-lifecycle projection (I2c,
          // portal-gated); null until then — the lock then applies to all dates
          // past its threshold rather than only post-trial-start dates.
          final clinicalRules = ClinicalRules.fromSettings(
            settingsMap,
            trialStart: null,
          );
          return _buildMaterialApp(
            prefs: prefs,
            clinicalRules: clinicalRules,
            // AppPreferencesScope is now provided above the Navigator inside
            // _buildMaterialApp's builder, so it covers HomeScreen AND every
            // pushed route. `home` is just the HomeScreen.
            home: HomeScreen(
              // A fresh device id after a factory reset re-keys HomeScreen so
              // its State is rebuilt from scratch against the new runtime.
              key: ValueKey(deviceId),
              runtime: runtime,
              deviceId: deviceId,
              enrollmentService: _enrollmentService,
              taskService: _taskService,
              // Implements: DIARY-DEV-native-outbound-sync/B — surface a wedged
              //   native outbound FIFO (new diary_es.db store) in the banner.
              nativeFifoWedged: _nativeFifoWedged,
              onEnrolled: _onPostEnrollment,
              onResetAllData: _resetAllData,
              // Implements: DIARY-BASE-local-data-reset/C — the sponsor-
              //   controllable layer of the reset gate, read from the
              //   event-sourced settings projection (default true).
              resetSettingAllowsReset: allowLocalResetSetting(settingsMap),
            ),
          );
        },
      ),
    );
  }
}
