import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/theme/portal_theme.dart';

void main() {
  group('portalTheme', () {
    test('uses Material 3', () {
      expect(portalTheme.useMaterial3, isTrue);
    });

    test('has light brightness', () {
      expect(portalTheme.colorScheme.brightness, Brightness.light);
    });

    test(
      'text theme uses the Material 3 type scale from diary_design_system',
      () {
        // Display sizes follow the Material 3 reference scale (was 32/24/20
        // in the legacy portalTheme — superseded by the shared design system).
        expect(portalTheme.textTheme.displayLarge?.fontSize, 57);
        expect(portalTheme.textTheme.displayMedium?.fontSize, 45);
        expect(portalTheme.textTheme.displaySmall?.fontSize, 36);
        // Body sizes are unchanged.
        expect(portalTheme.textTheme.bodyLarge?.fontSize, 16);
        expect(portalTheme.textTheme.bodyMedium?.fontSize, 14);
        expect(portalTheme.textTheme.bodySmall?.fontSize, 12);
      },
    );

    test('input decoration theme is filled', () {
      expect(portalTheme.inputDecorationTheme.filled, isTrue);
    });

    test('primary is the brand primary', () {
      // The design system's brand primary is #165C7D (confirmed against
      // Figma in Phase 3). Was incorrectly #0175C2 in the legacy portalTheme.
      expect(portalTheme.colorScheme.primary, const Color(0xFF165C7D));
    });
  });

  group('AppSemanticColors extension', () {
    // The legacy StatusColors class was deleted in this migration. Status
    // hues now live on the design system's ThemeExtension; portal code
    // reads them via Theme.of(context).extension<AppSemanticColors>().
    test('is registered on portalTheme', () {
      final semantic = portalTheme.extension<AppSemanticColors>();
      expect(semantic, isNotNull);
    });

    test('status colors are distinct', () {
      final semantic = portalTheme.extension<AppSemanticColors>()!;
      final colors = [
        semantic.statusActive,
        semantic.statusAttention,
        semantic.statusAtRisk,
        semantic.statusNoData,
      ];
      expect(colors.toSet().length, colors.length);
    });
  });
}
