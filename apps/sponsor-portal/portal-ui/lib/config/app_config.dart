// lib/config/app_config.dart
//
// Process-wide application configuration set once during bootstrap. Holds the
// runtime Firebase / Identity Platform credentials, the build version, and the
// local-emulator flag. Environment-derived presentation (title, banner, dev
// tools) lives in EnvProfile; this file resolves the environment from the
// server's same-origin runtime config and stores it there.

import '../services/identity_config_service.dart';
import 'env_profile.dart';

/// Runtime Firebase / Identity Platform credentials.
///
/// For deployed environments these are fetched from the server at runtime
/// ([RuntimeConfig.fromIdentityConfig]); for local development they are the
/// emulator placeholders set by [AppConfig.initializeLocal].
class RuntimeConfig {
  final String apiBaseUrl;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseProjectId;
  final String firebaseAuthDomain;
  final String firebaseMessagingSenderId;

  const RuntimeConfig({
    required this.apiBaseUrl,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseProjectId,
    required this.firebaseAuthDomain,
    required this.firebaseMessagingSenderId,
  });

  /// Create from the [IdentityPlatformConfig] fetched from the server.
  factory RuntimeConfig.fromIdentityConfig(
    IdentityPlatformConfig config, {
    required String apiBaseUrl,
  }) {
    return RuntimeConfig(
      apiBaseUrl: apiBaseUrl,
      firebaseApiKey: config.apiKey,
      firebaseAppId: config.appId,
      firebaseProjectId: config.projectId,
      firebaseAuthDomain: config.authDomain,
      firebaseMessagingSenderId: config.messagingSenderId,
    );
  }

  /// Check if Firebase is properly configured.
  bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseApiKey != 'REQUIRED' &&
      firebaseAppId.isNotEmpty &&
      firebaseAppId != 'REQUIRED';
}

/// Application configuration resolved once during bootstrap.
///
/// Usage patterns:
/// - Local development (emulator): call [initializeLocal] (sync).
/// - Deployed environments: call [initializeFromServer] after fetching config.
class AppConfig {
  /// App version - injected at build time from pubspec.yaml via --dart-define.
  /// Orthogonal to the deployment environment.
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  /// True only on a local-stack build wired to the Firebase emulator, detected
  /// by the emulator-host build input. This is a local-development concern, not
  /// an environment flavor: every *deployed* bundle sets no emulator host and
  /// is therefore identical and environment-independent.
  // Implements: DIARY-OPS-single-promotable-artifact/B
  static bool get useEmulator =>
      const String.fromEnvironment('FIREBASE_AUTH_EMULATOR_HOST').isNotEmpty;

  static RuntimeConfig? _values;

  static RuntimeConfig get values {
    if (_values == null) {
      throw StateError(
        'AppConfig not initialized. '
        'Call AppConfig.initializeLocal() or AppConfig.initializeFromServer() first.',
      );
    }
    return _values!;
  }

  /// Check if AppConfig has been initialized.
  static bool get isInitialized => _values != null;

  /// Initialize for local development (sync, uses the Firebase emulator).
  ///
  /// Uses hardcoded emulator-compatible values. The emulator doesn't validate
  /// these, so placeholder values work fine.
  static void initializeLocal() {
    EnvProfile.current = EnvProfile.forEnv(AppEnv.local);
    _values = const RuntimeConfig(
      apiBaseUrl: 'http://localhost:8084',
      // Emulator doesn't validate these, so placeholders are fine.
      firebaseApiKey: 'demo-api-key',
      firebaseAppId: '1:000000000000:web:0000000000000000000000',
      // CUR-1263: must match the firebase emulator's startup --project flag
      // and the local-stack seed script's effective project id (composed as
      // ${--project}-${--env}). All three live in
      // hht_diary_callisto/deployment/local-stack/.
      firebaseProjectId: 'demo-local-stack',
      // CUR-1280: must NOT be a *.firebaseapp.com domain on local. The
      // Firebase JS SDK loads a GAPI iframe at the configured authDomain to
      // broker popup/redirect/MFA flows; that iframe calls
      // getProjectConfig?key=demo-api-key, which 400s with API_KEY_INVALID and
      // breaks any auth flow that touches the iframe path. The SDK skips the
      // iframe path entirely when authDomain is on a local origin.
      firebaseAuthDomain: 'localhost',
      firebaseMessagingSenderId: '000000000000',
    );
  }

  /// Initialize from the server-provided same-origin runtime config.
  ///
  /// Resolves the active environment from [IdentityPlatformConfig.environment]
  /// (an absent/unknown value resolves to dev) and stores the Firebase
  /// credentials. The [apiBaseUrl] is typically the current origin.
  // Implements: DIARY-DEV-runtime-environment-resolution/A+C
  static void initializeFromServer(
    IdentityPlatformConfig config, {
    required String apiBaseUrl,
  }) {
    EnvProfile.current = EnvProfile.fromServerName(config.environment);
    _values = RuntimeConfig.fromIdentityConfig(config, apiBaseUrl: apiBaseUrl);
  }

  /// Validate that required Firebase config is present.
  /// Throws if configuration is missing for a non-local environment.
  static void validateConfig() {
    if (EnvProfile.current.env == AppEnv.local) {
      // Local environment uses the emulator, no validation needed.
      return;
    }

    if (!values.isFirebaseConfigured) {
      throw StateError(
        'Firebase configuration missing for ${EnvProfile.current.name} environment.\n'
        'The server should provide configuration via /api/v1/portal/config/identity.\n'
        'Check that Doppler environment variables are set:\n'
        '  PORTAL_IDENTITY_API_KEY\n'
        '  PORTAL_IDENTITY_APP_ID\n'
        '  PORTAL_IDENTITY_PROJECT_ID\n'
        '  PORTAL_IDENTITY_AUTH_DOMAIN\n',
      );
    }
  }
}
