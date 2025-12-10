// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00006: Mobile App Build and Release Process
//   REQ-p00008: Single App Architecture

import 'dart:async';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:clinical_diary/widgets/environment_banner.dart';
import 'package:clinical_diary/widgets/responsive_web_frame.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uuid/uuid.dart';

/// Flavor name passed from native code via --dart-define or Xcode/Gradle config.
/// For iOS/Android, Flutter sets FLUTTER_APP_FLAVOR when using --flavor flag.
/// For web builds (where --flavor isn't supported), use APP_FLAVOR instead.
const String appFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR') != ''
    ? String.fromEnvironment('FLUTTER_APP_FLAVOR')
    : String.fromEnvironment('APP_FLAVOR');

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

  @override
  Widget build(BuildContext context) {
    // Wrap with EnvironmentBanner to show DEV/QA ribbon in non-production builds
    return EnvironmentBanner(
      child: MaterialApp(
        title: F.title,
        // Show Flutter debug banner in debug mode (top-right corner)
        // Environment ribbon (DEV/QA) shows in top-left corner
        debugShowCheckedModeBanner: kDebugMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
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
    required this.preferencesService,
    super.key,
  });

  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  // CUR-488: Callback for larger text preference changes
  final ValueChanged<bool> onLargerTextChanged;
  final PreferencesService preferencesService;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final EnrollmentService _enrollmentService = EnrollmentService();
  final AuthService _authService = AuthService();
  late final NosebleedService _nosebleedService;

  @override
  void initState() {
    super.initState();
    _nosebleedService = NosebleedService(enrollmentService: _enrollmentService);
  }

  @override
  Widget build(BuildContext context) {
    // Go directly to home screen - clinical trial enrollment is accessed
    // from the user profile menu, not at app startup
    return HomeScreen(
      nosebleedService: _nosebleedService,
      enrollmentService: _enrollmentService,
      authService: _authService,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
      onLargerTextChanged: widget.onLargerTextChanged,
      preferencesService: widget.preferencesService,
    );
  }
}
