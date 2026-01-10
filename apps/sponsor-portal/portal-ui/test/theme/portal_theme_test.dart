// Tests for portal theme and status colors
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00029: Portal UI Design System

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

    test('has correct text theme sizes', () {
      expect(portalTheme.textTheme.displayLarge?.fontSize, 32);
      expect(portalTheme.textTheme.displayMedium?.fontSize, 24);
      expect(portalTheme.textTheme.displaySmall?.fontSize, 20);
      expect(portalTheme.textTheme.bodyLarge?.fontSize, 16);
      expect(portalTheme.textTheme.bodyMedium?.fontSize, 14);
      expect(portalTheme.textTheme.bodySmall?.fontSize, 12);
    });

    test('card theme has elevation', () {
      expect(portalTheme.cardTheme.elevation, 2);
    });

    test('input decoration theme is filled', () {
      expect(portalTheme.inputDecorationTheme.filled, isTrue);
    });
  });

  group('StatusColors', () {
    test('active is green', () {
      expect(StatusColors.active, const Color(0xFF4CAF50));
    });

    test('attention is amber', () {
      expect(StatusColors.attention, const Color(0xFFFFC107));
    });

    test('atRisk is red', () {
      expect(StatusColors.atRisk, const Color(0xFFF44336));
    });

    test('noData is grey', () {
      expect(StatusColors.noData, const Color(0xFF9E9E9E));
    });

    test('colors are distinct', () {
      final colors = [
        StatusColors.active,
        StatusColors.attention,
        StatusColors.atRisk,
        StatusColors.noData,
      ];

      // All colors should be unique
      expect(colors.toSet().length, colors.length);
    });
  });
}
