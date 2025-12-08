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
/// Configuration values are set at compile time via flutter_flavorizr.
/// Run with: flutter run --flavor dev -t lib/main_dev.dart
///
/// Required dart-define variables (set by flavorizr):
/// - apiBase: API endpoint URL (REQUIRED - throws if missing)
/// - environment: dev, test, uat, or prod
/// - showDevTools: true/false
/// - showBanner: true/false (shows DEV/TEST banner overlay)
class AppConfig {
  // Private constructor - this is a static utility class
  AppConfig._();

  /// Flag to track if config has been validated
  static bool _validated = false;

  /// Validate that all required configuration is present.
  /// Call this early in app startup (e.g., in main()).
  /// Throws [MissingConfigException] if required config is missing.
  static void validate() {
    if (_validated) return;

    if (_apiBaseRaw.isEmpty) {
      throw MissingConfigException(
        'apiBase',
        'API_BASE must be set via --dart-define=apiBase=<url> or flutter flavor. '
            'Run with: flutter run --flavor dev',
      );
    }

    _validated = true;
  }

  // ============================================================
  // Environment Configuration (from flavorizr via F class)
  // ============================================================

  /// Current flavor/environment - delegates to F class set by flavorizr
  static Flavor get environment => F.appFlavor;

  /// Whether to show the environment banner (DEV/TEST ribbon)
  static bool get showBanner => F.showBanner;

  // ============================================================
  // API Configuration
  // ============================================================

  /// Raw API base URL from dart-define (REQUIRED)
  static const String _apiBaseRaw = String.fromEnvironment('apiBase');

  /// QA API key from dart-define (only for dev/qa environments)
  static const String _qaApiKeyRaw = String.fromEnvironment(
    'CUREHHT_QA_API_KEY',
  );

  /// QA API key - returns empty string if not configured
  static String get qaApiKey => _qaApiKeyRaw;

  /// Test-only override for API base URL.
  /// Set this in test setUp() to avoid MissingConfigException.
  /// ignore: use_setters_to_change_properties
  @visibleForTesting
  static String? testApiBaseOverride;

  /// API base URL - throws if not configured
  /// Uses Firebase Hosting rewrites to proxy to functions,
  /// avoiding CORS issues and org policy restrictions.
  static String get apiBase {
    // Allow test override
    if (testApiBaseOverride != null) {
      return testApiBaseOverride!;
    }
    if (_apiBaseRaw.isEmpty) {
      throw MissingConfigException(
        'apiBase',
        'API_BASE is not configured. Run with a flavor: '
            'flutter run --flavor dev',
      );
    }
    return _apiBaseRaw;
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
  // Convenience Getters
  // ============================================================

  /// Whether to show dev tools menu items (Reset All Data, Add Example Data).
  /// Determined by flavor - only shown in dev and test environments.
  static bool get showDevTools => F.showDevTools;
}
