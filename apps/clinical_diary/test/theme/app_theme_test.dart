// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    group('getLightTheme', () {
      test('returns light theme without dyslexic font by default', () {
        final theme = AppTheme.getLightTheme();

        expect(theme.brightness, equals(Brightness.light));
        // Default system font has no explicit fontFamily set
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });

      test('returns light theme with dyslexic font when enabled', () {
        final theme = AppTheme.getLightTheme(useDyslexicFont: true);

        expect(theme.brightness, equals(Brightness.light));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          equals(AppTheme.openDyslexicFontFamily),
        );
      });

      test('returns light theme without dyslexic font when disabled', () {
        final theme = AppTheme.getLightTheme(useDyslexicFont: false);

        expect(theme.brightness, equals(Brightness.light));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });
    });

    group('getDarkTheme', () {
      test('returns dark theme without dyslexic font by default', () {
        final theme = AppTheme.getDarkTheme();

        expect(theme.brightness, equals(Brightness.dark));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });

      test('returns dark theme with dyslexic font when enabled', () {
        final theme = AppTheme.getDarkTheme(useDyslexicFont: true);

        expect(theme.brightness, equals(Brightness.dark));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          equals(AppTheme.openDyslexicFontFamily),
        );
      });

      test('returns dark theme without dyslexic font when disabled', () {
        final theme = AppTheme.getDarkTheme(useDyslexicFont: false);

        expect(theme.brightness, equals(Brightness.dark));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });
    });

    group('legacy getters', () {
      test('lightTheme getter returns theme without dyslexic font', () {
        final theme = AppTheme.lightTheme;

        expect(theme.brightness, equals(Brightness.light));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });

      test('darkTheme getter returns theme without dyslexic font', () {
        final theme = AppTheme.darkTheme;

        expect(theme.brightness, equals(Brightness.dark));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals(AppTheme.openDyslexicFontFamily)),
        );
      });
    });

    group('openDyslexicFontFamily', () {
      test('is defined as OpenDyslexic', () {
        expect(AppTheme.openDyslexicFontFamily, equals('OpenDyslexic'));
      });
    });

    group('theme configuration', () {
      test('light theme uses Material 3', () {
        final theme = AppTheme.getLightTheme();
        expect(theme.useMaterial3, isTrue);
      });

      test('dark theme uses Material 3', () {
        final theme = AppTheme.getDarkTheme();
        expect(theme.useMaterial3, isTrue);
      });

      test('light theme uses primaryTeal as seed color', () {
        final theme = AppTheme.getLightTheme();
        expect(theme.colorScheme.primary, equals(AppTheme.primaryTeal));
      });

      test('dark theme uses primaryTeal as seed color', () {
        final theme = AppTheme.getDarkTheme();
        expect(theme.colorScheme.primary, equals(AppTheme.primaryTeal));
      });
    });
  });
}
