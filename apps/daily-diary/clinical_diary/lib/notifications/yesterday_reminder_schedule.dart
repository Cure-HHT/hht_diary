// Implements: DIARY-PRD-notification-yesterday-entry/F — the Yesterday Entry
//   Reminder's Reminder Time is sponsor-configurable per deployment; a present
//   sponsor value overrides the participant's personal time. The personal Time
//   and an enable toggle are a CUR product extension beyond assertion F (which
//   covers only sponsor configurability): the participant may set their own
//   Reminder Time and turn the reminder off, while an Active Trial Policy can
//   force the reminder enabled and/or pin the time.
//
// Pure derivation, mirroring `resolveEpistaxisReminderSchedule` /
// `SponsorUiConfig.fromSettings`: no I/O, deterministic, defensive about wire
// shape.
import 'package:diary_shared_model/diary_shared_model.dart';

/// Settings keys (`source: user`) for the personal Yesterday reminder.
const String reminderYesterdayEnabledKey = 'reminder.yesterdayEnabled';
const String reminderYesterdayTimeMinutesKey = 'reminder.yesterdayTimeMinutes';

/// Settings keys (`source: sponsor`, `locked`) delivered in the `/link`
/// `sponsor_settings` batch. The enabled key, when true, force-enables the
/// reminder (Active Trial Policy); the time key pins the Reminder Time (F).
const String reminderYesterdayEnabledSponsorKey =
    'reminder.yesterdayEnabledSponsor';
const String reminderYesterdayTimeMinutesSponsorKey =
    'reminder.yesterdayTimeMinutesSponsor';

/// Default Reminder Time: 09:00 local (Callisto overlay
/// `CAL-PRD-notification-yesterday-entry-configuration`), expressed as
/// minutes-from-local-midnight.
const int kDefaultYesterdayReminderMinutes = 9 * 60;

/// Reminders may be set on the hour or half-hour, 00:00–23:30.
const int _kReminderStepMinutes = 30;
const int _kMaxReminderMinutes = 23 * 60 + 30;

/// Resolved Yesterday Entry Reminder configuration.
class YesterdayReminderConfig {
  const YesterdayReminderConfig({
    required this.enabled,
    required this.timeMinutes,
  });

  /// Whether the reminder is active.
  final bool enabled;

  /// Reminder Time as minutes-from-local-midnight, snapped to a 30-min grid.
  final int timeMinutes;

  @override
  bool operator ==(Object other) =>
      other is YesterdayReminderConfig &&
      other.enabled == enabled &&
      other.timeMinutes == timeMinutes;

  @override
  int get hashCode => Object.hash(enabled, timeMinutes);
}

/// Resolves the effective configuration from the folded settings map.
///
/// - **Reminder Time:** sponsor value (F) wins; else personal; else the 09:00
///   default. Snapped to a 30-minute grid in [0, 23:30].
/// - **Enabled:** a sponsor `true` force-enables (Active Trial Policy); a
///   sponsor `false` force-disables; else the personal value; else the default
///   (enabled).
YesterdayReminderConfig resolveYesterdayReminderConfig(
  Map<String, SettingPayload> settings,
) {
  int? minutesOf(String key) {
    final v = settings[key]?.value;
    final raw = switch (v) {
      final int i => i,
      final double d when d == d.roundToDouble() => d.toInt(),
      _ => null,
    };
    if (raw == null) return null;
    return _snapToGrid(raw);
  }

  bool? boolOf(String key) {
    final v = settings[key]?.value;
    return v is bool ? v : null;
  }

  final time =
      minutesOf(reminderYesterdayTimeMinutesSponsorKey) ??
      minutesOf(reminderYesterdayTimeMinutesKey) ??
      kDefaultYesterdayReminderMinutes;

  final enabled =
      boolOf(reminderYesterdayEnabledSponsorKey) ??
      boolOf(reminderYesterdayEnabledKey) ??
      true;

  return YesterdayReminderConfig(enabled: enabled, timeMinutes: time);
}

/// Clamps [minutes] into [0, 23:30] and snaps it to the nearest 30-min grid
/// point, so an out-of-range or off-grid stored value is always usable.
int _snapToGrid(int minutes) {
  final clamped = minutes.clamp(0, _kMaxReminderMinutes);
  final snapped =
      ((clamped + _kReminderStepMinutes ~/ 2) ~/ _kReminderStepMinutes) *
      _kReminderStepMinutes;
  return snapped.clamp(0, _kMaxReminderMinutes);
}
