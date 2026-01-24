// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Flavor configuration for sponsor portal
// Supports local development with emulator and deployed environments
// with runtime configuration from server

import 'services/identity_config_service.dart';

/// Available flavors for the portal
enum Flavor {
  local, // Local development with Firebase emulator
  dev, // Development environment
  qa, // QA/Testing environment
  uat, // User Acceptance Testing
  prod, // Production
}

/// Flavor accessor class - provides current flavor configuration
class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? 'unknown';

  static String get title {
    switch (appFlavor) {
      case Flavor.local:
        return 'Portal LOCAL';
      case Flavor.dev:
        return 'Portal DEV';
      case Flavor.qa:
        return 'Portal QA';
      case Flavor.uat:
        return 'Portal UAT';
      case Flavor.prod:
        return 'Clinical Trial Portal';
      default:
        return 'Portal';
    }
  }

  /// Whether to show development tools (role switcher, debug info, etc.)
  static bool get showDevTools {
    switch (appFlavor) {
      case Flavor.local:
      case Flavor.dev:
      case Flavor.qa:
        return true;
      case Flavor.uat:
      case Flavor.prod:
      default:
        return false;
    }
  }

  /// Whether to show environment banner
  static bool get showBanner {
    switch (appFlavor) {
      case Flavor.local:
      case Flavor.dev:
      case Flavor.qa:
        return true;
      case Flavor.uat:
      case Flavor.prod:
      default:
        return false;
    }
  }

  /// Whether to use Firebase emulator
  static bool get useEmulator => appFlavor == Flavor.local;
}

/// Configuration values for Identity Platform / Firebase Auth
///
/// For local flavor: Uses hardcoded emulator values (sync initialization)
/// For deployed flavors: Fetched from server at runtime (async initialization)
class FlavorValues {
  final String apiBaseUrl;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseProjectId;
  final String firebaseAuthDomain;
  final String firebaseMessagingSenderId;

  const FlavorValues({
    required this.apiBaseUrl,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseProjectId,
    required this.firebaseAuthDomain,
    required this.firebaseMessagingSenderId,
  });

  /// Create FlavorValues from IdentityPlatformConfig
  factory FlavorValues.fromIdentityConfig(
    IdentityPlatformConfig config, {
    required String apiBaseUrl,
  }) {
    return FlavorValues(
      apiBaseUrl: apiBaseUrl,
      firebaseApiKey: config.apiKey,
      firebaseAppId: config.appId,
      firebaseProjectId: config.projectId,
      firebaseAuthDomain: config.authDomain,
      firebaseMessagingSenderId: config.messagingSenderId,
    );
  }

  /// Check if Firebase is properly configured
  bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseApiKey != 'REQUIRED' &&
      firebaseAppId.isNotEmpty &&
      firebaseAppId != 'REQUIRED';
}

/// Flavor configuration - holds values for current flavor
///
/// Usage patterns:
/// - Local development: Call `initializeLocal()` (sync, uses emulator)
/// - Deployed environments: Call `initializeWithConfig()` after fetching
///   config from server
class FlavorConfig {
  static FlavorValues? _values;

  static FlavorValues get values {
    if (_values == null) {
      throw StateError(
        'FlavorConfig not initialized. '
        'Call FlavorConfig.initializeLocal() or FlavorConfig.initializeWithConfig() first.',
      );
    }
    return _values!;
  }

  /// Check if FlavorConfig has been initialized
  static bool get isInitialized => _values != null;

  /// Initialize for local development (sync, uses emulator)
  ///
  /// Uses hardcoded emulator-compatible values. The emulator doesn't
  /// validate these, so placeholder values work fine.
  static void initializeLocal() {
    F.appFlavor = Flavor.local;
    _values = const FlavorValues(
      apiBaseUrl: 'http://localhost:8080',
      // Emulator doesn't validate these, so placeholders are fine
      firebaseApiKey: 'demo-api-key',
      firebaseAppId: '1:000000000000:web:0000000000000000000000',
      firebaseProjectId: 'demo-sponsor-portal',
      firebaseAuthDomain: 'demo-sponsor-portal.firebaseapp.com',
      firebaseMessagingSenderId: '000000000000',
    );
  }

  /// Initialize with runtime config from server
  ///
  /// Call this after fetching [IdentityPlatformConfig] from the server.
  /// The [apiBaseUrl] is typically the current origin for same-origin API.
  static void initializeWithConfig(
    Flavor flavor,
    IdentityPlatformConfig config, {
    required String apiBaseUrl,
  }) {
    F.appFlavor = flavor;
    _values = FlavorValues.fromIdentityConfig(config, apiBaseUrl: apiBaseUrl);
  }

  /// Initialize with emulator fallback (for debug mode failures)
  ///
  /// Use this when config fetch fails in debug mode. Shows a warning
  /// but allows development to continue with emulator.
  static void initializeWithEmulatorFallback(Flavor flavor) {
    F.appFlavor = flavor;
    _values = const FlavorValues(
      apiBaseUrl: 'http://localhost:8080',
      firebaseApiKey: 'demo-api-key',
      firebaseAppId: '1:000000000000:web:0000000000000000000000',
      firebaseProjectId: 'demo-sponsor-portal',
      firebaseAuthDomain: 'demo-sponsor-portal.firebaseapp.com',
      firebaseMessagingSenderId: '000000000000',
    );
  }

  /// Validate that required Firebase config is present
  /// Throws if configuration is missing for non-local flavors
  static void validateConfig() {
    if (F.appFlavor == Flavor.local) {
      // Local flavor uses emulator, no validation needed
      return;
    }

    if (!values.isFirebaseConfigured) {
      throw StateError(
        'Firebase configuration missing for ${F.name} flavor.\n'
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

/// Parse flavor from string (case-insensitive)
Flavor? flavorFromString(String? name) {
  if (name == null || name.isEmpty) return null;

  final normalized = name.toLowerCase().trim();
  for (final flavor in Flavor.values) {
    if (flavor.name == normalized) return flavor;
  }
  return null;
}
