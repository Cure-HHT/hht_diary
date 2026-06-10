// The read-only study-configuration aggregate behind GET /config/study
// (the portal's Study Settings page). Reports ONLY parameters the system
// actually enforces, each resolved through the same code path its consumer
// uses — never a display-side copy that could drift:
//
//   - session idle/warning: resolveSessionConfig (portal_settings + env)
//   - 2FA code expiry + rate limits: the live OtpStore's effective fields
//   - password-reset TTL + rate limit: the live PasswordResetCodeStore
//   - linking-code TTL: portal_actions' linkingCodeTtl (the value
//     ACT-PAT-001 stamps)
//   - diary entry rules: ClinicalRules.fromSettings over the
//     portal_settings rows — identical resolution to the diary client
//   - questionnaire session timing: constants drift-guarded against
//     trial_data_types/assets/data/questionnaires.json by test (the asset
//     is a clinically-validated artifact, not sponsor configuration)
//
// Parameters with no implementation (password expiry, diary app lock,
// reminder timing, linking-code rate limits) are deliberately ABSENT from
// the payload; the client renders those rows as "Not yet implemented".
//
// NOTE: study-settings visibility is a spec gap — no DIARY-* REQ yet
// covers this read surface (flagged per convention, CUR-1483).
import 'package:event_sourcing/event_sourcing.dart';
// Re-exports diary_shared_model (SettingPayload, ClinicalRules) alongside
// linkingCodeTtl.
import 'package:portal_actions/portal_actions.dart';

import 'otp_store.dart';
import 'password_reset_code_store.dart';
import 'session_config.dart';

/// Questionnaire session timing as authored in the validated questionnaire
/// asset (`trial_data_types/assets/data/questionnaires.json`, both NOSE HHT
/// and HHT-QoL). The server can't load Flutter assets, so the values are
/// mirrored here; `study_config_drift_test.dart` fails the build if the
/// asset ever changes without this mirror.
const int questionnaireSessionTimeoutMinutes = 30;
const int questionnaireTimeoutWarningMinutes = 5;

/// Builds the GET /config/study response body.
Future<Map<String, Object?>> studyConfigJson({
  required StorageBackend backend,
  required Map<String, String> env,
  required OtpStore otpStore,
  required PasswordResetCodeStore passwordResetStore,
}) async {
  final session = await resolveSessionConfig(backend, env);

  // Fold the sponsor-seeded portal_settings rows into the same
  // SettingPayload map the diary derives its rules from.
  final rows = await backend.findViewRows('portal_settings');
  final settings = <String, SettingPayload>{
    for (final r in rows)
      if (r['key'] is String)
        r['key'] as String: SettingPayload(
          key: r['key'] as String,
          value: r['value'],
          source: SettingSource.sponsor,
          locked: r['locked'] == true,
        ),
  };
  final rules = ClinicalRules.fromSettings(settings, trialStart: null);

  return <String, Object?>{
    'session_idle_minutes': session.idleMinutes,
    'session_warning_seconds': session.warningSeconds,
    'two_factor_code_expiry_minutes': otpStore.ttl.inMinutes,
    'two_factor_issue_max_per_window': otpStore.maxIssuesPerWindow,
    'two_factor_issue_window_minutes': otpStore.issueWindow.inMinutes,
    'two_factor_max_attempts': otpStore.maxAttempts,
    'password_reset_ttl_hours': passwordResetStore.ttl.inHours,
    'password_reset_issue_max_per_window':
        passwordResetStore.maxIssuesPerWindow,
    'password_reset_issue_window_minutes':
        passwordResetStore.issueWindow.inMinutes,
    'linking_code_expiry_hours': linkingCodeTtl.inHours,
    // Entry-gate thresholds report null when unseeded (= no restriction),
    // mirroring EntryGateRules' permissive default.
    'justification_threshold_hours': rules.gate.justificationThreshold?.inHours,
    'lock_threshold_hours': rules.gate.lockThreshold?.inHours,
    'short_duration_confirm': rules.shortDurationConfirm,
    'long_duration_confirm': rules.longDurationConfirm,
    'long_duration_threshold_minutes': rules.longDurationThresholdMinutes,
    'questionnaire_session_timeout_minutes': questionnaireSessionTimeoutMinutes,
    'questionnaire_timeout_warning_minutes': questionnaireTimeoutWarningMinutes,
  };
}
