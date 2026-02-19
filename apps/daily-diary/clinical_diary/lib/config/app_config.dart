// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/flavors.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Exception thrown when required configuration is missing.
class MissingConfigException implements Exception {
  MissingConfigException(this.configName, this.message);

  final String configName;
  final String message;

  @override
  String toString() => 'MissingConfigException: $configName - $message';
}

/// Application configuration.
///
/// Configuration is derived from the app flavor set at compile time.
/// Run with: flutter run --dart-define=APP_FLAVOR=dev
///
/// For mobile builds, --flavor dev also works (sets FLUTTER_APP_FLAVOR).
/// For web builds, use --dart-define=APP_FLAVOR=dev.
///
/// All other configuration (apiBase, showDevTools, showBanner) is derived
/// from the flavor via [FlavorConfig].
class AppConfig {
  // Private constructor - this is a static utility class
  AppConfig._();

  // ============================================================
  // Environment Configuration (from F class)
  // ============================================================

  /// Current flavor/environment - delegates to F class
  static Flavor get environment => F.appFlavor;

  /// Whether to show the environment banner (DEV/TEST ribbon)
  static bool get showBanner => F.showBanner;

  // ============================================================
  // API Configuration
  // ============================================================

  /// QA API key from dart-define (only for dev/qa environments)
  static const String _qaApiKeyRaw = String.fromEnvironment(
    'CUREHHT_QA_API_KEY',
  );

  /// QA API key - returns empty string if not configured
  static String get qaApiKey => _qaApiKeyRaw;

  /// Compile-time override for API base URL.
  /// Pass via: --dart-define=BACKEND_URL=http://10.0.2.2:8080
  /// Used by run_local.sh to point the app at a local diary server.
  static const String _backendUrlOverride = String.fromEnvironment(
    'BACKEND_URL',
  );

  /// Test-only override for API base URL.
  /// Set this in test setUp() to override the flavor-based apiBase.
  @visibleForTesting
  static String? testApiBaseOverride;

  /// API base URL - derived from the current flavor.
  /// Points to the diary-server Cloud Run service.
  /// Can be overridden at compile time via BACKEND_URL dart-define,
  /// or at test time via testApiBaseOverride.
  static String get apiBase {
    // Allow test override
    if (testApiBaseOverride != null) {
      return testApiBaseOverride!;
    }
    // Allow compile-time override for local development
    if (_backendUrlOverride.isNotEmpty) {
      return _backendUrlOverride;
    }
    return FlavorConfig.byName(F.name).apiBase;
  }

  // API Endpoints - paths match diary_server routes.dart
  // Auth routes
  static String get registerUrl => '$apiBase/api/v1/auth/register';
  static String get loginUrl => '$apiBase/api/v1/auth/login';
  static String get changePasswordUrl => '$apiBase/api/v1/auth/change-password';

  // User routes
  static String get enrollUrl =>
      '$apiBase/api/v1/user/enroll'; // Deprecated, returns 410
  static String get linkUrl =>
      '$apiBase/api/v1/user/link'; // Patient linking via sponsor portal codes
  static String get syncUrl => '$apiBase/api/v1/user/sync';
  static String get getRecordsUrl => '$apiBase/api/v1/user/records';

  // Sponsor routes
  static String sponsorConfigUrl(String sponsorId) =>
      '$apiBase/api/v1/sponsor/config?sponsorId=$sponsorId';

  // Health check
  static String get healthUrl => '$apiBase/health';

  // ============================================================
  // App Metadata
  // ============================================================

  /// App name displayed in UI
  static const String appName = 'Nosebleed Diary';

  /// Whether we're in debug mode (legacy - prefer environment checks)
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false,
  );

  // ============================================================
  // Testing Configuration
  // ============================================================

  /// Path to a JSON file to auto-import on app startup.
  /// Used for testing with pre-populated data.
  /// Pass via: --dart-define=IMPORT_FILE=/path/to/export.json
  static const String importFilePath = String.fromEnvironment('IMPORT_FILE');

  /// Whether an import file was specified
  static bool get hasImportFile => importFilePath.isNotEmpty;

  // ============================================================
  // Convenience Getters
  // ============================================================

  /// Whether to show dev tools menu items (Reset All Data, Add Example Data).
  /// Determined by flavor - only shown in dev and test environments.
  static bool get showDevTools => F.showDevTools;
}
