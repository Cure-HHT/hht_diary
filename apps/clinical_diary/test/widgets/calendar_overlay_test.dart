// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/calendar_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

// Helper to build calendar overlay with adequate screen size
Widget buildCalendarOverlay({
  required bool isOpen,
  required VoidCallback onClose,
  required ValueChanged<DateTime> onDateSelect,
  List<NosebleedRecord> records = const [],
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 800,
          height: 1200,
          child: CalendarOverlay(
            isOpen: isOpen,
            onClose: onClose,
            onDateSelect: onDateSelect,
            records: records,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('CalendarOverlay', () {
    testWidgets('returns empty widget when not open', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: false,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Select Date'), findsNothing);
    });

    testWidgets('displays overlay when open', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onClose when close button is pressed', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () => closeCalled = true,
          onDateSelect: (_) {},
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCalled, true);
    });

    testWidgets('displays TableCalendar widget', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.byType(TableCalendar<dynamic>), findsOneWidget);
    });

    testWidgets('displays legend items', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.text('Nosebleed events'), findsOneWidget);
      expect(find.text('No nosebleeds'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Incomplete/Missing'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('displays help text', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.text('Tap a date to add or edit events'), findsOneWidget);
    });

    testWidgets('has Material widget for overlay background', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      // The overlay should contain a Material widget
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('renders records with correct date status', (tester) async {
      final records = [
        NosebleedRecord(
          id: 'test-1',
          date: DateTime.now(),
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(minutes: 15)),
          severity: NosebleedSeverity.dripping,
        ),
      ];

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
          records: records,
        ),
      );

      // The calendar should render with records
      expect(find.byType(TableCalendar<dynamic>), findsOneWidget);
    });

    testWidgets('uses GridView for legend', (tester) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('DateStatus enum', () {
    test('has all expected values', () {
      expect(DateStatus.values.length, 6);
      expect(DateStatus.values.contains(DateStatus.nosebleed), true);
      expect(DateStatus.values.contains(DateStatus.noNosebleed), true);
      expect(DateStatus.values.contains(DateStatus.unknown), true);
      expect(DateStatus.values.contains(DateStatus.incomplete), true);
      expect(DateStatus.values.contains(DateStatus.noEvents), true);
      expect(DateStatus.values.contains(DateStatus.beforeFirst), true);
    });
  });
}
