import 'package:event_sourcing/event_sourcing.dart';

/// Reads the event-sourced `require_second_factor` portal setting from the
/// `portal_settings` projection. Fail-safe: returns true (OTP required) when
/// the setting is absent or anything other than an explicit `false`.
// Implements: DIARY-DEV-portal-second-factor-toggle/B
Future<bool> requireSecondFactor(StorageBackend backend) async {
  final rows = await backend.findViewRows('portal_settings');
  for (final r in rows) {
    if (r['key'] == 'require_second_factor') {
      return r['value'] != false; // only an explicit false disables it
    }
  }
  return true;
}

/// Whether multi-cycle questionnaire tracking is enabled (default true).
/// Fail-safe: returns true when absent so questionnaires are tracked by default.
// Implements: DIARY-BASE-questionnaire-cycle-tracking/I
Future<bool> cycleTrackingEnabled(StorageBackend backend) async {
  final rows = await backend.findViewRows('portal_settings');
  for (final r in rows) {
    if (r['key'] == 'questionnaire.cycle_tracking_enabled') {
      return r['value'] != false;
    }
  }
  return true;
}

/// Whether the coordinator must pick the starting cycle on first send (default false).
// Implements: DIARY-BASE-questionnaire-cycle-tracking/J
Future<bool> requireInitialCycleSelection(StorageBackend backend) async {
  final rows = await backend.findViewRows('portal_settings');
  for (final r in rows) {
    if (r['key'] == 'questionnaire.require_initial_cycle_selection') {
      return r['value'] == true;
    }
  }
  return false;
}
