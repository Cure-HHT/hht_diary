// Verifies: DIARY-DEV-state-in-event-log/A — user preferences are derived from
//   the event-sourced settings projection, not shared_preferences.
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

SettingPayload _user(String key, Object? value) => SettingPayload(
  key: key,
  value: value,
  source: SettingSource.user,
  locked: false,
);

void main() {
  group('userPreferencesFromSettings', () {
    test('returns defaults when settings map is empty', () {
      final prefs = userPreferencesFromSettings(const {});
      expect(prefs.isDarkMode, isFalse);
      expect(prefs.largerTextAndControls, isFalse);
      expect(prefs.useAnimation, isTrue);
      expect(prefs.compactView, isFalse);
      expect(prefs.languageCode, 'en');
      expect(prefs.selectedFont, 'Roboto');
      expect(prefs, const UserPreferences());
    });

    test('maps each key to its field', () {
      final prefs = userPreferencesFromSettings({
        prefDarkMode: _user(prefDarkMode, true),
        prefLargerText: _user(prefLargerText, true),
        prefUseAnimation: _user(prefUseAnimation, false),
        prefCompactView: _user(prefCompactView, true),
        prefLanguageCode: _user(prefLanguageCode, 'es'),
        prefSelectedFont: _user(prefSelectedFont, 'OpenDyslexic'),
      });
      expect(prefs.isDarkMode, isTrue);
      expect(prefs.largerTextAndControls, isTrue);
      expect(prefs.useAnimation, isFalse);
      expect(prefs.compactView, isTrue);
      expect(prefs.languageCode, 'es');
      expect(prefs.selectedFont, 'OpenDyslexic');
    });

    test('uses defaults for keys that are absent', () {
      final prefs = userPreferencesFromSettings({
        prefDarkMode: _user(prefDarkMode, true),
        prefLanguageCode: _user(prefLanguageCode, 'fr'),
      });
      expect(prefs.isDarkMode, isTrue);
      expect(prefs.languageCode, 'fr');
      // Untouched keys keep their defaults.
      expect(prefs.useAnimation, isTrue);
      expect(prefs.compactView, isFalse);
      expect(prefs.largerTextAndControls, isFalse);
      expect(prefs.selectedFont, 'Roboto');
    });

    test('falls back to default when a value has the wrong type', () {
      final prefs = userPreferencesFromSettings({
        // bool key holding a String
        prefDarkMode: _user(prefDarkMode, 'yes'),
        // String key holding an int
        prefLanguageCode: _user(prefLanguageCode, 42),
        // bool key holding null
        prefUseAnimation: _user(prefUseAnimation, null),
      });
      expect(prefs.isDarkMode, isFalse);
      expect(prefs.languageCode, 'en');
      expect(prefs.useAnimation, isTrue);
    });
  });

  group('UserPreferences value semantics', () {
    test('equality and copyWith', () {
      const base = UserPreferences();
      expect(base.copyWith(isDarkMode: true).isDarkMode, isTrue);
      expect(base.copyWith(selectedFont: 'X').selectedFont, 'X');
      expect(base, const UserPreferences());
      expect(
        base.copyWith(isDarkMode: true) == const UserPreferences(),
        isFalse,
      );
    });
  });
}
