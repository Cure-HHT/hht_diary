// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService', () {
    late PreferencesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = PreferencesService();
    });

    group('useAnimation', () {
      test('getUseAnimation returns true by default', () async {
        final result = await service.getUseAnimation();
        expect(result, isTrue);
      });

      test('setUseAnimation stores value correctly', () async {
        await service.setUseAnimation(false);

        final result = await service.getUseAnimation();
        expect(result, isFalse);
      });

      test('setUseAnimation can toggle value', () async {
        await service.setUseAnimation(false);
        expect(await service.getUseAnimation(), isFalse);

        await service.setUseAnimation(true);
        expect(await service.getUseAnimation(), isTrue);
      });
    });

    group('compactView', () {
      test('getCompactView returns false by default', () async {
        final result = await service.getCompactView();
        expect(result, isFalse);
      });

      test('setCompactView stores value correctly', () async {
        await service.setCompactView(true);

        final result = await service.getCompactView();
        expect(result, isTrue);
      });

      test('setCompactView can toggle value', () async {
        await service.setCompactView(true);
        expect(await service.getCompactView(), isTrue);

        await service.setCompactView(false);
        expect(await service.getCompactView(), isFalse);
      });
    });

    group('getPreferences', () {
      test('returns default values when nothing is stored', () async {
        final prefs = await service.getPreferences();

        expect(prefs.isDarkMode, isFalse);
        expect(prefs.largerTextAndControls, isFalse);
        expect(prefs.useAnimation, isTrue);
        expect(prefs.compactView, isFalse);
        expect(prefs.languageCode, equals('en'));
      });

      test('returns stored values', () async {
        await service.savePreferences(
          const UserPreferences(
            isDarkMode: true,
            largerTextAndControls: true,
            useAnimation: false,
            compactView: true,
            languageCode: 'es',
          ),
        );

        final prefs = await service.getPreferences();

        expect(prefs.isDarkMode, isTrue);
        expect(prefs.largerTextAndControls, isTrue);
        expect(prefs.useAnimation, isFalse);
        expect(prefs.compactView, isTrue);
        expect(prefs.languageCode, equals('es'));
      });
    });

    group('savePreferences', () {
      test('persists all preference values', () async {
        const prefs = UserPreferences(
          isDarkMode: true,
          largerTextAndControls: true,
          useAnimation: false,
          compactView: true,
          languageCode: 'fr',
        );

        await service.savePreferences(prefs);

        final loaded = await service.getPreferences();
        expect(loaded.isDarkMode, equals(prefs.isDarkMode));
        expect(
          loaded.largerTextAndControls,
          equals(prefs.largerTextAndControls),
        );
        expect(loaded.useAnimation, equals(prefs.useAnimation));
        expect(loaded.compactView, equals(prefs.compactView));
        expect(loaded.languageCode, equals(prefs.languageCode));
      });
    });

    group('darkMode', () {
      test('setDarkMode stores value correctly', () async {
        await service.setDarkMode(true);

        final prefs = await service.getPreferences();
        expect(prefs.isDarkMode, isTrue);
      });

      test('setDarkMode can toggle value', () async {
        await service.setDarkMode(true);
        var prefs = await service.getPreferences();
        expect(prefs.isDarkMode, isTrue);

        await service.setDarkMode(false);
        prefs = await service.getPreferences();
        expect(prefs.isDarkMode, isFalse);
      });
    });

    group('largerTextAndControls', () {
      test('setLargerTextAndControls stores value correctly', () async {
        await service.setLargerTextAndControls(true);

        final prefs = await service.getPreferences();
        expect(prefs.largerTextAndControls, isTrue);
      });

      test('setLargerTextAndControls can toggle value', () async {
        await service.setLargerTextAndControls(true);
        var prefs = await service.getPreferences();
        expect(prefs.largerTextAndControls, isTrue);

        await service.setLargerTextAndControls(false);
        prefs = await service.getPreferences();
        expect(prefs.largerTextAndControls, isFalse);
      });
    });

    group('languageCode', () {
      test('getLanguageCode returns en by default', () async {
        final result = await service.getLanguageCode();
        expect(result, equals('en'));
      });

      test('setLanguageCode stores value correctly', () async {
        await service.setLanguageCode('es');

        final result = await service.getLanguageCode();
        expect(result, equals('es'));
      });

      test('setLanguageCode can change value', () async {
        await service.setLanguageCode('fr');
        expect(await service.getLanguageCode(), equals('fr'));

        await service.setLanguageCode('de');
        expect(await service.getLanguageCode(), equals('de'));
      });
    });

    group('selectedFont', () {
      test('getSelectedFont returns Roboto by default', () async {
        final result = await service.getSelectedFont();
        expect(result, equals('Roboto'));
      });

      test('setSelectedFont stores value correctly', () async {
        await service.setSelectedFont('OpenDyslexic');

        final result = await service.getSelectedFont();
        expect(result, equals('OpenDyslexic'));
      });

      test('setSelectedFont can change value', () async {
        await service.setSelectedFont('OpenDyslexic');
        expect(await service.getSelectedFont(), equals('OpenDyslexic'));

        await service.setSelectedFont('AtkinsonHyperlegible');
        expect(await service.getSelectedFont(), equals('AtkinsonHyperlegible'));
      });

      test(
        'getSelectedFont migrates from legacy dyslexia font setting',
        () async {
          // Set the legacy dyslexia font preference
          SharedPreferences.setMockInitialValues({'pref_dyslexia_font': true});
          final migrationService = PreferencesService();

          final result = await migrationService.getSelectedFont();
          expect(result, equals('OpenDyslexic'));
        },
      );

      test(
        'getSelectedFont prefers selectedFont over legacy setting',
        () async {
          // Both settings exist, selectedFont should win
          SharedPreferences.setMockInitialValues({
            'pref_dyslexia_font': true,
            'pref_selected_font': 'AtkinsonHyperlegible',
          });
          final migrationService = PreferencesService();

          final result = await migrationService.getSelectedFont();
          expect(result, equals('AtkinsonHyperlegible'));
        },
      );
    });

    group('getPreferences font migration', () {
      test('migrates legacy dyslexia font to selectedFont', () async {
        SharedPreferences.setMockInitialValues({'pref_dyslexia_font': true});
        final migrationService = PreferencesService();

        final prefs = await migrationService.getPreferences();
        expect(prefs.selectedFont, equals('OpenDyslexic'));
      });

      test('uses Roboto when no font settings exist', () async {
        SharedPreferences.setMockInitialValues({});
        final migrationService = PreferencesService();

        final prefs = await migrationService.getPreferences();
        expect(prefs.selectedFont, equals('Roboto'));
      });
    });
  });

  group('UserPreferences', () {
    test('copyWith creates new instance with updated values', () {
      const original = UserPreferences(
        isDarkMode: false,
        largerTextAndControls: false,
        useAnimation: true,
        compactView: false,
        languageCode: 'en',
      );

      final updated = original.copyWith(
        useAnimation: false,
        compactView: true,
        languageCode: 'de',
      );

      expect(updated.isDarkMode, equals(original.isDarkMode));
      expect(
        updated.largerTextAndControls,
        equals(original.largerTextAndControls),
      );
      expect(updated.useAnimation, isFalse);
      expect(updated.compactView, isTrue);
      expect(updated.languageCode, equals('de'));
    });

    test('toJson serializes all fields', () {
      const prefs = UserPreferences(
        isDarkMode: true,
        largerTextAndControls: true,
        useAnimation: false,
        compactView: true,
        languageCode: 'es',
        selectedFont: 'OpenDyslexic',
      );

      final json = prefs.toJson();

      expect(json['isDarkMode'], isTrue);
      // Note: dyslexiaFriendlyFont removed from toJson (deprecated field)
      expect(json['largerTextAndControls'], isTrue);
      expect(json['useAnimation'], isFalse);
      expect(json['compactView'], isTrue);
      expect(json['languageCode'], equals('es'));
      expect(json['selectedFont'], equals('OpenDyslexic'));
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'isDarkMode': true,
        'dyslexiaFriendlyFont': true,
        'largerTextAndControls': true,
        'useAnimation': false,
        'compactView': true,
        'languageCode': 'fr',
      };

      final prefs = UserPreferences.fromJson(json);

      expect(prefs.isDarkMode, isTrue);
      expect(prefs.largerTextAndControls, isTrue);
      expect(prefs.useAnimation, isFalse);
      expect(prefs.compactView, isTrue);
      expect(prefs.languageCode, equals('fr'));
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};

      final prefs = UserPreferences.fromJson(json);

      expect(prefs.isDarkMode, isFalse);
      expect(prefs.largerTextAndControls, isFalse);
      expect(prefs.useAnimation, isTrue); // Default is true
      expect(prefs.compactView, isFalse); // Default is false
      expect(prefs.languageCode, equals('en'));
    });

    group('selectedFont', () {
      test('defaults to Roboto when not provided', () {
        final json = <String, dynamic>{};
        final prefs = UserPreferences.fromJson(json);
        expect(prefs.selectedFont, equals('Roboto'));
      });

      test('uses selectedFont when provided', () {
        final json = {'selectedFont': 'AtkinsonHyperlegible'};
        final prefs = UserPreferences.fromJson(json);
        expect(prefs.selectedFont, equals('AtkinsonHyperlegible'));
      });

      test('migrates dyslexiaFriendlyFont to OpenDyslexic', () {
        final json = {'dyslexiaFriendlyFont': true};
        final prefs = UserPreferences.fromJson(json);
        expect(prefs.selectedFont, equals('OpenDyslexic'));
      });

      test('selectedFont takes precedence over dyslexiaFriendlyFont', () {
        final json = {
          'dyslexiaFriendlyFont': true,
          'selectedFont': 'AtkinsonHyperlegible',
        };
        final prefs = UserPreferences.fromJson(json);
        expect(prefs.selectedFont, equals('AtkinsonHyperlegible'));
      });

      test('uses Roboto when dyslexiaFriendlyFont is false', () {
        final json = {'dyslexiaFriendlyFont': false};
        final prefs = UserPreferences.fromJson(json);
        expect(prefs.selectedFont, equals('Roboto'));
      });
    });

    group('copyWith selectedFont', () {
      test('can update selectedFont', () {
        const original = UserPreferences(selectedFont: 'Roboto');
        final updated = original.copyWith(selectedFont: 'OpenDyslexic');
        expect(updated.selectedFont, equals('OpenDyslexic'));
      });

      test('preserves selectedFont when not specified', () {
        const original = UserPreferences(selectedFont: 'OpenDyslexic');
        final updated = original.copyWith(isDarkMode: true);
        expect(updated.selectedFont, equals('OpenDyslexic'));
      });
    });
  });
}
