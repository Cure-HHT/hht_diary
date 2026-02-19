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

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/data_export_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/file_read_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/notification_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:clinical_diary/widgets/environment_banner.dart';
import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:clinical_diary/widgets/update_banner_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Flavor name from build configuration.
/// APP_FLAVOR (--dart-define) takes priority over FLUTTER_APP_FLAVOR (--flavor).
/// This allows local dev to use --dart-define=APP_FLAVOR=local while keeping
/// --flavor dev for the Android build (which has no 'local' product flavor).
const String appFlavor = String.fromEnvironment('APP_FLAVOR') != ''
    ? String.fromEnvironment('APP_FLAVOR')
    : String.fromEnvironment('FLUTTER_APP_FLAVOR');

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

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('Firebase initialized successfully');
      } catch (e, stack) {
        debugPrint('Firebase initialization error: $e');
        debugPrint('Stack trace:\n$stack');
      }

      // Initialize append-only datastore for offline-first event storage
      try {
        // Generate a stable device ID (this would normally be persisted)
        const uuid = Uuid();
        final deviceId = uuid.v4();

        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: deviceId,
            userId: 'anonymous', // Will be updated after enrollment
          ),
        );
        debugPrint('Datastore initialized successfully');
      } catch (e, stack) {
        debugPrint('Datastore initialization error: $e');
        debugPrint('Stack trace:\n$stack');
      }

      // Timezone is now embedded in ISO 8601 timestamp strings via DateTimeFormatter.
      // No separate TimezoneService initialization needed.

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

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  final EnrollmentService _enrollmentService = EnrollmentService();
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  late final NosebleedService _nosebleedService;
  MobileNotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nosebleedService = NosebleedService(enrollmentService: _enrollmentService);
    _performAutoImport();
    _initializeNotifications();
  }

  /// REQ-CAL-p00081: Sync tasks when app resumes from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_taskService.syncTasks(_enrollmentService));
    }
  }

  /// Initialize FCM notification service and task loading.
  ///
  /// REQ-CAL-p00081: Task system initialization
  /// REQ-CAL-p00023-D: Push notification receiving
  /// REQ-CAL-p00082: Patient Alert Delivery (FCM token registration)
  Future<void> _initializeNotifications() async {
    // Load persisted tasks from storage
    await _taskService.loadTasks();

    // REQ-CAL-p00081: Poll for tasks on app start (FCM fallback)
    unawaited(_taskService.syncTasks(_enrollmentService));

    // Initialize FCM
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
  /// The diary server stores the token in the shared database so the
  /// portal server can send targeted notifications.
  ///
  /// Uses [EnrollmentService] for JWT and backend URL because the patient
  /// authenticates via linking codes (not username/password login).
  /// The backend URL is sponsor-specific, determined by the linking code prefix.
  ///
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
    WidgetsBinding.instance.removeObserver(this);
    _notificationService?.dispose();
    _taskService.dispose();
    super.dispose();
  }

  /// Auto-import data from file if IMPORT_FILE was specified via dart-define.
  /// This is useful for testing with pre-populated data.
  Future<void> _performAutoImport() async {
    if (!AppConfig.hasImportFile) return;

    debugPrint(
      '[AutoImport] IMPORT_FILE specified: ${AppConfig.importFilePath}',
    );

    try {
      final fileContent = await FileReadService.readFile(
        AppConfig.importFilePath,
      );

      if (fileContent == null) {
        debugPrint('[AutoImport] Could not read file');
        return;
      }

      final exportService = DataExportService(
        nosebleedService: _nosebleedService,
        preferencesService: widget.preferencesService,
        enrollmentService: _enrollmentService,
      );

      final result = await exportService.importAppState(fileContent);

      if (result.success) {
        debugPrint(
          '[AutoImport] Success: ${result.recordsImported} records imported',
        );
      } else {
        debugPrint('[AutoImport] Failed: ${result.error}');
      }
    } catch (e, stack) {
      debugPrint('[AutoImport] Error: $e');
      debugPrint('[AutoImport] Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Go directly to home screen - clinical trial enrollment is accessed
    // from the user profile menu, not at app startup
    // CUR-513: Wrap with UpdateBannerWrapper for version update notifications
    return UpdateBannerWrapper(
      child: HomeScreen(
        nosebleedService: _nosebleedService,
        enrollmentService: _enrollmentService,
        authService: _authService,
        taskService: _taskService,
        onLocaleChanged: widget.onLocaleChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
        onLargerTextChanged: widget.onLargerTextChanged,
        onFontChanged: widget.onFontChanged,
        preferencesService: widget.preferencesService,
        onEnrolled: _onPostEnrollment,
      ),
    );
  }
}
