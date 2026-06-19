// Pure formatting from the GET /config/study payload to the Study
// Settings screen's section structure. Keeps the Figma's FULL layout
// (every section and row) while staying honest about reality:
//
//   - parameters the server reports render their EFFECTIVE values
//     (e.g. "240 minutes", "Not set (no restriction)" for unseeded
//     thresholds, "Disabled" for confirmation gates that are off);
//   - parameters with no implementation render "Not yet implemented"
//     (password expiry, the diary app-lock trio, reminder timing, and
//     the login / linking-code rate limits);
//   - the Rate Limiting section additionally lists the protections that
//     DO exist (2FA code issuance/attempt limits, password-reset limits)
//     so the section isn't all placeholders while real limits go unshown.
import 'dart:convert';

import 'package:portal_screens/portal_screens.dart';

const String _notImplemented = 'Not yet implemented';

StudySettingRowView _todo(String label) => StudySettingRowView(
  label: label,
  value: _notImplemented,
  implemented: false,
);

/// Parses the /config/study response body into the screen's sections.
/// Unknown/missing keys degrade to "Not yet implemented" rather than
/// throwing, so an older server still renders a usable page.
List<StudySettingsSectionView> buildStudySettingsSections(String responseBody) {
  final decoded = jsonDecode(responseBody);
  final c = decoded is Map<String, Object?> ? decoded : <String, Object?>{};

  int? intOf(String key) {
    final v = c[key];
    return v is int ? v : null;
  }

  bool boolOf(String key) => c[key] == true;

  // [variableName] is the parameter's true source identifier (settings
  // key, env var, or class.field) — surfaced to SystemOperator viewers as
  // a hover/copy developer affordance.
  StudySettingRowView row(String label, String? value, String variableName) =>
      value == null
      ? _todo(label)
      : StudySettingRowView(
          label: label,
          value: value,
          variableName: variableName,
        );

  String? minutes(String key) {
    final v = intOf(key);
    return v == null ? null : '$v minutes';
  }

  String? hours(String key) {
    final v = intOf(key);
    return v == null ? null : '$v hours';
  }

  // Entry-gate thresholds: the server reports null for "unseeded = no
  // restriction" — a real, effective state, distinct from unimplemented.
  String gateThreshold(String key) {
    final v = intOf(key);
    return v == null ? 'Not set (no restriction)' : '$v hours';
  }

  return <StudySettingsSectionView>[
    StudySettingsSectionView(
      title: 'Authentication and Sessions',
      description:
          'Controls login sessions, password expiration, and two-factor '
          'authentication timing.',
      rows: [
        row(
          'Sponsor Portal Session Idle Timeout',
          minutes('session_idle_minutes'),
          'session_idle_minutes',
        ),
        _todo('Password Expiry Interval'),
        row(
          'Two-Factor Authentication Code Expiry',
          minutes('two_factor_code_expiry_minutes'),
          'PORTAL_OTP_TTL_MINUTES',
        ),
      ],
    ),
    StudySettingsSectionView(
      title: 'Mobile Application Security',
      description:
          'Defines mobile access, linking, and app lock security rules.',
      rows: [
        row(
          'Mobile Linking Code Expiry',
          hours('linking_code_expiry_hours'),
          'linkingCodeTtl',
        ),
        _todo('Application Lock Idle Timeout'),
        _todo('Application Lock PIN Length'),
        _todo('Application Lock Failed Attempt Threshold'),
      ],
    ),
    StudySettingsSectionView(
      title: 'Diary Entry Rules',
      description:
          'Defines timing rules for diary entries and event duration '
          'thresholds.',
      rows: [
        StudySettingRowView(
          label: 'Justification Threshold',
          value: gateThreshold('justification_threshold_hours'),
          variableName: 'clinical.justificationThresholdHours',
        ),
        StudySettingRowView(
          label: 'Lock Threshold',
          value: gateThreshold('lock_threshold_hours'),
          variableName: 'clinical.lockThresholdHours',
        ),
        StudySettingRowView(
          label: 'Short Duration Confirmation',
          // The short-duration rule is a toggle over a fixed 1-minute
          // bound, not a tunable duration.
          value: boolOf('short_duration_confirm')
              ? 'Enabled (1 minute)'
              : 'Disabled',
          variableName: 'clinical.shortDurationConfirm',
        ),
        StudySettingRowView(
          label: 'Long Duration Confirmation',
          value: boolOf('long_duration_confirm')
              ? 'Enabled (${intOf('long_duration_threshold_minutes')} minutes)'
              : 'Disabled '
                    '(threshold ${intOf('long_duration_threshold_minutes')} '
                    'minutes)',
          variableName: 'clinical.longDurationThresholdMinutes',
        ),
      ],
    ),
    StudySettingsSectionView(
      title: 'Questionnaire Sessions',
      description: 'Controls questionnaire session timeout and warning timing.',
      rows: [
        row(
          'NOSE HHT and HHT-QoL Session Timeout',
          minutes('questionnaire_session_timeout_minutes'),
          'sessionTimeoutMinutes',
        ),
        row(
          'NOSE HHT and HHT-QoL Timeout Warning Threshold',
          intOf('questionnaire_timeout_warning_minutes') == null
              ? null
              : '${intOf('questionnaire_timeout_warning_minutes')} minutes '
                    'before expiry',
          'timeoutWarningMinutes',
        ),
      ],
    ),
    const StudySettingsSectionView(
      title: 'Notifications and Reminders',
      description:
          'Defines reminder timing for incomplete records, yesterday '
          'entries, and ongoing epistaxis events.',
      rows: [
        StudySettingRowView(
          label: 'Incomplete Record Lock Warning Offset',
          value: _notImplemented,
          implemented: false,
        ),
        StudySettingRowView(
          label: 'Yesterday Entry Reminder Time',
          value: _notImplemented,
          implemented: false,
        ),
        StudySettingRowView(
          label: 'Ongoing Epistaxis Event Reminder Interval',
          value: _notImplemented,
          implemented: false,
        ),
      ],
    ),
    StudySettingsSectionView(
      title: 'Rate Limiting',
      description: 'Controls login and linking code attempt limits.',
      rows: [
        _todo('Login Rate Limit Threshold'),
        _todo('Login Rate Limit Cooldown'),
        _todo('Linking Code Rate Limit Threshold'),
        _todo('Linking Code Rate Limit Cooldown'),
        row(
          'Two-Factor Code Request Limit',
          intOf('two_factor_issue_max_per_window') == null
              ? null
              : '${intOf('two_factor_issue_max_per_window')} per '
                    '${intOf('two_factor_issue_window_minutes')} minutes',
          'OtpStore.maxIssuesPerWindow',
        ),
        row(
          'Two-Factor Code Attempt Limit',
          intOf('two_factor_max_attempts') == null
              ? null
              : '${intOf('two_factor_max_attempts')} attempts',
          'OtpStore.maxAttempts',
        ),
        row(
          'Password Reset Request Limit',
          intOf('password_reset_issue_max_per_window') == null
              ? null
              : '${intOf('password_reset_issue_max_per_window')} per '
                    '${intOf('password_reset_issue_window_minutes')} minutes',
          'PasswordResetCodeStore.maxIssuesPerWindow',
        ),
        row(
          'Password Reset Link Expiry',
          hours('password_reset_ttl_hours'),
          'PasswordResetCodeStore.ttl',
        ),
      ],
    ),
  ];
}
