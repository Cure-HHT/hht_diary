// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00006: Mobile App Build and Release Process

import 'dart:async';

import 'package:clinical_diary/firebase_options.dart';
import 'package:clinical_diary/screens/enrollment_screen.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

class ClinicalDiaryApp extends StatelessWidget {
  const ClinicalDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nosebleed Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppRoot(),
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
  late final NosebleedService _nosebleedService;

  bool _isLoading = true;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _nosebleedService = NosebleedService(
      enrollmentService: _enrollmentService,
    );
    _checkEnrollment();
  }

  Future<void> _checkEnrollment() async {
    final isEnrolled = await _enrollmentService.isEnrolled();
    setState(() {
      _isEnrolled = isEnrolled;
      _isLoading = false;
    });
  }

  void _handleEnrolled() {
    setState(() {
      _isEnrolled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isEnrolled) {
      return EnrollmentScreen(
        enrollmentService: _enrollmentService,
        onEnrolled: _handleEnrolled,
      );
    }

    return HomeScreen(
      nosebleedService: _nosebleedService,
    );
  }
}
