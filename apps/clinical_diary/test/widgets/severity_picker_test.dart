// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/severity_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeverityPicker', () {
    testWidgets('displays title text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('How severe is the nosebleed?'), findsOneWidget);
    });

    testWidgets('displays subtitle text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Select the option that best describes the bleeding'),
        findsOneWidget,
      );
    });

    testWidgets('displays severity options (first visible ones)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: SeverityPicker(
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );

      // At least some severity options should be visible
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.text('Dripping'), findsOneWidget);
    });

    testWidgets('calls onSelect when severity is tapped', (tester) async {
      NosebleedSeverity? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              onSelect: (severity) => selected = severity,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dripping'));
      await tester.pump();

      expect(selected, NosebleedSeverity.dripping);
    });

    testWidgets('can select different visible severities', (tester) async {
      final selections = <NosebleedSeverity>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: SeverityPicker(
                onSelect: selections.add,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Spotting'));
      await tester.pump();

      await tester.tap(find.text('Dripping'));
      await tester.pump();

      expect(selections, [NosebleedSeverity.spotting, NosebleedSeverity.dripping]);
    });

    testWidgets('highlights selected severity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              selectedSeverity: NosebleedSeverity.steadyStream,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      // The selected severity should show with bold font
      final textWidget = tester.widget<Text>(
        find.text('Steady stream'),
      );
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('non-selected severities have normal font weight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              selectedSeverity: NosebleedSeverity.steadyStream,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      // Non-selected severity should not be bold
      final textWidget = tester.widget<Text>(
        find.text('Spotting'),
      );
      expect(textWidget.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('displays icons for visible severities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: SeverityPicker(
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );

      // Should have at least some icons (one for each visible severity)
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('renders as a grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeverityPicker(
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('works without initial selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: SeverityPicker(
                selectedSeverity: null,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );

      // Check visible severities have non-bold weight when nothing is selected
      final spottingText = tester.widget<Text>(
        find.text('Spotting'),
      );
      expect(spottingText.style?.fontWeight, FontWeight.w500);

      final drippingText = tester.widget<Text>(
        find.text('Dripping'),
      );
      expect(drippingText.style?.fontWeight, FontWeight.w500);
    });
  });
}
