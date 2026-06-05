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
