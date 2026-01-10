/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

/// Configuration constants for JWT tokens.
class TokenConfig {
  TokenConfig._();

  /// Token expiry duration for web (15 minutes)
  static const Duration webTokenExpiry = Duration(minutes: 15);

  /// Token expiry duration for mobile (7 days)
  static const Duration mobileTokenExpiry = Duration(days: 7);

  /// Refresh token window (can refresh within last 5 minutes of expiry)
  static const Duration refreshWindow = Duration(minutes: 5);

  /// Default session timeout for web (2 minutes)
  static const Duration defaultSessionTimeout = Duration(minutes: 2);

  /// Session warning threshold (30 seconds before timeout)
  static const Duration sessionWarningThreshold = Duration(seconds: 30);

  /// Minimum session timeout allowed
  static const Duration minSessionTimeout = Duration(minutes: 1);

  /// Maximum session timeout allowed
  static const Duration maxSessionTimeout = Duration(minutes: 30);

  /// Failed login attempt lockout threshold
  static const int maxFailedAttempts = 5;

  /// Account lockout duration after max failed attempts
  static const Duration lockoutDuration = Duration(minutes: 15);

  /// Rate limit for login attempts (per minute)
  static const int loginRateLimitPerMinute = 5;
}
