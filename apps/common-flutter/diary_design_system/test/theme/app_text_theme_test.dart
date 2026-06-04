import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests for font resolution. These pin the contract between
/// AppFontFamily and the bundled font assets so a future regression in
/// the per-family `package:` field (which routes Flutter to look up the
/// font in `diary_design_system`'s own assets) is caught at test time
/// instead of at runtime in a consumer app.
void main() {
  group('buildAppTheme font resolution', () {
    test('Inter resolves to a fontFamily that names Inter', () {
      final theme = buildAppTheme(
        font: AppFontFamily.inter,
        brightness: Brightness.light,
      );
      // bodyLarge is the default body run; if it doesn't carry an
      // Inter-named family then theme.textTheme is mis-wired and every
      // consumer screen renders in the platform fallback.
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        contains('Inter'),
        reason:
            'buildAppTheme(font: AppFontFamily.inter) must produce a '
            'TextTheme whose run families resolve to the bundled Inter '
            'asset, not the platform default.',
      );
    });

    test('font is consistent across the type scale', () {
      final theme = buildAppTheme(
        font: AppFontFamily.inter,
        brightness: Brightness.light,
      );
      // A subset of the M3 scale should all share the same family.
      // A drift here means a tier was constructed with a different
      // family override and consumer text will render mixed-font.
      final families = <String?>{
        theme.textTheme.displayLarge?.fontFamily,
        theme.textTheme.headlineMedium?.fontFamily,
        theme.textTheme.titleMedium?.fontFamily,
        theme.textTheme.bodyLarge?.fontFamily,
        theme.textTheme.labelSmall?.fontFamily,
      };
      expect(
        families.length,
        1,
        reason:
            'All text-theme tiers must use the same family; got: $families.',
      );
    });
  });
}
