// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('DateRecordsScreen', () {
    final testDate = DateTime(2025, 11, 28);

    testWidgets('displays the formatted date', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dateStr = DateFormat('EEEE, MMMM d, y').format(testDate);
      expect(find.text(dateStr), findsOneWidget);
    }, skip: true);

    testWidgets('displays back button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays "Add new event" button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add new event'), findsOneWidget);
    });

    testWidgets('calls onAddEvent when Add new event button is tapped', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () => called = true,
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add new event'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('displays empty state when no entries', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No events recorded for this day'), findsOneWidget);
    });

    // CUR-443: One-line format shows times, not intensity names
    testWidgets('displays list of entries', (tester) async {
      final entries = [
        buildEpistaxisEntry(
          entryId: 'test-1',
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          intensity: NosebleedIntensity.dripping,
        ),
        buildEpistaxisEntry(
          entryId: 'test-2',
          startTime: DateTime(2025, 11, 28, 14, 0),
          endTime: DateTime(2025, 11, 28, 14, 20),
          intensity: NosebleedIntensity.steadyStream,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: entries,
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('10:30 AM'), findsOneWidget);
      expect(find.textContaining('2:00 PM'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });

    // CUR-443: One-line format - tap by start time, not intensity name
    testWidgets('calls onEditEvent when entry is tapped', (tester) async {
      DiaryEntry? tappedEntry;
      final entry = buildEpistaxisEntry(
        entryId: 'test-1',
        startTime: DateTime(2025, 11, 28, 10, 30),
        endTime: DateTime(2025, 11, 28, 10, 45),
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (e) => tappedEntry = e,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the record card by finding the start time
      await tester.tap(find.textContaining('10:30 AM'));
      await tester.pump();

      expect(tappedEntry, isNotNull);
      expect(tappedEntry!.entryId, 'test-1');
    });

    testWidgets('displays No nosebleed event card correctly', (tester) async {
      final entry = buildNoEpistaxisEntry(
        entryId: 'test-1',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No nosebleeds'), findsOneWidget);
    });

    testWidgets('displays Unknown event card correctly', (tester) async {
      final entry = buildUnknownDayEntry(entryId: 'test-1', date: testDate);

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('displays event count in subtitle', (tester) async {
      final entries = [
        buildEpistaxisEntry(
          entryId: 'test-1',
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          intensity: NosebleedIntensity.dripping,
        ),
        buildEpistaxisEntry(
          entryId: 'test-2',
          startTime: DateTime(2025, 11, 28, 14, 0),
          endTime: DateTime(2025, 11, 28, 14, 20),
          intensity: NosebleedIntensity.steadyStream,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: entries,
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 events'), findsOneWidget);
    });

    testWidgets('displays "1 event" for single entry', (tester) async {
      final entries = [
        buildEpistaxisEntry(
          entryId: 'test-1',
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          intensity: NosebleedIntensity.dripping,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: entries,
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 event'), findsOneWidget);
    });
  });
}
