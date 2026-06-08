// Verifies: DIARY-DEV-deployment-config-defaults/A+C+E
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

SettingPayload _s(String k, Object? v) => SettingPayload(
  key: k,
  value: v,
  source: SettingSource.sponsor,
  locked: true,
);

void main() {
  group('SponsorUiConfig.fromSettings precedence', () {
    test('code defaults when nothing set', () {
      final c = SponsorUiConfig.fromSettings(const {});
      expect(c.useAnimations, isTrue);
      expect(c.availableLanguages, kPlatformLanguageCodes);
      expect(c.availableFonts, kPlatformFontFamilies);
      expect(c.defaultLanguage, 'en');
      expect(c.defaultFont, 'Roboto');
    });

    test('deployment default overrides code default', () {
      const dep = SponsorUiConfig(availableLanguages: ['en', 'es']);
      final c = SponsorUiConfig.fromSettings(const {}, deploymentDefaults: dep);
      expect(c.availableLanguages, ['en', 'es']);
    });

    test('settings row overrides deployment default; null row is unset', () {
      const dep = SponsorUiConfig(availableLanguages: ['en', 'es']);
      final c = SponsorUiConfig.fromSettings({
        uiAvailableLanguagesKey: _s(uiAvailableLanguagesKey, ['en', 'fr']),
        uiDefaultLanguageKey: _s(uiDefaultLanguageKey, 'fr'),
        uiUseAnimationsKey: _s(uiUseAnimationsKey, null), // null => unset
      }, deploymentDefaults: dep);
      expect(c.availableLanguages, ['en', 'fr']);
      expect(c.defaultLanguage, 'fr');
      expect(c.useAnimations, isTrue); // null fell through to dep/code default
    });
  });

  group('SponsorUiConfig.fromSettings clamps to platform', () {
    test('drops unsupported allow-set values and dedupes', () {
      final c = SponsorUiConfig.fromSettings({
        uiAvailableLanguagesKey: _s(uiAvailableLanguagesKey, [
          'en',
          'xx', // unsupported
          'en', // duplicate
          'fr',
        ]),
        uiAvailableFontsKey: _s(uiAvailableFontsKey, ['Roboto', 'Comic Sans']),
      });
      expect(c.availableLanguages, ['en', 'fr']);
      expect(c.availableFonts, ['Roboto']);
    });

    test('empty-after-clamp allow-set falls back to the full platform set', () {
      final c = SponsorUiConfig.fromSettings({
        uiAvailableLanguagesKey: _s(uiAvailableLanguagesKey, ['xx', 'zz']),
      });
      expect(c.availableLanguages, kPlatformLanguageCodes);
    });

    test('default forced into the resolved allow-set', () {
      final c = SponsorUiConfig.fromSettings({
        uiAvailableLanguagesKey: _s(uiAvailableLanguagesKey, ['es', 'fr']),
        uiDefaultLanguageKey: _s(uiDefaultLanguageKey, 'de'), // not in set
      });
      expect(c.availableLanguages, ['es', 'fr']);
      expect(c.defaultLanguage, 'es'); // forced to first member
    });
  });

  group('reconcilePick', () {
    test('returns default when current pick out of set', () {
      expect(
        reconcilePick(current: 'de', allowed: ['en', 'es'], fallback: 'en'),
        'en',
      );
    });
    test('returns null (no write) when current pick is allowed', () {
      expect(
        reconcilePick(current: 'es', allowed: ['en', 'es'], fallback: 'en'),
        isNull,
      );
    });
  });
}
