// Tests for app_version.dart
// Covers: Version parsing, environment variable handling

import 'package:clinical_diary/utils/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appVersion', () {
    test('returns a string', () {
      expect(appVersion, isA<String>());
    });

    test('has default value when not set', () {
      // When APP_VERSION is not defined via --dart-define,
      // it defaults to '0.0.0'
      expect(appVersion, isNotEmpty);
    });

    test('default value is 0.0.0', () {
      // The default value defined in the source
      expect(appVersion, equals('0.0.0'));
    });
  });

  group('appFlavor', () {
    test('returns a string', () {
      expect(appFlavor, isA<String>());
    });

    test('has default value when not set', () {
      // When APP_FLAVOR is not defined via --dart-define,
      // it defaults to 'dev'
      expect(appFlavor, isNotEmpty);
    });

    test('default value is dev', () {
      // The default value defined in the source
      expect(appFlavor, equals('dev'));
    });
  });
}
