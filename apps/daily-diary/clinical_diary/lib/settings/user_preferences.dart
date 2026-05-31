// Implements: DIARY-DEV-state-in-event-log/A — the user-preferences domain is
//   recorded as `setting_applied` events and read back from the canonical
//   settings projection, never from `shared_preferences`.
//
// The canonical [UserPreferences] value type plus the pure derivation from the
// folded settings map (mirrors B1's `entryRestrictionConfigFromSettings`).
// Diary-side: the `pref.*` keys are `source: user` settings.
import 'package:diary_shared_model/diary_shared_model.dart';

/// Settings-stream keys for the six user preferences (`source: user`).
const String prefDarkMode = 'pref.darkMode';
const String prefLargerText = 'pref.largerText';
const String prefUseAnimation = 'pref.useAnimation';
const String prefCompactView = 'pref.compactView';
const String prefLanguageCode = 'pref.languageCode';
const String prefSelectedFont = 'pref.selectedFont';

/// User preferences value type. Same shape/defaults as the legacy
/// `PreferencesService.UserPreferences`; now sourced from the settings
/// projection.
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.largerTextAndControls = false,
    this.useAnimation = true,
    this.compactView = false,
    this.languageCode = 'en',
    this.selectedFont = 'Roboto',
  });

  final bool isDarkMode;
  final bool largerTextAndControls;
  final bool useAnimation;
  final bool compactView;
  final String languageCode;

  /// Selected font family name (e.g. 'Roboto', 'OpenDyslexic',
  /// 'AtkinsonHyperlegible').
  final String selectedFont;

  UserPreferences copyWith({
    bool? isDarkMode,
    bool? largerTextAndControls,
    bool? useAnimation,
    bool? compactView,
    String? languageCode,
    String? selectedFont,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      useAnimation: useAnimation ?? this.useAnimation,
      compactView: compactView ?? this.compactView,
      languageCode: languageCode ?? this.languageCode,
      selectedFont: selectedFont ?? this.selectedFont,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.isDarkMode == isDarkMode &&
      other.largerTextAndControls == largerTextAndControls &&
      other.useAnimation == useAnimation &&
      other.compactView == compactView &&
      other.languageCode == languageCode &&
      other.selectedFont == selectedFont;

  @override
  int get hashCode => Object.hash(
    isDarkMode,
    largerTextAndControls,
    useAnimation,
    compactView,
    languageCode,
    selectedFont,
  );
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

  return UserPreferences(
    isDarkMode: boolPref(prefDarkMode, defaults.isDarkMode),
    largerTextAndControls: boolPref(
      prefLargerText,
      defaults.largerTextAndControls,
    ),
    useAnimation: boolPref(prefUseAnimation, defaults.useAnimation),
    compactView: boolPref(prefCompactView, defaults.compactView),
    languageCode: stringPref(prefLanguageCode, defaults.languageCode),
    selectedFont: stringPref(prefSelectedFont, defaults.selectedFont),
  );
}
