// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DateRecordsScreen', () {
    final testDate = DateTime(2025, 11, 28);

    testWidgets('displays the formatted date', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dateStr = DateFormat('EEEE, MMMM d, y').format(testDate);
      expect(find.text(dateStr), findsOneWidget);
    });

    testWidgets('displays back button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: const [],
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
            records: const [],
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
            records: const [],
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

    testWidgets('displays empty state when no records', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No events recorded for this day'), findsOneWidget);
    });

    testWidgets('displays list of records', (tester) async {
      final records = [
        NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          severity: NosebleedSeverity.dripping,
        ),
        NosebleedRecord(
          id: 'test-2',
          date: testDate,
          startTime: DateTime(2025, 11, 28, 14, 0),
          endTime: DateTime(2025, 11, 28, 14, 20),
          severity: NosebleedSeverity.steadyStream,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: records,
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display both records
      expect(find.text('Dripping'), findsOneWidget);
      expect(find.text('Steady stream'), findsOneWidget);
    });

    testWidgets('calls onEditEvent when record is tapped', (tester) async {
      NosebleedRecord? tappedRecord;
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2025, 11, 28, 10, 30),
        endTime: DateTime(2025, 11, 28, 10, 45),
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: [record],
            onAddEvent: () {},
            onEditEvent: (r) => tappedRecord = r,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the record card
      await tester.tap(find.text('Dripping'));
      await tester.pump();

      expect(tappedRecord, isNotNull);
      expect(tappedRecord!.id, 'test-1');
    });

    testWidgets('displays No nosebleed event card correctly', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        isNoNosebleedsEvent: true,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: [record],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No nosebleeds'), findsOneWidget);
    });

    testWidgets('displays Unknown event card correctly', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        isUnknownEvent: true,
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: [record],
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('displays event count in subtitle', (tester) async {
      final records = [
        NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          severity: NosebleedSeverity.dripping,
        ),
        NosebleedRecord(
          id: 'test-2',
          date: testDate,
          startTime: DateTime(2025, 11, 28, 14, 0),
          endTime: DateTime(2025, 11, 28, 14, 20),
          severity: NosebleedSeverity.steadyStream,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: records,
            onAddEvent: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 events'), findsOneWidget);
    });

    testWidgets('displays "1 event" for single record', (tester) async {
      final records = [
        NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          severity: NosebleedSeverity.dripping,
        ),
      ];

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            records: records,
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
