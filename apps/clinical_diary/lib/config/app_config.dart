// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

/// Application environment enum.
/// Determined at compile time via --dart-define=ENVIRONMENT=xxx
enum AppEnvironment {
  /// Development environment - full dev tools, local/dev API
  dev,

  /// Test environment - for automated testing
  test,

  /// User Acceptance Testing - mirrors prod visually, test API
  uat,

  /// Production environment - no dev tools, production API
  prod;

  /// Parse environment from string (case-insensitive)
  static AppEnvironment fromString(String? value) {
    if (value == null) return AppEnvironment.dev;
    return AppEnvironment.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppEnvironment.dev,
    );
  }

  /// Whether this environment should show developer tools
  /// (Reset All Data, Add Example Data menus)
  bool get showDevTools => this == dev || this == test;

  /// Whether this is a production-like environment (prod or uat)
  bool get isProductionLike => this == prod || this == uat;

  /// Display name for the environment
  String get displayName => switch (this) {
    dev => 'Development',
    test => 'Test',
    uat => 'UAT',
    prod => 'Production',
  };
}

/// Application configuration.
/// All environment-specific values are determined at compile time
/// via --dart-define flags.
class AppConfig {
  /// Current environment - set via --dart-define=ENVIRONMENT=xxx
  static const String _envString = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  /// Parsed environment enum
  static final AppEnvironment environment = AppEnvironment.fromString(
    _envString,
  );

  /// API base URL - uses Firebase Hosting rewrites to proxy to functions
  /// This avoids CORS issues and org policy restrictions on direct function access
  /// Set via --dart-define=API_BASE=xxx or defaults based on environment
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE');
  static String get _apiBase {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    return switch (environment) {
      AppEnvironment.dev => 'https://hht-diary-mvp.web.app/api',
      AppEnvironment.test => 'https://hht-diary-mvp.web.app/api',
      AppEnvironment.uat => 'https://hht-diary-mvp.web.app/api',
      AppEnvironment.prod => 'https://hht-diary-mvp.web.app/api',
    };
  }

  static String get enrollUrl => '$_apiBase/enroll';
  static String get healthUrl => '$_apiBase/health';
  static String get syncUrl => '$_apiBase/sync';
  static String get getRecordsUrl => '$_apiBase/getRecords';
  static String get registerUrl => '$_apiBase/register';
  static String get loginUrl => '$_apiBase/login';
  static String get changePasswordUrl => '$_apiBase/changePassword';

  /// App name displayed in UI
  static const String appName = 'Nosebleed Diary';

  /// Whether we're in debug mode (legacy - prefer environment checks)
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false,
  );

  /// Convenience getter for showing dev tools
  static bool get showDevTools => environment.showDevTools;
}
