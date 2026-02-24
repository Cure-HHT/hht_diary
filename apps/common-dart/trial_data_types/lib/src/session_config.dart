// IMPLEMENTS REQUIREMENTS:
//   REQ-p01073: Session Management

/// Session configuration for a questionnaire.
///
/// Controls the readiness gate and session timeout behavior
/// per REQ-p01073.
class SessionConfig {
  const SessionConfig({
    required this.readinessCheck,
    required this.readinessMessage,
    required this.estimatedMinutes,
    required this.sessionTimeoutMinutes,
    this.timeoutWarningMinutes,
  });

  factory SessionConfig.fromJson(Map<String, dynamic> json) {
    return SessionConfig(
      readinessCheck: json['readinessCheck'] as bool? ?? true,
      readinessMessage: json['readinessMessage'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as String? ?? '',
      sessionTimeoutMinutes: json['sessionTimeoutMinutes'] as int? ?? 30,
      timeoutWarningMinutes: json['timeoutWarningMinutes'] as int?,
    );
  }

  /// Whether to show the readiness check screen (REQ-p01073-A)
  final bool readinessCheck;

  /// Message shown on the readiness screen (REQ-p01073-B)
  final String readinessMessage;

  /// Estimated completion time (e.g., "10-12")
  final String estimatedMinutes;

  /// Session timeout in minutes (REQ-p01073-E)
  final int sessionTimeoutMinutes;

  /// Warning before timeout in minutes
  final int? timeoutWarningMinutes;
}
