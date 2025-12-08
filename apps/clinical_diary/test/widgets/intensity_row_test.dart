// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/intensity_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('IntensityRow', () {
    testWidgets('displays all intensity options', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have 6 intensity options
      expect(find.byType(Image), findsNWidgets(6));
    });

    testWidgets('displays intensity labels', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Labels are displayed (may have newlines for two-word labels)
      expect(find.textContaining('Spotting'), findsOneWidget);
      expect(find.textContaining('Dripping'), findsWidgets);
    });

    testWidgets('calls onSelect when intensity is tapped', (tester) async {
      NosebleedIntensity? selected;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              width: 400,
              child: IntensityRow(
                onSelect: (intensity) => selected = intensity,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the first intensity option (Spotting)
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(selected, NosebleedIntensity.spotting);
    });

    testWidgets('can select different intensities', (tester) async {
      final selections = <NosebleedIntensity>[];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              width: 400,
              child: IntensityRow(onSelect: selections.add),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first option (Spotting)
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      // Tap second option (Dripping)
      await tester.tap(find.byType(InkWell).at(1));
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
              width: 400,
              child: IntensityRow(
                selectedIntensity: NosebleedIntensity.spotting,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Selected intensity should have bold font
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      // First text widget should be "Spotting" and should be bold
      final spottingText = textWidgets.first;
      expect(spottingText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('non-selected intensities have normal font weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              width: 400,
              child: IntensityRow(
                selectedIntensity: NosebleedIntensity.spotting,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-selected intensities should not be bold
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      // Second text widget should be "Dripping" and should not be bold
      final drippingText = textWidgets[1];
      expect(drippingText.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('renders as a row layout', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should use Row layout
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('works without initial selection', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              width: 400,
              child: IntensityRow(selectedIntensity: null, onSelect: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All intensities should have normal font weight when nothing is selected
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        expect(textWidget.style?.fontWeight, FontWeight.w500);
      }
    });

    testWidgets('displays tooltip on long press', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press to trigger tooltip
      await tester.longPress(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Tooltip should contain the intensity name
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('adapts to different widths', (tester) async {
      // Test with narrow width
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 300, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still render all 6 items
      expect(find.byType(Image), findsNWidgets(6));

      // Test with wide width
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 600, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still render all 6 items
      expect(find.byType(Image), findsNWidgets(6));
    });

    testWidgets('selected intensity has border', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(
              width: 400,
              child: IntensityRow(
                selectedIntensity: NosebleedIntensity.dripping,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find containers with border decoration
      final containers = tester.widgetList<Container>(find.byType(Container));
      var foundBorderedContainer = false;

      for (final container in containers) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.border != null) {
          foundBorderedContainer = true;
          break;
        }
      }

      expect(foundBorderedContainer, isTrue);
    });

    testWidgets('displays correct images for each intensity', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all Image widgets and verify they have asset image paths
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.length, 6);

      // Each image should be an AssetImage
      for (final image in images) {
        expect(image.image, isA<AssetImage>());
      }
    });

    testWidgets('uses LayoutBuilder for responsive sizing', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          Scaffold(
            body: SizedBox(width: 400, child: IntensityRow(onSelect: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should use LayoutBuilder for responsive layout
      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('all intensities can be selected', (tester) async {
      NosebleedIntensity? selected;

      for (var i = 0; i < NosebleedIntensity.values.length; i++) {
        await tester.pumpWidget(
          wrapWithMaterialApp(
            Scaffold(
              body: SizedBox(
                width: 400,
                child: IntensityRow(
                  onSelect: (intensity) => selected = intensity,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(InkWell).at(i));
        await tester.pump();

        expect(selected, NosebleedIntensity.values[i]);
      }
    });
  });
}
