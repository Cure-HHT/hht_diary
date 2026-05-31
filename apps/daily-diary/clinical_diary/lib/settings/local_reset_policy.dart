// Implements: DIARY-PRD-local-data-reset/B+C — whether the participant may wipe
//   all local data right now. A HARD safeguard forbids it while participating in
//   a trial (regardless of any setting); a sponsor-controllable, lockable
//   `allow_local_reset` setting layers on top.
import 'package:diary_shared_model/diary_shared_model.dart';

/// Settings key gating the local "reset all data" capability. Sponsor-settable
/// and lockable (same lock model as the other sponsor settings); default
/// **true** (enabled) when absent.
const String kAllowLocalResetKey = 'allow_local_reset';

/// The `allow_local_reset` setting value, defaulting to `true` when the key is
/// absent or not a bool.
bool allowLocalResetSetting(Map<String, SettingPayload> settings) {
  final value = settings[kAllowLocalResetKey]?.value;
  // Default true: a non-bool/absent value enables reset.
  return value is! bool || value;
}

/// Whether local reset is permitted right now.
///
/// HARD safeguard: never while [participating] in a trial — a participant must
/// end participation before wiping their device — regardless of the setting.
/// Layered with the sponsor-controllable [settingAllowsReset].
bool canResetLocalData({
  required bool participating,
  required bool settingAllowsReset,
}) => !participating && settingAllowsReset;
