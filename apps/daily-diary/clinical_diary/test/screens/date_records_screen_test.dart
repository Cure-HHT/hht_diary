// Verifies: DIARY-DEV-reactive-read-path/A — renders the driven typed
//   view-models (EpistaxisEntryView / DayMarkerView) via EventListItem.
// Verifies: DIARY-GUI-epistaxis-record/A — Add Event fires onAddEvent; tapping
//   an epistaxis item fires onEditEvent with the right view-model.
// Verifies: DIARY-PRD-day-disposition/B — tapping a day-marker row fires
//   onRedispositionMarker (re-disposition), while an epistaxis tap stays
//   onEditEvent.

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show NosebleedIntensity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('DateRecordsScreen', () {
    final testDate = DateTime(2025, 11, 28);

    // Fix device timezone to UTC+0 so that toDisplayedDateTime with
    // startTimeZone='UTC' is an identity transform (stored == displayed).
    setUp(() {
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';
    });
    tearDown(() {
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;
    });

    testWidgets('displays the formatted date', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: const [],
            onAddEvent: () {},
            onEditEvent: (_) {},
            onRedispositionMarker: (_) {},
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
            onRedispositionMarker: (_) {},
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
            onRedispositionMarker: (_) {},
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
            onRedispositionMarker: (_) {},
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
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No events recorded for this day'), findsOneWidget);
    });

    // CUR-443: One-line format shows times, not intensity names
    testWidgets('displays list of entries', (tester) async {
      final entries = [
        buildEpistaxisView(
          aggregateId: 'test-1',
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          intensity: NosebleedIntensity.dripping,
        ),
        buildEpistaxisView(
          aggregateId: 'test-2',
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
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('10:30 AM'), findsOneWidget);
      expect(find.textContaining('2:00 PM'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });

    // CUR-443: One-line format - tap by start time, not intensity name
    testWidgets('calls onEditEvent with the right view-model when tapped', (
      tester,
    ) async {
      EpistaxisEntryView? tappedEntry;
      final entry = buildEpistaxisView(
        aggregateId: 'test-1',
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
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the record card by finding the start time
      await tester.tap(find.textContaining('10:30 AM'));
      await tester.pump();

      expect(tappedEntry, isNotNull);
      expect(tappedEntry!.aggregateId, 'test-1');
    });

    testWidgets('displays No nosebleed event card correctly', (tester) async {
      final entry = buildDayMarkerView(
        aggregateId: 'test-1',
        date: '2025-11-28',
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (_) {},
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No nosebleeds'), findsOneWidget);
    });

    testWidgets('tapping a day-marker fires onRedispositionMarker', (
      tester,
    ) async {
      DayMarkerView? tapped;
      final entry = buildDayMarkerView(
        aggregateId: 'P:2025-11-28',
        date: '2025-11-28',
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (_) {},
            onRedispositionMarker: (m) => tapped = m,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No nosebleeds'));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.aggregateId, 'P:2025-11-28');
      expect(tapped!.entryType, 'no_epistaxis_event');
    });

    testWidgets('displays Unknown event card correctly', (tester) async {
      final entry = buildDayMarkerView(
        aggregateId: 'test-1',
        date: '2025-11-28',
        entryType: 'unknown_day_event',
      );

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DateRecordsScreen(
            date: testDate,
            entries: [entry],
            onAddEvent: () {},
            onEditEvent: (_) {},
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('displays event count in subtitle', (tester) async {
      final entries = [
        buildEpistaxisView(
          aggregateId: 'test-1',
          startTime: DateTime(2025, 11, 28, 10, 30),
          endTime: DateTime(2025, 11, 28, 10, 45),
          intensity: NosebleedIntensity.dripping,
        ),
        buildEpistaxisView(
          aggregateId: 'test-2',
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
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 events'), findsOneWidget);
    });

    testWidgets('displays "1 event" for single entry', (tester) async {
      final entries = [
        buildEpistaxisView(
          aggregateId: 'test-1',
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
            onRedispositionMarker: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 event'), findsOneWidget);
    });
  });
}
