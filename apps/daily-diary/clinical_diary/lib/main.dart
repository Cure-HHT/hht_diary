// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00006: Mobile App Build and Release Process
//   REQ-p00008: Single App Architecture
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/diary_event_bridge.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/notification_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show AutomationInitiator;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
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

/// Default primary diary server URL. In production this would be derived
/// from the linking code; for now a fixed dev URL keeps bootstrap simple.
const _kDefaultPrimaryDiaryServer = 'https://diary.example.com';

void main() async {
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
  Locale _locale = const Locale('en');
  // CUR-424: Force light mode for alpha partners (no system/dark mode)
  ThemeMode _themeMode = ThemeMode.light;
  // CUR-488: Larger text and controls preference
  bool _largerTextAndControls = false;
  // CUR-528: Selected font family
  String _selectedFont = 'Roboto';
  final PreferencesService _preferencesService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _preferencesService.getPreferences();
    setState(() {
      _locale = Locale(prefs.languageCode);
      // CUR-424: Always use light mode for alpha partners
      _themeMode = ThemeMode.light;
      // CUR-488: Load larger text preference
      _largerTextAndControls = prefs.largerTextAndControls;
      // CUR-528: Load selected font preference
      _selectedFont = prefs.selectedFont;
    });
  }

  void _setLocale(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  void _setThemeMode(bool isDarkMode) {
    // CUR-424: Ignore dark mode requests, always use light mode for alpha
    setState(() {
      _themeMode = ThemeMode.light;
    });
  }

  // CUR-488: Update larger text preference
  void _setLargerTextAndControls(bool value) {
    setState(() {
      _largerTextAndControls = value;
    });
  }

  // CUR-528: Update selected font preference
  void _setFont(String fontFamily) {
    setState(() {
      _selectedFont = fontFamily;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with EnvironmentBanner to show DEV/QA ribbon in non-production builds
    return EnvironmentBanner(
      show: F.showBanner,
      flavorName: F.name,
      child: MaterialApp(
        title: F.title,
        // Show Flutter debug banner in debug mode (top-right corner)
        // Environment ribbon (DEV/QA) shows in top-left corner
        debugShowCheckedModeBanner: kDebugMode,
        // CUR-528: Use theme with selected font
        theme: AppTheme.getLightThemeWithFont(fontFamily: _selectedFont),
        darkTheme: AppTheme.getDarkThemeWithFont(fontFamily: _selectedFont),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Wrap all routes with ResponsiveWebFrame to constrain width on web
        // CUR-488: Apply text scale factor for larger text preference
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          // Scale text by 1.2x when larger text is enabled
          final textScaleFactor = _largerTextAndControls
              ? mediaQuery.textScaler.scale(1.2)
              : 1.0;
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: ResponsiveWebFrame(child: child ?? const SizedBox.shrink()),
          );
        },
        home: AppRoot(
          onLocaleChanged: _setLocale,
          onThemeModeChanged: _setThemeMode,
          onLargerTextChanged: _setLargerTextAndControls,
          onFontChanged: _setFont,
          preferencesService: _preferencesService,
        ),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.onLargerTextChanged,
    required this.onFontChanged,
    required this.preferencesService,
    super.key,
  });

  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  // CUR-488: Callback for larger text preference changes
  final ValueChanged<bool> onLargerTextChanged;
  // CUR-528: Callback for font selection changes
  final ValueChanged<String> onFontChanged;
  final PreferencesService preferencesService;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final EnrollmentService _enrollmentService = EnrollmentService();
  final TaskService _taskService = TaskService();
  ClinicalDiaryRuntime? _runtime;
  DiaryEventBridge? _bridge;
  MobileNotificationService? _notificationService;
  Object? _bootstrapError;

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
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = '${docsDir.path}/diary.db';
      final db = await databaseFactoryIo.openDatabase(dbPath);

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
        deviceId: deviceId,
        softwareVersion: softwareVersion,
        userId: userId,
        primaryDiaryServerBaseUrl: Uri.parse(_kDefaultPrimaryDiaryServer),
      );

      // Activate the primary destination once at boot. setStartDate is
      // idempotent — calling it on a destination that is already at the
      // requested startDate is a no-op.
      try {
        await runtime.destinations.setStartDate(
          'primary_diary_server',
          DateTime.utc(2020, 1, 1),
          initiator: const AutomationInitiator(service: 'mobile-bootstrap'),
        );
      } catch (e, stack) {
        debugPrint('[Bootstrap] setStartDate failed: $e\n$stack');
      }

      if (mounted) {
        setState(() {
          _runtime = runtime;
          _bridge = DiaryEventBridge(
            entryService: runtime.entryService,
            reader: runtime.reader,
          );
        });
      }
    } catch (e, stack) {
      debugPrint('[Bootstrap] Runtime init failed: $e\n$stack');
      if (mounted) {
        setState(() => _bootstrapError = e);
      }
    }
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
  /// REQ-CAL-p00082: Patient Alert Delivery
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
        debugPrint(
          '[FCM] Token registration failed: ${response.statusCode} '
          '${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }
  }

  /// Called after the user successfully links to a study.
  /// Registers the cached FCM token with the diary server now that
  /// the JWT and backend URL are available.
  ///
  /// REQ-CAL-p00082: Patient Alert Delivery
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
    _runtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to initialize storage: $_bootstrapError'),
          ),
        ),
      );
    }
    final runtime = _runtime;
    final bridge = _bridge;
    if (runtime == null || bridge == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeScreen(
      runtime: runtime,
      bridge: bridge,
      enrollmentService: _enrollmentService,
      taskService: _taskService,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
      onLargerTextChanged: widget.onLargerTextChanged,
      onFontChanged: widget.onFontChanged,
      preferencesService: widget.preferencesService,
      onEnrolled: _onPostEnrollment,
    );
  }
}
