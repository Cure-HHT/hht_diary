import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  // Verifies: DIARY-PRD-mobile-offline-first/A+B+C
  group('IntensityPicker', () {
    testWidgets('displays title text', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(IntensityPicker(onSelect: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('How intense is the nosebleed?'), findsOneWidget);
    });

    testWidgets('displays subtitle text', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(IntensityPicker(onSelect: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Select the option that best describes the bleeding'),
        findsOneWidget,
      );
    });

    testWidgets('displays intensity options (first visible ones)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: IntensityPicker(onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At least some intensity options should be visible
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.text('Dripping'), findsOneWidget);
    });

    testWidgets('calls onSelect when intensity is tapped', (tester) async {
      NosebleedIntensity? selected;

      await tester.pumpWidget(
        wrapWithScaffold(
          IntensityPicker(onSelect: (intensity) => selected = intensity),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dripping'));
      await tester.pump();

      expect(selected, NosebleedIntensity.dripping);
    });

    testWidgets('can select different visible severities', (tester) async {
      final selections = <NosebleedIntensity>[];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: IntensityPicker(onSelect: selections.add),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spotting'));
      await tester.pump();

      await tester.tap(find.text('Dripping'));
      await tester.pump();

      expect(selections, [
        NosebleedIntensity.spotting,
        NosebleedIntensity.dripping,
      ]);
    });

    testWidgets('highlights selected intensity', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: IntensityPicker(
                selectedIntensity: NosebleedIntensity.steadyStream,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The selected intensity label renders in the theme primary color
      // (Figma redesign: selection cue is the primary ring + tinted label,
      // not a bold weight).
      final textWidget = tester.widget<Text>(find.text('Steady stream'));
      final context = tester.element(find.byType(IntensityPicker));
      expect(textWidget.style?.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('non-selected severities have normal font weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          IntensityPicker(
            selectedIntensity: NosebleedIntensity.steadyStream,
            onSelect: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-selected intensity should not be bold
      final textWidget = tester.widget<Text>(find.text('Spotting'));
      expect(textWidget.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('displays images for visible severities', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: IntensityPicker(onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have custom intensity images (one for each visible intensity)
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('renders as a grid', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(IntensityPicker(onSelect: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
    });

    // Verifies: DIARY-GUI-epistaxis-record/G
    // CUR-1517 regression: all six options must render when there is room.
    testWidgets('renders all six intensity options on a tall screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 900,
              child: IntensityPicker(onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Spotting',
        'Dripping',
        'Dripping quickly',
        'Steady stream',
        'Pouring',
        'Gushing',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label should render',
        );
      }
    });

    // Verifies: DIARY-GUI-epistaxis-record/G
    // CUR-1517 regression: on a short screen the grid must scroll (no clipped
    // overflow) so the bottom options ("Pouring"/"Gushing") stay reachable.
    testWidgets('scrolls to the bottom options on a short screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 360,
              child: IntensityPicker(onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The constrained layout must not overflow (the original bug clipped the
      // bottom row silently with NeverScrollableScrollPhysics).
      expect(tester.takeException(), isNull);

      // The bottom option is reachable by scrolling the grid into view.
      await tester.scrollUntilVisible(
        find.text('Gushing'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gushing'), findsOneWidget);
    });

    testWidgets('works without initial selection', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              height: 800,
              child: IntensityPicker(selectedIntensity: null, onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check visible severities have non-bold weight when nothing is selected
      final spottingText = tester.widget<Text>(find.text('Spotting'));
      expect(spottingText.style?.fontWeight, FontWeight.w500);

      final drippingText = tester.widget<Text>(find.text('Dripping'));
      expect(drippingText.style?.fontWeight, FontWeight.w500);
    });
  });
}
