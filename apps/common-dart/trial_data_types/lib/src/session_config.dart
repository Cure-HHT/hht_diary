/// Session configuration for a questionnaire.
///
/// Controls the readiness gate and session timeout behavior.
// Implements: DIARY-PRD-questionnaire-session-timeout/I — optional session-timeout configuration
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

  /// Whether to show the readiness check screen
  // Implements: DIARY-PRD-questionnaire-portal-sent-rules/D — confirm readiness before proceeding
  final bool readinessCheck;

  /// Message shown on the readiness screen
  // Implements: DIARY-PRD-questionnaire-portal-sent-rules/B — inform estimated time to complete
  final String readinessMessage;

  /// Estimated completion time (e.g., "10-12")
  // Implements: DIARY-PRD-questionnaire-portal-sent-rules/B — estimated time to complete
  final String estimatedMinutes;

  /// Session timeout in minutes
  // Implements: DIARY-PRD-questionnaire-session-timeout/I — configurable timeout duration
  final int sessionTimeoutMinutes;

  /// Warning before timeout in minutes
  // Implements: DIARY-PRD-questionnaire-session-timeout/J — configurable warning threshold
  final int? timeoutWarningMinutes;
}
