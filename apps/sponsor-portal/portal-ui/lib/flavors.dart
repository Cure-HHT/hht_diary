// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//
// Flavor configuration for sponsor portal
// Supports local development with emulator and deployed environments

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

/// Configuration values for each flavor
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

  /// Check if Firebase is properly configured
  bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseApiKey != 'REQUIRED' &&
      firebaseAppId.isNotEmpty &&
      firebaseAppId != 'REQUIRED';
}

// Compile-time environment variables for each flavor
// These must be const because String.fromEnvironment requires compile-time keys

// DEV environment variables
const _devApiUrl = String.fromEnvironment(
  'PORTAL_DEV_API_URL',
  defaultValue: 'https://portal-dev.example.com',
);
const _devFirebaseApiKey = String.fromEnvironment(
  'PORTAL_DEV_FIREBASE_API_KEY',
  defaultValue: 'REQUIRED',
);
const _devFirebaseAppId = String.fromEnvironment(
  'PORTAL_DEV_FIREBASE_APP_ID',
  defaultValue: 'REQUIRED',
);
const _devFirebaseProjectId = String.fromEnvironment(
  'PORTAL_DEV_FIREBASE_PROJECT_ID',
  defaultValue: 'REQUIRED',
);
const _devFirebaseAuthDomain = String.fromEnvironment(
  'PORTAL_DEV_FIREBASE_AUTH_DOMAIN',
  defaultValue: 'REQUIRED',
);
const _devFirebaseMessagingSenderId = String.fromEnvironment(
  'PORTAL_DEV_FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

// QA environment variables
const _qaApiUrl = String.fromEnvironment(
  'PORTAL_QA_API_URL',
  defaultValue: 'https://portal-qa.example.com',
);
const _qaFirebaseApiKey = String.fromEnvironment(
  'PORTAL_QA_FIREBASE_API_KEY',
  defaultValue: 'REQUIRED',
);
const _qaFirebaseAppId = String.fromEnvironment(
  'PORTAL_QA_FIREBASE_APP_ID',
  defaultValue: 'REQUIRED',
);
const _qaFirebaseProjectId = String.fromEnvironment(
  'PORTAL_QA_FIREBASE_PROJECT_ID',
  defaultValue: 'REQUIRED',
);
const _qaFirebaseAuthDomain = String.fromEnvironment(
  'PORTAL_QA_FIREBASE_AUTH_DOMAIN',
  defaultValue: 'REQUIRED',
);
const _qaFirebaseMessagingSenderId = String.fromEnvironment(
  'PORTAL_QA_FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

// UAT environment variables
const _uatApiUrl = String.fromEnvironment(
  'PORTAL_UAT_API_URL',
  defaultValue: 'https://portal-uat.example.com',
);
const _uatFirebaseApiKey = String.fromEnvironment(
  'PORTAL_UAT_FIREBASE_API_KEY',
  defaultValue: 'REQUIRED',
);
const _uatFirebaseAppId = String.fromEnvironment(
  'PORTAL_UAT_FIREBASE_APP_ID',
  defaultValue: 'REQUIRED',
);
const _uatFirebaseProjectId = String.fromEnvironment(
  'PORTAL_UAT_FIREBASE_PROJECT_ID',
  defaultValue: 'REQUIRED',
);
const _uatFirebaseAuthDomain = String.fromEnvironment(
  'PORTAL_UAT_FIREBASE_AUTH_DOMAIN',
  defaultValue: 'REQUIRED',
);
const _uatFirebaseMessagingSenderId = String.fromEnvironment(
  'PORTAL_UAT_FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

// PROD environment variables
const _prodApiUrl = String.fromEnvironment(
  'PORTAL_PROD_API_URL',
  defaultValue: '',
);
const _prodFirebaseApiKey = String.fromEnvironment(
  'PORTAL_PROD_FIREBASE_API_KEY',
  defaultValue: 'REQUIRED',
);
const _prodFirebaseAppId = String.fromEnvironment(
  'PORTAL_PROD_FIREBASE_APP_ID',
  defaultValue: 'REQUIRED',
);
const _prodFirebaseProjectId = String.fromEnvironment(
  'PORTAL_PROD_FIREBASE_PROJECT_ID',
  defaultValue: 'REQUIRED',
);
const _prodFirebaseAuthDomain = String.fromEnvironment(
  'PORTAL_PROD_FIREBASE_AUTH_DOMAIN',
  defaultValue: 'REQUIRED',
);
const _prodFirebaseMessagingSenderId = String.fromEnvironment(
  'PORTAL_PROD_FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

/// Flavor configuration - holds values for all flavors
class FlavorConfig {
  static FlavorValues? _values;

  static FlavorValues get values {
    if (_values == null) {
      throw StateError(
        'FlavorConfig not initialized. Call FlavorConfig.initialize() first.',
      );
    }
    return _values!;
  }

  /// Initialize flavor configuration from environment
  ///
  /// For local flavor, uses emulator with placeholder values.
  /// For other flavors, requires real Firebase credentials via --dart-define.
  static void initialize(Flavor flavor) {
    F.appFlavor = flavor;

    switch (flavor) {
      case Flavor.local:
        _values = const FlavorValues(
          apiBaseUrl: 'http://localhost:8080',
          // Emulator doesn't validate these, so placeholders are fine
          firebaseApiKey: 'demo-api-key',
          firebaseAppId: '1:000000000000:web:0000000000000000000000',
          firebaseProjectId: 'demo-sponsor-portal',
          firebaseAuthDomain: 'demo-sponsor-portal.firebaseapp.com',
          firebaseMessagingSenderId: '000000000000',
        );
        break;

      case Flavor.dev:
        _values = const FlavorValues(
          apiBaseUrl: _devApiUrl,
          firebaseApiKey: _devFirebaseApiKey,
          firebaseAppId: _devFirebaseAppId,
          firebaseProjectId: _devFirebaseProjectId,
          firebaseAuthDomain: _devFirebaseAuthDomain,
          firebaseMessagingSenderId: _devFirebaseMessagingSenderId,
        );
        break;

      case Flavor.qa:
        _values = const FlavorValues(
          apiBaseUrl: _qaApiUrl,
          firebaseApiKey: _qaFirebaseApiKey,
          firebaseAppId: _qaFirebaseAppId,
          firebaseProjectId: _qaFirebaseProjectId,
          firebaseAuthDomain: _qaFirebaseAuthDomain,
          firebaseMessagingSenderId: _qaFirebaseMessagingSenderId,
        );
        break;

      case Flavor.uat:
        _values = const FlavorValues(
          apiBaseUrl: _uatApiUrl,
          firebaseApiKey: _uatFirebaseApiKey,
          firebaseAppId: _uatFirebaseAppId,
          firebaseProjectId: _uatFirebaseProjectId,
          firebaseAuthDomain: _uatFirebaseAuthDomain,
          firebaseMessagingSenderId: _uatFirebaseMessagingSenderId,
        );
        break;

      case Flavor.prod:
        _values = const FlavorValues(
          apiBaseUrl: _prodApiUrl,
          firebaseApiKey: _prodFirebaseApiKey,
          firebaseAppId: _prodFirebaseAppId,
          firebaseProjectId: _prodFirebaseProjectId,
          firebaseAuthDomain: _prodFirebaseAuthDomain,
          firebaseMessagingSenderId: _prodFirebaseMessagingSenderId,
        );
        break;
    }
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
        'Required --dart-define variables:\n'
        '  --dart-define=PORTAL_${F.name.toUpperCase()}_FIREBASE_API_KEY=your-api-key\n'
        '  --dart-define=PORTAL_${F.name.toUpperCase()}_FIREBASE_APP_ID=your-app-id\n'
        '  --dart-define=PORTAL_${F.name.toUpperCase()}_FIREBASE_PROJECT_ID=your-project-id\n'
        '  --dart-define=PORTAL_${F.name.toUpperCase()}_FIREBASE_AUTH_DOMAIN=your-auth-domain\n'
        '\n'
        'Get these values from Firebase Console > Project Settings > Your apps > Web app',
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
