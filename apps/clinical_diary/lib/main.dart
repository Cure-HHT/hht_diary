// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00006: Mobile App Build and Release Process

import 'dart:async';

import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
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
  ThemeMode _themeMode = ThemeMode.system;
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
      _themeMode = prefs.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _setLocale(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  void _setThemeMode(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nosebleed Diary',
      debugShowCheckedModeBanner: false,
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
      home: AppRoot(
        onLocaleChanged: _setLocale,
        onThemeModeChanged: _setThemeMode,
        preferencesService: _preferencesService,
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.preferencesService,
    super.key,
  });

  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final PreferencesService preferencesService;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final EnrollmentService _enrollmentService = EnrollmentService();
  late final NosebleedService _nosebleedService;

  @override
  void initState() {
    super.initState();
    _nosebleedService = NosebleedService(
      enrollmentService: _enrollmentService,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Go directly to home screen - clinical trial enrollment is accessed
    // from the user profile menu, not at app startup
    return HomeScreen(
      nosebleedService: _nosebleedService,
      enrollmentService: _enrollmentService,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
      preferencesService: widget.preferencesService,
    );
  }
}
