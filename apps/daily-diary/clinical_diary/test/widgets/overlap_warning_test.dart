// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00043: Temporal Entry Validation - Overlap Prevention

import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('OverlapWarning', () {
    DiaryEntry createTestEntry({
      required DateTime startTime,
      required DateTime endTime,
    }) {
      return buildEpistaxisEntry(
        entryId: 'test-${startTime.millisecondsSinceEpoch}',
        startTime: startTime,
        endTime: endTime,
        intensity: NosebleedIntensity.spotting,
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
        find.text(
          'This time overlaps with an existing nosebleed record from 10:00 AM to 10:30 AM',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'displays first overlapping entry time range when multiple exist',
      (tester) async {
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
          find.text(
            'This time overlaps with an existing nosebleed record from 10:00 AM to 10:30 AM',
          ),
          findsOneWidget,
        );
      },
    );

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

    testWidgets('has amber colored container', (tester) async {
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
      expect(decoration?.color, Colors.amber.shade50);
    });

    testWidgets('has amber border', (tester) async {
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
      expect(decoration?.border, isNotNull);
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

      expect(icon.color, Colors.amber.shade700);
    });

    testWidgets('does not show View button when onViewConflict is null', (
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

      expect(find.text('View'), findsNothing);
    });

    testWidgets('shows View button when onViewConflict is provided', (
      tester,
    ) async {
      final overlappingEntry = createTestEntry(
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(
            overlappingEntries: [overlappingEntry],
            onViewConflict: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('View button calls onViewConflict with first entry', (
      tester,
    ) async {
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

      DiaryEntry? tappedEntry;

      await tester.pumpWidget(
        wrapWithScaffold(
          OverlapWarning(
            overlappingEntries: overlappingEntries,
            onViewConflict: (entry) {
              tappedEntry = entry;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(tappedEntry, isNotNull);
      expect(tappedEntry!.entryId, overlappingEntries.first.entryId);
    });
  });
}
