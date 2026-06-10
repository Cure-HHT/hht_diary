// buildStudySettingsSections keeps the Figma's full layout while staying
// honest: server-reported parameters render their effective values,
// unimplemented rows render the standard placeholder, and an unknown /
// older server payload degrades gracefully instead of throwing.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';
import 'package:portal_ui_evs/src/study_settings_format.dart';

const _fullPayload = <String, Object?>{
  'session_idle_minutes': 10,
  'session_warning_seconds': 60,
  'two_factor_code_expiry_minutes': 10,
  'two_factor_issue_max_per_window': 3,
  'two_factor_issue_window_minutes': 15,
  'two_factor_max_attempts': 5,
  'password_reset_ttl_hours': 24,
  'password_reset_issue_max_per_window': 3,
  'password_reset_issue_window_minutes': 15,
  'linking_code_expiry_hours': 72,
  'justification_threshold_hours': null,
  'lock_threshold_hours': 48,
  'short_duration_confirm': false,
  'long_duration_confirm': false,
  'long_duration_threshold_minutes': 240,
  'questionnaire_session_timeout_minutes': 30,
  'questionnaire_timeout_warning_minutes': 5,
};

StudySettingRowView _row(
  List<StudySettingsSectionView> sections,
  String label,
) => sections
    .expand((s) => s.rows)
    .firstWhere((r) => r.label == label, orElse: () => throw StateError(label));

void main() {
  test('renders all six Figma sections in order', () {
    final sections = buildStudySettingsSections(jsonEncode(_fullPayload));
    expect(sections.map((s) => s.title), [
      'Authentication and Sessions',
      'Mobile Application Security',
      'Diary Entry Rules',
      'Questionnaire Sessions',
      'Notifications and Reminders',
      'Rate Limiting',
    ]);
  });

  test('real parameters render their effective values', () {
    final sections = buildStudySettingsSections(jsonEncode(_fullPayload));
    expect(
      _row(sections, 'Sponsor Portal Session Idle Timeout').value,
      '10 minutes',
    );
    expect(
      _row(sections, 'Two-Factor Authentication Code Expiry').value,
      '10 minutes',
    );
    expect(_row(sections, 'Mobile Linking Code Expiry').value, '72 hours');
    expect(_row(sections, 'Lock Threshold').value, '48 hours');
    expect(
      _row(sections, 'NOSE HHT and HHT-QoL Timeout Warning Threshold').value,
      '5 minutes before expiry',
    );
    expect(
      _row(sections, 'Two-Factor Code Request Limit').value,
      '3 per 15 minutes',
    );
    expect(_row(sections, 'Two-Factor Code Attempt Limit').value, '5 attempts');
    expect(_row(sections, 'Password Reset Link Expiry').value, '24 hours');
  });

  test('honest states: unseeded threshold and disabled confirmations are '
      'real values, not placeholders', () {
    final sections = buildStudySettingsSections(jsonEncode(_fullPayload));
    final justification = _row(sections, 'Justification Threshold');
    expect(justification.value, 'Not set (no restriction)');
    expect(justification.implemented, isTrue);
    expect(_row(sections, 'Short Duration Confirmation').value, 'Disabled');
    expect(
      _row(sections, 'Long Duration Confirmation').value,
      'Disabled (threshold 240 minutes)',
    );
  });

  test('enabled confirmations surface their thresholds', () {
    final payload = <String, Object?>{
      ..._fullPayload,
      'short_duration_confirm': true,
      'long_duration_confirm': true,
      'long_duration_threshold_minutes': 60,
    };
    final sections = buildStudySettingsSections(jsonEncode(payload));
    expect(
      _row(sections, 'Short Duration Confirmation').value,
      'Enabled (1 minute)',
    );
    expect(
      _row(sections, 'Long Duration Confirmation').value,
      'Enabled (60 minutes)',
    );
  });

  test('unimplemented rows carry the placeholder with implemented=false', () {
    final sections = buildStudySettingsSections(jsonEncode(_fullPayload));
    for (final label in [
      'Password Expiry Interval',
      'Application Lock Idle Timeout',
      'Application Lock PIN Length',
      'Application Lock Failed Attempt Threshold',
      'Incomplete Record Lock Warning Offset',
      'Yesterday Entry Reminder Time',
      'Ongoing Epistaxis Event Reminder Interval',
      'Login Rate Limit Threshold',
      'Login Rate Limit Cooldown',
      'Linking Code Rate Limit Threshold',
      'Linking Code Rate Limit Cooldown',
    ]) {
      final row = _row(sections, label);
      expect(row.value, 'Not yet implemented', reason: label);
      expect(row.implemented, isFalse, reason: label);
    }
  });

  test('an empty/older payload degrades to placeholders, never throws', () {
    final sections = buildStudySettingsSections('{}');
    expect(sections, hasLength(6));
    expect(
      _row(sections, 'Sponsor Portal Session Idle Timeout').value,
      'Not yet implemented',
    );
  });
}
