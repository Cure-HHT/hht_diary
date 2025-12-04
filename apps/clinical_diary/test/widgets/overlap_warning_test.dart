// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('OverlapWarning', () {
    testWidgets('returns empty widget when overlapping count is 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Overlapping Events Detected'), findsNothing);
    });

    testWidgets('displays warning when overlapping count is 1', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overlapping Events Detected'), findsOneWidget);
      expect(
        find.text('This event overlaps with 1 existing event'),
        findsOneWidget,
      );
    });

    testWidgets('displays plural form for multiple overlapping events', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 3)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overlapping Events Detected'), findsOneWidget);
      expect(
        find.text('This event overlaps with 3 existing events'),
        findsOneWidget,
      );
    });

    testWidgets('displays warning icon', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('has amber colored container', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 1)),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(OverlapWarning),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, Colors.amber.shade50);
    });

    testWidgets('has amber border', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 1)),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(OverlapWarning),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });

    testWidgets('renders as a Row with icon and text column', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('icon has correct color', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingCount: 1)),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );

      expect(icon.color, Colors.amber.shade700);
    });
  });
}
