// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:clinical_diary/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    group('getLightThemeWithFont', () {
      test('returns light theme with default font for Roboto', () {
        final theme = AppTheme.getLightThemeWithFont(fontFamily: 'Roboto');

        expect(theme.brightness, equals(Brightness.light));
        // Roboto uses system default - should NOT be OpenDyslexic or Atkinson
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('OpenDyslexic')),
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('AtkinsonHyperlegible')),
        );
      });

      test('returns light theme with default font when null passed', () {
        final theme = AppTheme.getLightThemeWithFont();

        expect(theme.brightness, equals(Brightness.light));
        // Should NOT be OpenDyslexic or Atkinson
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('OpenDyslexic')),
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('AtkinsonHyperlegible')),
        );
      });

      test('returns light theme with OpenDyslexic fontFamily', () {
        final theme = AppTheme.getLightThemeWithFont(
          fontFamily: 'OpenDyslexic',
        );

        expect(theme.brightness, equals(Brightness.light));
        expect(theme.textTheme.bodyMedium?.fontFamily, equals('OpenDyslexic'));
      });

      test('returns light theme with AtkinsonHyperlegible fontFamily', () {
        final theme = AppTheme.getLightThemeWithFont(
          fontFamily: 'AtkinsonHyperlegible',
        );

        expect(theme.brightness, equals(Brightness.light));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          equals('AtkinsonHyperlegible'),
        );
      });
    });

    group('getDarkThemeWithFont', () {
      test('returns dark theme with default font for Roboto', () {
        final theme = AppTheme.getDarkThemeWithFont(fontFamily: 'Roboto');

        expect(theme.brightness, equals(Brightness.dark));
        // Roboto uses system default - should NOT be OpenDyslexic or Atkinson
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('OpenDyslexic')),
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('AtkinsonHyperlegible')),
        );
      });

      test('returns dark theme with default font when null passed', () {
        final theme = AppTheme.getDarkThemeWithFont();

        expect(theme.brightness, equals(Brightness.dark));
        // Should NOT be OpenDyslexic or Atkinson
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('OpenDyslexic')),
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          isNot(equals('AtkinsonHyperlegible')),
        );
      });

      test('returns dark theme with OpenDyslexic fontFamily', () {
        final theme = AppTheme.getDarkThemeWithFont(fontFamily: 'OpenDyslexic');

        expect(theme.brightness, equals(Brightness.dark));
        expect(theme.textTheme.bodyMedium?.fontFamily, equals('OpenDyslexic'));
      });

      test('returns dark theme with AtkinsonHyperlegible fontFamily', () {
        final theme = AppTheme.getDarkThemeWithFont(
          fontFamily: 'AtkinsonHyperlegible',
        );

        expect(theme.brightness, equals(Brightness.dark));
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          equals('AtkinsonHyperlegible'),
        );
      });
    });

    group('atkinsonHyperlegibleFontFamily', () {
      test('is defined as AtkinsonHyperlegible', () {
        expect(
          AppTheme.atkinsonHyperlegibleFontFamily,
          equals('AtkinsonHyperlegible'),
        );
      });
    });

    // Legacy tests for deprecated methods below
    group('getLightTheme (deprecated)', () {
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

    group('getDarkTheme (deprecated)', () {
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
