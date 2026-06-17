// Implements: DIARY-DEV-state-in-event-log/A — the user-preferences domain is
//   recorded as `setting_applied` events and read back from the canonical
//   settings projection, never from `shared_preferences`.
//
// The canonical [UserPreferences] value type plus the pure derivation from the
// folded settings map (mirrors B1's `EntryGateRules.fromSettings`).
// Diary-side: the `pref.*` keys are `source: user` settings.
import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:diary_shared_model/diary_shared_model.dart';

/// Settings-stream keys for the user preferences (`source: user`).
const String prefDarkMode = 'pref.darkMode';
const String prefLargerText = 'pref.largerText';
const String prefUseAnimation = 'pref.useAnimation';
const String prefLanguageCode = 'pref.languageCode';
const String prefSelectedFont = 'pref.selectedFont';

/// User preferences value type, sourced from the event-sourced settings
/// projection.
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.largerTextAndControls = false,
    this.useAnimation = true,
    this.languageCode = 'en',
    this.selectedFont = 'Roboto',
    this.epistaxisReminderScheduleMinutes = const <int>[],
    this.yesterdayReminderEnabled = true,
    this.yesterdayReminderTimeMinutes = kDefaultYesterdayReminderMinutes,
  });

  final bool isDarkMode;
  final bool largerTextAndControls;
  final bool useAnimation;
  final String languageCode;

  /// Selected font family name (e.g. 'Roboto', 'OpenDyslexic',
  /// 'AtkinsonHyperlegible').
  final String selectedFont;

  /// The participant's personal Ongoing Epistaxis Reminder Schedule, as an
  /// ordered list of whole-minute intervals. Empty by default (no reminders).
  /// A *Sponsor*-configured schedule, when present, overrides this — see
  /// `resolveEpistaxisReminderSchedule`.
  // Implements: DIARY-PRD-notification-ongoing-epistaxis/H
  final List<int> epistaxisReminderScheduleMinutes;

  /// Whether the daily Yesterday Entry Reminder is enabled (default on). A
  /// *Sponsor* may force it on regardless — see `resolveYesterdayReminderConfig`.
  // Implements: DIARY-PRD-notification-yesterday-entry/F
  final bool yesterdayReminderEnabled;

  /// The Yesterday reminder's time of day, minutes-from-local-midnight
  /// (default 540 = 09:00). A *Sponsor*-configured time overrides this.
  // Implements: DIARY-PRD-notification-yesterday-entry/F
  final int yesterdayReminderTimeMinutes;

  UserPreferences copyWith({
    bool? isDarkMode,
    bool? largerTextAndControls,
    bool? useAnimation,
    String? languageCode,
    String? selectedFont,
    List<int>? epistaxisReminderScheduleMinutes,
    bool? yesterdayReminderEnabled,
    int? yesterdayReminderTimeMinutes,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      useAnimation: useAnimation ?? this.useAnimation,
      languageCode: languageCode ?? this.languageCode,
      selectedFont: selectedFont ?? this.selectedFont,
      epistaxisReminderScheduleMinutes:
          epistaxisReminderScheduleMinutes ??
          this.epistaxisReminderScheduleMinutes,
      yesterdayReminderEnabled:
          yesterdayReminderEnabled ?? this.yesterdayReminderEnabled,
      yesterdayReminderTimeMinutes:
          yesterdayReminderTimeMinutes ?? this.yesterdayReminderTimeMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.isDarkMode == isDarkMode &&
      other.largerTextAndControls == largerTextAndControls &&
      other.useAnimation == useAnimation &&
      other.languageCode == languageCode &&
      other.selectedFont == selectedFont &&
      _intListEq(
        other.epistaxisReminderScheduleMinutes,
        epistaxisReminderScheduleMinutes,
      ) &&
      other.yesterdayReminderEnabled == yesterdayReminderEnabled &&
      other.yesterdayReminderTimeMinutes == yesterdayReminderTimeMinutes;

  @override
  int get hashCode => Object.hash(
    isDarkMode,
    largerTextAndControls,
    useAnimation,
    languageCode,
    selectedFont,
    Object.hashAll(epistaxisReminderScheduleMinutes),
    yesterdayReminderEnabled,
    yesterdayReminderTimeMinutes,
  );
}

bool _intListEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Derives [UserPreferences] from the folded settings map (one [SettingPayload]
/// per key). Pure and deterministic: each `pref.*` key maps to a field, with the
/// [UserPreferences] default applied when the key is absent or its value has the
/// wrong type.
UserPreferences userPreferencesFromSettings(
  Map<String, SettingPayload> settings,
) {
  const defaults = UserPreferences();

  bool boolPref(String key, bool fallback) {
    final v = settings[key]?.value;
    return v is bool ? v : fallback;
  }

  String stringPref(String key, String fallback) {
    final v = settings[key]?.value;
    return v is String ? v : fallback;
  }

  int intPref(String key, int fallback) {
    final v = settings[key]?.value;
    return switch (v) {
      final int i => i,
      final double d when d == d.roundToDouble() => d.toInt(),
      _ => fallback,
    };
  }

  // Whole-minute interval list for the personal reminder schedule; non-integer
  // and non-positive entries are dropped, order preserved.
  List<int> minutesPref(String key, List<int> fallback) {
    final v = settings[key]?.value;
    if (v is! List) return fallback;
    final out = <int>[];
    for (final entry in v) {
      final minutes = switch (entry) {
        final int i => i,
        final double d when d == d.roundToDouble() => d.toInt(),
        _ => null,
      };
      if (minutes != null && minutes > 0) out.add(minutes);
    }
    return out;
  }

  return UserPreferences(
    isDarkMode: boolPref(prefDarkMode, defaults.isDarkMode),
    largerTextAndControls: boolPref(
      prefLargerText,
      defaults.largerTextAndControls,
    ),
    useAnimation: boolPref(prefUseAnimation, defaults.useAnimation),
    languageCode: stringPref(prefLanguageCode, defaults.languageCode),
    selectedFont: stringPref(prefSelectedFont, defaults.selectedFont),
    epistaxisReminderScheduleMinutes: minutesPref(
      reminderEpistaxisScheduleKey,
      defaults.epistaxisReminderScheduleMinutes,
    ),
    yesterdayReminderEnabled: boolPref(
      reminderYesterdayEnabledKey,
      defaults.yesterdayReminderEnabled,
    ),
    yesterdayReminderTimeMinutes: intPref(
      reminderYesterdayTimeMinutesKey,
      defaults.yesterdayReminderTimeMinutes,
    ),
  );
}
