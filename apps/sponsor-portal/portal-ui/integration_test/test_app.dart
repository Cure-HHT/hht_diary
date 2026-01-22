// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00010: First Admin Provisioning
//   REQ-CAL-p00029: Create User Account
//   REQ-d00031: Identity Platform Integration
//
// Test app builder for portal-ui Flutter integration tests.
// Configures the app to run against real services (no mocks):
// - Firebase Auth emulator or GCP Identity Platform
// - Portal server on localhost:8080
// - PostgreSQL database

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sponsor_portal_ui/firebase_options.dart';
import 'package:sponsor_portal_ui/flavors.dart';
import 'package:sponsor_portal_ui/router/app_router.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/theme/portal_theme.dart';
import 'package:provider/provider.dart';

/// Test configuration from environment
class IntegrationTestConfig {
  /// True when using real GCP Identity Platform instead of Firebase emulator
  static bool get useDevIdentity =>
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] == null &&
      Platform.environment['PORTAL_IDENTITY_API_KEY'] != null;

  static String get firebaseEmulatorHost =>
      Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? 'localhost:9099';

  static String get portalServerUrl =>
      Platform.environment['PORTAL_SERVER_URL'] ?? 'http://localhost:8080';

  /// Dev admin email for tests
  static String get devAdminEmail => 'mike.bushe@anspar.org';

  /// Dev admin password (from environment or default)
  static String get devAdminPassword =>
      Platform.environment['DEV_ADMIN_PASSWORD'] ?? 'curehht';
}

/// Initialize Firebase for integration tests
///
/// Must be called in setUpAll before building the test app.
/// Configures Firebase to use emulator or real Identity Platform based on environment.
Future<void> initializeFirebaseForTests() async {
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flavor (local for emulator, dev for Identity Platform)
  if (IntegrationTestConfig.useDevIdentity) {
    FlavorConfig.initialize(Flavor.dev);
    debugPrint('Integration tests: Using GCP Identity Platform');
  } else {
    FlavorConfig.initialize(Flavor.local);
    debugPrint(
      'Integration tests: Using Firebase emulator at ${IntegrationTestConfig.firebaseEmulatorHost}',
    );
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to emulator if not using real Identity Platform
  if (!IntegrationTestConfig.useDevIdentity) {
    final parts = IntegrationTestConfig.firebaseEmulatorHost.split(':');
    final host = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099;
    try {
      await FirebaseAuth.instance.useAuthEmulator(host, port);
      debugPrint('Connected to Firebase Auth emulator at $host:$port');
    } catch (e) {
      debugPrint('Failed to connect to Firebase Auth emulator: $e');
    }
  }
}

/// Build the test app with real services
///
/// Creates the portal app configured for integration testing.
/// Uses real Firebase Auth (emulator or Identity Platform) and real portal server.
Widget buildTestApp({AuthService? authService}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => authService ?? AuthService()),
    ],
    child: MaterialApp.router(
      title: 'Portal UI Integration Test',
      theme: portalTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Sign out current user (cleanup helper)
Future<void> signOutCurrentUser() async {
  try {
    await FirebaseAuth.instance.signOut();
    debugPrint('Signed out current user');
  } catch (e) {
    debugPrint('Error signing out: $e');
  }
}
