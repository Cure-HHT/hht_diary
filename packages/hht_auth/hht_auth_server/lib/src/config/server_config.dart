/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - Server configuration from environment
///
/// Server configuration loaded from environment variables.

class ServerConfig {
  final String host;
  final int port;
  final String jwtPrivateKey;
  final String jwtPublicKey;
  final String jwtIssuer;
  final String firestoreProjectId;
  final String firestoreApiKey;
  final int rateLimitMaxAttempts;
  final Duration rateLimitWindow;
  final Duration accountLockoutDuration;

  ServerConfig({
    required this.host,
    required this.port,
    required this.jwtPrivateKey,
    required this.jwtPublicKey,
    required this.jwtIssuer,
    required this.firestoreProjectId,
    required this.firestoreApiKey,
    this.rateLimitMaxAttempts = 5,
    this.rateLimitWindow = const Duration(minutes: 1),
    this.accountLockoutDuration = const Duration(minutes: 15),
  });

  /// Loads configuration from environment variables.
  ///
  /// For testing, you can pass a custom environment map.
  factory ServerConfig.fromEnv([Map<String, String>? envOverrides]) {
    String getEnv(String key, {String? defaultValue}) {
      // Check overrides first (for testing)
      if (envOverrides != null && envOverrides.containsKey(key)) {
        return envOverrides[key]!;
      }

      // Try compile-time environment
      const value = String.fromEnvironment('');
      if (value.isNotEmpty) {
        return value;
      }

      // Return default or throw
      if (defaultValue != null) {
        return defaultValue;
      }

      throw Exception(
        'Missing required environment variable: $key. '
        'Set via --dart-define=$key=value or platform-specific environment.',
      );
    }

    return ServerConfig(
      host: getEnv('HOST', defaultValue: '0.0.0.0'),
      port: int.parse(getEnv('PORT', defaultValue: '8080')),
      jwtPrivateKey: getEnv('JWT_PRIVATE_KEY', defaultValue: 'test-key'),
      jwtPublicKey: getEnv('JWT_PUBLIC_KEY', defaultValue: 'test-key'),
      jwtIssuer: getEnv('JWT_ISSUER', defaultValue: 'hht-auth-service'),
      firestoreProjectId: getEnv('FIRESTORE_PROJECT_ID', defaultValue: 'test-project'),
      firestoreApiKey: getEnv('FIRESTORE_API_KEY', defaultValue: 'test-api-key'),
      rateLimitMaxAttempts: int.parse(
        getEnv('RATE_LIMIT_MAX_ATTEMPTS', defaultValue: '5'),
      ),
      rateLimitWindow: Duration(
        minutes: int.parse(
          getEnv('RATE_LIMIT_WINDOW_MINUTES', defaultValue: '1'),
        ),
      ),
      accountLockoutDuration: Duration(
        minutes: int.parse(
          getEnv('ACCOUNT_LOCKOUT_MINUTES', defaultValue: '15'),
        ),
      ),
    );
  }
}
