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
        expect(prefs.dyslexiaFriendlyFont, isFalse);
        expect(prefs.largerTextAndControls, isFalse);
        expect(prefs.useAnimation, isTrue);
        expect(prefs.compactView, isFalse);
        expect(prefs.languageCode, equals('en'));
      });

      test('returns stored values', () async {
        await service.savePreferences(
          const UserPreferences(
            isDarkMode: true,
            dyslexiaFriendlyFont: true,
            largerTextAndControls: true,
            useAnimation: false,
            compactView: true,
            languageCode: 'es',
          ),
        );

        final prefs = await service.getPreferences();

        expect(prefs.isDarkMode, isTrue);
        expect(prefs.dyslexiaFriendlyFont, isTrue);
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
          dyslexiaFriendlyFont: true,
          largerTextAndControls: true,
          useAnimation: false,
          compactView: true,
          languageCode: 'fr',
        );

        await service.savePreferences(prefs);

        final loaded = await service.getPreferences();
        expect(loaded.isDarkMode, equals(prefs.isDarkMode));
        expect(loaded.dyslexiaFriendlyFont, equals(prefs.dyslexiaFriendlyFont));
        expect(
          loaded.largerTextAndControls,
          equals(prefs.largerTextAndControls),
        );
        expect(loaded.useAnimation, equals(prefs.useAnimation));
        expect(loaded.compactView, equals(prefs.compactView));
        expect(loaded.languageCode, equals(prefs.languageCode));
      });
    });
  });

  group('UserPreferences', () {
    test('copyWith creates new instance with updated values', () {
      const original = UserPreferences(
        isDarkMode: false,
        dyslexiaFriendlyFont: false,
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
        updated.dyslexiaFriendlyFont,
        equals(original.dyslexiaFriendlyFont),
      );
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
        dyslexiaFriendlyFont: true,
        largerTextAndControls: true,
        useAnimation: false,
        compactView: true,
        languageCode: 'es',
      );

      final json = prefs.toJson();

      expect(json['isDarkMode'], isTrue);
      expect(json['dyslexiaFriendlyFont'], isTrue);
      expect(json['largerTextAndControls'], isTrue);
      expect(json['useAnimation'], isFalse);
      expect(json['compactView'], isTrue);
      expect(json['languageCode'], equals('es'));
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
      expect(prefs.dyslexiaFriendlyFont, isTrue);
      expect(prefs.largerTextAndControls, isTrue);
      expect(prefs.useAnimation, isFalse);
      expect(prefs.compactView, isTrue);
      expect(prefs.languageCode, equals('fr'));
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};

      final prefs = UserPreferences.fromJson(json);

      expect(prefs.isDarkMode, isFalse);
      expect(prefs.dyslexiaFriendlyFont, isFalse);
      expect(prefs.largerTextAndControls, isFalse);
      expect(prefs.useAnimation, isTrue); // Default is true
      expect(prefs.compactView, isFalse); // Default is false
      expect(prefs.languageCode, equals('en'));
    });
  });
}
