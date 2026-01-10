// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('FlashHighlight', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: false,
            builder: (context, color) =>
                Container(key: const Key('test-container'), color: color),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('test-container')), findsOneWidget);
    });

    testWidgets('passes null color when not flashing', (tester) async {
      Color? capturedColor;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: false,
            builder: (context, color) {
              capturedColor = color;
              return Container();
            },
          ),
        ),
      );

      expect(capturedColor, isNull);
    });

    testWidgets('animates color when flash is true and enabled', (
      tester,
    ) async {
      Color? capturedColor;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: true,
            enabled: true,
            builder: (context, color) {
              capturedColor = color;
              return Container();
            },
          ),
        ),
      );

      // Initially should be null before animation starts
      await tester.pump();

      // After some animation time, color should be non-null
      await tester.pump(const Duration(milliseconds: 200));
      expect(capturedColor, isNotNull);
    });

    testWidgets('calls onFlashComplete after animation', (tester) async {
      var flashCompleted = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: true,
            enabled: true,
            onFlashComplete: () => flashCompleted = true,
            builder: (context, color) => Container(),
          ),
        ),
      );

      // Wait for full animation cycle (2 flashes at 250ms each = ~1000ms)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(flashCompleted, isTrue);
    });

    testWidgets(
      'skips animation and calls onFlashComplete immediately when disabled',
      (tester) async {
        var flashCompleted = false;

        await tester.pumpWidget(
          wrapWithScaffold(
            FlashHighlight(
              flash: true,
              enabled: false,
              onFlashComplete: () => flashCompleted = true,
              builder: (context, color) => Container(),
            ),
          ),
        );

        // Should complete immediately without needing pumpAndSettle
        await tester.pump();

        expect(flashCompleted, isTrue);
      },
    );

    testWidgets('does not pass color when disabled', (tester) async {
      Color? capturedColor;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: true,
            enabled: false,
            builder: (context, color) {
              capturedColor = color;
              return Container();
            },
          ),
        ),
      );

      await tester.pump();

      // Color should remain null when animations are disabled
      expect(capturedColor, isNull);
    });

    testWidgets('does not flash when flash is false even if enabled', (
      tester,
    ) async {
      var flashCompleted = false;
      Color? capturedColor;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: false,
            enabled: true,
            onFlashComplete: () => flashCompleted = true,
            builder: (context, color) {
              capturedColor = color;
              return Container();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not have flashed
      expect(flashCompleted, isFalse);
      expect(capturedColor, isNull);
    });

    testWidgets('uses custom highlight color when provided', (tester) async {
      Color? capturedColor;
      const customColor = Colors.red;

      await tester.pumpWidget(
        wrapWithScaffold(
          FlashHighlight(
            flash: true,
            enabled: true,
            highlightColor: customColor,
            builder: (context, color) {
              capturedColor = color;
              return Container();
            },
          ),
        ),
      );

      // Pump several frames to let the animation progress
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (capturedColor != null) break;
      }

      // The captured color should be derived from the custom color
      expect(capturedColor, isNotNull);
      // The color should have red component from the custom color
      expect((capturedColor!.r * 255).round(), greaterThan(0));
    });
  });
}
