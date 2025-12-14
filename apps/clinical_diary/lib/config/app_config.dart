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

  /// Test-only override for API base URL.
  /// Set this in test setUp() to override the flavor-based apiBase.
  @visibleForTesting
  static String? testApiBaseOverride;

  /// API base URL - derived from the current flavor.
  /// Uses Firebase Hosting rewrites to proxy to functions,
  /// avoiding CORS issues and org policy restrictions.
  static String get apiBase {
    // Allow test override
    if (testApiBaseOverride != null) {
      return testApiBaseOverride!;
    }
    return FlavorConfig.byName(F.name).apiBase;
  }

  // API Endpoints
  static String get enrollUrl => '$apiBase/enroll';
  static String get healthUrl => '$apiBase/health';
  static String get syncUrl => '$apiBase/sync';
  static String get getRecordsUrl => '$apiBase/getRecords';
  static String get registerUrl => '$apiBase/register';
  static String get loginUrl => '$apiBase/login';
  static String get changePasswordUrl => '$apiBase/changePassword';
  static String sponsorConfigUrl(String sponsorId, String apiKey) =>
      '$apiBase/sponsorConfig?sponsorId=$sponsorId&apiKey=$apiKey';

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
