// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
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

      // The selected intensity should show with bold font
      // Note: label has newline because spaces are replaced with \n
      final textWidget = tester.widget<Text>(find.text('Steady\nstream'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
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
