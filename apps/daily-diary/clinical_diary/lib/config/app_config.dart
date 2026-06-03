import 'package:clinical_diary/config/env_profile.dart';
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
/// Configuration is derived from the runtime [EnvProfile], resolved once
/// during app bootstrap via [EnvProfile.load] from the bundled
/// `assets/config/env.json` pointer asset.
///
/// The asset is committed as `{ "env": "dev" }` by default. Non-dev builds
/// stamp it at packaging time via `tool/_write_env_pointer.sh` (CUR-1391
/// wires this into the qa/uat/prod build scripts).
///
/// All environment-dependent configuration (apiBase, showDevTools,
/// showBanner, showResetData) is derived from [EnvProfile.current].
class AppConfig {
  // Private constructor - this is a static utility class
  AppConfig._();

  // ============================================================
  // Environment Configuration (from EnvProfile)
  // ============================================================

  /// Current environment - delegates to the active EnvProfile.
  static AppEnv get environment => EnvProfile.current.env;

  /// Whether to show the environment banner (DEV/TEST ribbon)
  static bool get showBanner => EnvProfile.current.showBanner;

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
  /// Pass via: --dart-define=DIARY_API_BASE=http://10.0.2.2:8081
  /// Used by `local-stack diary` (sponsor repo) and run_local.sh to
  /// point the app at a local diary-server. BACKEND_URL is the legacy
  /// name; honored when DIARY_API_BASE is unset.
  static const String _diaryApiBaseOverride = String.fromEnvironment(
    'DIARY_API_BASE',
  );
  static const String _backendUrlOverride = String.fromEnvironment(
    'BACKEND_URL',
  );

  /// Test-only override for API base URL.
  /// Set this in test setUp() to override the profile-based apiBase.
  @visibleForTesting
  static String? testApiBaseOverride;

  /// API base URL - derived from the active EnvProfile.
  /// Points to the diary-server Cloud Run service.
  /// Can be overridden at compile time via DIARY_API_BASE (preferred)
  /// or BACKEND_URL dart-define, or at test time via testApiBaseOverride.
  // Implements: DIARY-DEV-runtime-environment-resolution/C
  static String get apiBase {
    if (testApiBaseOverride != null) {
      return testApiBaseOverride!;
    }
    if (_diaryApiBaseOverride.isNotEmpty) {
      return _diaryApiBaseOverride;
    }
    if (_backendUrlOverride.isNotEmpty) {
      return _backendUrlOverride;
    }
    return EnvProfile.current.apiBase;
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

  /// Whether to show the developer-tools menu section (Export/Import,
  /// Feature Flags, Add Example Data). Determined by EnvProfile — shown in
  /// local/dev/qa, hidden in uat/prod. Reset All Data is gated separately
  /// via `showResetData`.
  static bool get showDevTools => EnvProfile.current.showDevTools;

  /// Whether to show the Reset All Data feature.
  /// Determined by EnvProfile - only enabled in dev, qa, uat, and local.
  static bool get showResetData => EnvProfile.current.showResetData;
}
