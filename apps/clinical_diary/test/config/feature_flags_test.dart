// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // Set up test API base to avoid MissingConfigException
  setUpAll(() {
    AppConfig.testApiBaseOverride = 'https://test-api.example.com';
  });

  tearDownAll(() {
    AppConfig.testApiBaseOverride = null;
  });

  group('FeatureFlags', () {
    group('default values', () {
      test('defaultUseReviewScreen is false', () {
        expect(FeatureFlags.defaultUseReviewScreen, false);
      });

      test('defaultUseAnimations is true', () {
        expect(FeatureFlags.defaultUseAnimations, true);
      });

      test('defaultRequireOldEntryJustification is false', () {
        expect(FeatureFlags.defaultRequireOldEntryJustification, false);
      });

      test('defaultEnableShortDurationConfirmation is false', () {
        expect(FeatureFlags.defaultEnableShortDurationConfirmation, false);
      });

      test('defaultEnableLongDurationConfirmation is false', () {
        expect(FeatureFlags.defaultEnableLongDurationConfirmation, false);
      });

      test('defaultLongDurationThresholdMinutes is 60', () {
        expect(FeatureFlags.defaultLongDurationThresholdMinutes, 60);
      });
    });

    group('constraints', () {
      test('minLongDurationThresholdHours is 1', () {
        expect(FeatureFlags.minLongDurationThresholdHours, 1);
      });

      test('maxLongDurationThresholdHours is 9', () {
        expect(FeatureFlags.maxLongDurationThresholdHours, 9);
      });
    });

    group('known sponsors', () {
      test('contains curehht', () {
        expect(FeatureFlags.knownSponsors, contains('curehht'));
      });

      test('contains callisto', () {
        expect(FeatureFlags.knownSponsors, contains('callisto'));
      });

      test('has expected number of sponsors', () {
        expect(FeatureFlags.knownSponsors.length, 2);
      });
    });
  });

  group('FeatureFlagService', () {
    late FeatureFlagService service;

    setUp(() {
      service = FeatureFlagService.instance..resetToDefaults();
    });

    group('singleton', () {
      test('instance returns same object', () {
        final instance1 = FeatureFlagService.instance;
        final instance2 = FeatureFlagService.instance;
        expect(identical(instance1, instance2), true);
      });
    });

    group('default state', () {
      test('useReviewScreen defaults to false', () {
        expect(service.useReviewScreen, false);
      });

      test('useAnimations defaults to true', () {
        expect(service.useAnimations, true);
      });

      test('requireOldEntryJustification defaults to false', () {
        expect(service.requireOldEntryJustification, false);
      });

      test('enableShortDurationConfirmation defaults to false', () {
        expect(service.enableShortDurationConfirmation, false);
      });

      test('enableLongDurationConfirmation defaults to false', () {
        expect(service.enableLongDurationConfirmation, false);
      });

      test('longDurationThresholdMinutes defaults to 60', () {
        expect(service.longDurationThresholdMinutes, 60);
      });

      test('currentSponsorId is null by default', () {
        expect(service.currentSponsorId, isNull);
      });

      test('isLoading is false by default', () {
        expect(service.isLoading, false);
      });

      test('lastError is null by default', () {
        expect(service.lastError, isNull);
      });
    });

    group('setters', () {
      test('useReviewScreen can be set', () {
        service.useReviewScreen = true;
        expect(service.useReviewScreen, true);

        service.useReviewScreen = false;
        expect(service.useReviewScreen, false);
      });

      test('useAnimations can be set', () {
        service.useAnimations = false;
        expect(service.useAnimations, false);

        service.useAnimations = true;
        expect(service.useAnimations, true);
      });

      test('requireOldEntryJustification can be set', () {
        service.requireOldEntryJustification = true;
        expect(service.requireOldEntryJustification, true);
      });

      test('enableShortDurationConfirmation can be set', () {
        service.enableShortDurationConfirmation = true;
        expect(service.enableShortDurationConfirmation, true);
      });

      test('enableLongDurationConfirmation can be set', () {
        service.enableLongDurationConfirmation = true;
        expect(service.enableLongDurationConfirmation, true);
      });

      test('longDurationThresholdMinutes can be set', () {
        service.longDurationThresholdMinutes = 120;
        expect(service.longDurationThresholdMinutes, 120);
      });
    });

    group('resetToDefaults', () {
      test('resets all flags to defaults', () {
        // Set non-default values
        service
          ..useReviewScreen = true
          ..useAnimations = false
          ..requireOldEntryJustification = true
          ..enableShortDurationConfirmation = true
          ..enableLongDurationConfirmation = true
          ..longDurationThresholdMinutes = 120
          // Reset
          ..resetToDefaults();

        // Verify defaults
        expect(service.useReviewScreen, FeatureFlags.defaultUseReviewScreen);
        expect(service.useAnimations, FeatureFlags.defaultUseAnimations);
        expect(
          service.requireOldEntryJustification,
          FeatureFlags.defaultRequireOldEntryJustification,
        );
        expect(
          service.enableShortDurationConfirmation,
          FeatureFlags.defaultEnableShortDurationConfirmation,
        );
        expect(
          service.enableLongDurationConfirmation,
          FeatureFlags.defaultEnableLongDurationConfirmation,
        );
        expect(
          service.longDurationThresholdMinutes,
          FeatureFlags.defaultLongDurationThresholdMinutes,
        );
        expect(service.currentSponsorId, isNull);
        expect(service.lastError, isNull);
      });
    });

    group('initialize', () {
      test('completes successfully', () async {
        await expectLater(service.initialize(), completes);
      });
    });

    group('loadFromServer', () {
      test('returns false on server error', () async {
        service.httpClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        final result = await service.loadFromServer('curehht');
        expect(result, false);
        expect(service.lastError, 'Server error: 500');
      });

      test('returns false on network error', () async {
        service.httpClient = MockClient((request) async {
          throw http.ClientException('Network unreachable');
        });

        final result = await service.loadFromServer('curehht');
        expect(result, false);
        expect(service.lastError, contains('Network error'));
      });

      test('returns false on invalid JSON', () async {
        service.httpClient = MockClient((request) async {
          return http.Response('not valid json', 200);
        });

        final result = await service.loadFromServer('curehht');
        expect(result, false);
        expect(service.lastError, startsWith('Error:'));
      });

      test('successfully loads flags from server', () async {
        final responseBody = jsonEncode({
          'flags': {
            'useReviewScreen': true,
            'useAnimations': false,
            'requireOldEntryJustification': true,
            'enableShortDurationConfirmation': true,
            'enableLongDurationConfirmation': true,
            'longDurationThresholdMinutes': 90,
          },
        });

        service.httpClient = MockClient((request) async {
          return http.Response(responseBody, 200);
        });

        final result = await service.loadFromServer('curehht');

        expect(result, true);
        expect(service.lastError, isNull);
        expect(service.currentSponsorId, 'curehht');
        expect(service.useReviewScreen, true);
        expect(service.useAnimations, false);
        expect(service.requireOldEntryJustification, true);
        expect(service.enableShortDurationConfirmation, true);
        expect(service.enableLongDurationConfirmation, true);
        expect(service.longDurationThresholdMinutes, 90);
      });

      test('uses defaults for missing flags', () async {
        final responseBody = jsonEncode({
          'flags': {
            // Only set some flags
            'useReviewScreen': true,
          },
        });

        service.httpClient = MockClient((request) async {
          return http.Response(responseBody, 200);
        });

        final result = await service.loadFromServer('curehht');

        expect(result, true);
        expect(service.useReviewScreen, true);
        // Other flags should use defaults
        expect(service.useAnimations, FeatureFlags.defaultUseAnimations);
        expect(
          service.requireOldEntryJustification,
          FeatureFlags.defaultRequireOldEntryJustification,
        );
        expect(
          service.enableShortDurationConfirmation,
          FeatureFlags.defaultEnableShortDurationConfirmation,
        );
        expect(
          service.enableLongDurationConfirmation,
          FeatureFlags.defaultEnableLongDurationConfirmation,
        );
        expect(
          service.longDurationThresholdMinutes,
          FeatureFlags.defaultLongDurationThresholdMinutes,
        );
      });

      test('isLoading is false after completion', () async {
        service.httpClient = MockClient((request) async {
          return http.Response(jsonEncode({'flags': <String, String>{}}), 200);
        });

        await service.loadFromServer('curehht');
        expect(service.isLoading, false);
      });

      test('isLoading is false after error', () async {
        service.httpClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        await service.loadFromServer('curehht');
        expect(service.isLoading, false);
      });

      test('successfully loads availableFonts from server', () async {
        final responseBody = jsonEncode({
          'flags': {
            'availableFonts': [
              'Roboto',
              'OpenDyslexic',
              'AtkinsonHyperlegible',
            ],
          },
        });

        service.httpClient = MockClient((request) async {
          return http.Response(responseBody, 200);
        });

        final result = await service.loadFromServer('curehht');

        expect(result, true);
        expect(service.availableFonts, hasLength(3));
        expect(service.availableFonts, contains(FontOption.roboto));
        expect(service.availableFonts, contains(FontOption.openDyslexic));
        expect(
          service.availableFonts,
          contains(FontOption.atkinsonHyperlegible),
        );
      });

      test('uses default fonts when availableFonts not in response', () async {
        final responseBody = jsonEncode({
          'flags': {'useReviewScreen': true},
        });

        service.httpClient = MockClient((request) async {
          return http.Response(responseBody, 200);
        });

        final result = await service.loadFromServer('curehht');

        expect(result, true);
        // Should have default fonts (all 3)
        expect(service.availableFonts, hasLength(3));
      });

      // CUR-546: Test for loading Callisto flags with validation enabled
      test(
        'successfully loads callisto flags with validations enabled',
        () async {
          // Callisto config as returned by server (matches functions/src/sponsor.ts)
          final responseBody = jsonEncode({
            'flags': {
              'useReviewScreen': false,
              'useAnimations': true,
              'requireOldEntryJustification': true,
              'enableShortDurationConfirmation': true,
              'enableLongDurationConfirmation': true,
              'longDurationThresholdMinutes': 60,
              'availableFonts': [
                'Roboto',
                'OpenDyslexic',
                'AtkinsonHyperlegible',
              ],
            },
          });

          service.httpClient = MockClient((request) async {
            return http.Response(responseBody, 200);
          });

          final result = await service.loadFromServer('callisto');

          expect(result, true);
          expect(service.lastError, isNull);
          expect(service.currentSponsorId, 'callisto');

          // Callisto has all validation features enabled
          expect(service.requireOldEntryJustification, true);
          expect(service.enableShortDurationConfirmation, true);
          expect(service.enableLongDurationConfirmation, true);
          expect(service.longDurationThresholdMinutes, 60);

          // UI flags
          expect(service.useReviewScreen, false);
          expect(service.useAnimations, true);

          // All fonts available
          expect(service.availableFonts, hasLength(3));
        },
      );
    });

    group('availableFonts', () {
      test('defaults to all fonts', () {
        expect(service.availableFonts, hasLength(3));
        expect(service.availableFonts, contains(FontOption.roboto));
        expect(service.availableFonts, contains(FontOption.openDyslexic));
        expect(
          service.availableFonts,
          contains(FontOption.atkinsonHyperlegible),
        );
      });

      test('can be set to a subset', () {
        service.availableFonts = [FontOption.roboto, FontOption.openDyslexic];
        expect(service.availableFonts, hasLength(2));
        expect(service.availableFonts, contains(FontOption.roboto));
        expect(service.availableFonts, contains(FontOption.openDyslexic));
        expect(
          service.availableFonts,
          isNot(contains(FontOption.atkinsonHyperlegible)),
        );
      });

      test('can be set to empty', () {
        service.availableFonts = [];
        expect(service.availableFonts, isEmpty);
      });
    });

    group('shouldShowFontSelector', () {
      test('returns false when availableFonts is empty', () {
        service.availableFonts = [];
        expect(service.shouldShowFontSelector, false);
      });

      test('returns false when only Roboto is available', () {
        service.availableFonts = [FontOption.roboto];
        expect(service.shouldShowFontSelector, false);
      });

      test('returns true when OpenDyslexic is available', () {
        service.availableFonts = [FontOption.openDyslexic];
        expect(service.shouldShowFontSelector, true);
      });

      test('returns true when AtkinsonHyperlegible is available', () {
        service.availableFonts = [FontOption.atkinsonHyperlegible];
        expect(service.shouldShowFontSelector, true);
      });

      test(
        'returns true when multiple fonts including Roboto are available',
        () {
          service.availableFonts = [FontOption.roboto, FontOption.openDyslexic];
          expect(service.shouldShowFontSelector, true);
        },
      );

      test('returns true when all fonts are available', () {
        service.availableFonts = FontOption.values.toList();
        expect(service.shouldShowFontSelector, true);
      });
    });
  });

  group('FontOption', () {
    test('roboto has correct fontFamily', () {
      expect(FontOption.roboto.fontFamily, 'Roboto');
    });

    test('openDyslexic has correct fontFamily', () {
      expect(FontOption.openDyslexic.fontFamily, 'OpenDyslexic');
    });

    test('atkinsonHyperlegible has correct fontFamily', () {
      expect(
        FontOption.atkinsonHyperlegible.fontFamily,
        'AtkinsonHyperlegible',
      );
    });

    test('roboto has correct displayName', () {
      expect(FontOption.roboto.displayName, 'Roboto (Default)');
    });

    test('openDyslexic has correct displayName', () {
      expect(FontOption.openDyslexic.displayName, 'OpenDyslexic');
    });

    test('atkinsonHyperlegible has correct displayName', () {
      expect(
        FontOption.atkinsonHyperlegible.displayName,
        'Atkinson Hyperlegible',
      );
    });

    group('fromString', () {
      test('parses Roboto', () {
        expect(FontOption.fromString('Roboto'), FontOption.roboto);
      });

      test('parses OpenDyslexic', () {
        expect(FontOption.fromString('OpenDyslexic'), FontOption.openDyslexic);
      });

      test('parses AtkinsonHyperlegible', () {
        expect(
          FontOption.fromString('AtkinsonHyperlegible'),
          FontOption.atkinsonHyperlegible,
        );
      });

      test('returns null for unknown font', () {
        expect(FontOption.fromString('UnknownFont'), isNull);
      });

      test('returns null for empty string', () {
        expect(FontOption.fromString(''), isNull);
      });
    });
  });
}
