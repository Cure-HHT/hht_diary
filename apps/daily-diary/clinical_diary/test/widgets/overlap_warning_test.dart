// Verifies: DIARY-GUI-entry-overlap-resolution

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:diary_shared_model/diary_shared_model.dart' as shared;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('OverlapWarning', () {
    EpistaxisEntryView createTestEntry({
      required DateTime startTime,
      required DateTime endTime,
    }) {
      return buildEpistaxisView(
        aggregateId: 'test-${startTime.millisecondsSinceEpoch}',
        startTime: startTime,
        endTime: endTime,
        endTimeZone: 'UTC',
        intensity: shared.NosebleedIntensity.spotting,
      );
    }

    testWidgets('returns empty widget when overlapping entries list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(const OverlapWarning(overlappingEntries: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Overlapping Events Detected'), findsNothing);
    });

    testWidgets('displays warning with time range when one overlap exists', (
      tester,
    ) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overlapping Events Detected'), findsOneWidget);
      expect(
        find.text('This event overlaps with 1 existing event'),
        findsOneWidget,
      );
    });

    testWidgets('displays overlap count when multiple exist', (tester) async {
      final overlappingEntries = [
        createTestEntry(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
        ),
        createTestEntry(
          startTime: DateTime(2024, 1, 15, 11, 0),
          endTime: DateTime(2024, 1, 15, 11, 45),
        ),
      ];

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: overlappingEntries),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overlapping Events Detected'), findsOneWidget);
      expect(
        find.text('This event overlaps with 2 existing events'),
        findsOneWidget,
      );
    });

    testWidgets('displays warning icon', (tester) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('has pending (amber) colored container', (tester) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(OverlapWarning),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, const Color(0xFFFFF5DE));
    });

    testWidgets('has rounded borderless container (Figma 675:2377)', (
      tester,
    ) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(OverlapWarning),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNull);
      expect(decoration?.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('renders as a Row with icon and text column', (tester) async {
      final overlappingEntries = [
        createTestEntry(
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
        ),
        createTestEntry(
          startTime: DateTime(2024, 1, 15, 11, 0),
          endTime: DateTime(2024, 1, 15, 11, 30),
        ),
      ];

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: overlappingEntries),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('icon has correct color', (tester) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );

      expect(icon.color, const Color(0xFFB9790A));
    });

    // CUR-1518 Issue 2 (DIARY-GUI-entry-overlap-resolution/B): the early warning
    // is informational only — it never offers a "Resolve" action, so it cannot
    // pull the participant out of the recording flow prematurely.
    testWidgets('never shows a Resolve button (informational only)', (
      tester,
    ) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(overlappingEntries: [overlappingEntry]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolve'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
