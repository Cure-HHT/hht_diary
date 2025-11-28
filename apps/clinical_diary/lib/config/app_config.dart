// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

/// Application configuration
class AppConfig {
  /// API base URL - uses Firebase Hosting rewrites to proxy to functions
  /// This avoids CORS issues and org policy restrictions on direct function access
  static const String _apiBase = 'https://hht-diary-mvp.web.app/api';

  static const String enrollUrl = '$_apiBase/enroll';
  static const String healthUrl = '$_apiBase/health';
  static const String syncUrl = '$_apiBase/sync';
  static const String getRecordsUrl = '$_apiBase/getRecords';

  /// App name displayed in UI
  static const String appName = 'Nosebleed Diary';

  /// Whether we're in debug mode
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: false,
  );
}
