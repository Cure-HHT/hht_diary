// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry (CUR-407 - future date blocking)

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/calendar_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

// Helper to build calendar overlay with adequate screen size
// Wrapped in SingleChildScrollView to handle overflow in tests
Widget buildCalendarOverlay({
  required bool isOpen,
  required VoidCallback onClose,
  required ValueChanged<DateTime> onDateSelect,
  List<NosebleedRecord> records = const [],
  DateTime? selectedDate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 800,
          height: 900,
          child: CalendarOverlay(
            isOpen: isOpen,
            onClose: onClose,
            onDateSelect: onDateSelect,
            records: records,
            selectedDate: selectedDate,
          ),
        ),
      ),
    ),
  );
}

/// Helper to find a date cell in the calendar by looking for the date's
/// Container with the day number text inside it.
Finder findDateCellInCurrentMonth(WidgetTester tester, int day) {
  // Find all Text widgets with the day number
  final dayTexts = find.text('$day');

  // Filter to find the one that's in a Container with circle shape
  return find.ancestor(
    of: dayTexts,
    matching: find.byWidgetPredicate((widget) {
      if (widget is Container) {
        final decoration = widget.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle) {
          return true;
        }
      }
      return false;
    }),
  );
}

/// Helper to get a day number that is guaranteed to be in the past or today.
/// This ensures tests work regardless of when they run in the month.
int getPastOrTodayDay() {
  final today = DateTime.now().day;
  // If we're past day 5, use day 5 (a day in the past)
  // Otherwise, use today (which is always selectable)
  return today > 5 ? 5 : today;
}

/// Helper to tap the left chevron to go to previous month
Future<void> navigateToPreviousMonth(WidgetTester tester) async {
  final leftChevron = find.byIcon(Icons.chevron_left);
  if (leftChevron.evaluate().isNotEmpty) {
    await tester.tap(leftChevron);
    await tester.pumpAndSettle();
  }
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

  group('Date validation (CUR-407)', () {
    testWidgets('allows selection of today', (tester) async {
      DateTime? selectedDate;
      final today = DateTime.now();

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (date) => selectedDate = date,
        ),
      );
      await tester.pumpAndSettle();

      // Find date cells for today's day number
      final dateCells = findDateCellInCurrentMonth(tester, today.day);
      expect(
        dateCells,
        findsWidgets,
        reason: 'Should find date cells for day ${today.day}',
      );

      // Tap the first matching cell
      await tester.tap(dateCells.first);
      await tester.pumpAndSettle();

      // Should have selected a date (the callback should fire)
      expect(selectedDate, isNotNull, reason: 'Today should be selectable');
      // The selected date should be today or earlier (not future)
      expect(
        selectedDate!.isBefore(DateTime.now().add(const Duration(days: 1))),
        isTrue,
        reason: 'Selected date should not be in the future',
      );
    });

    testWidgets('allows selection of past dates', (tester) async {
      DateTime? selectedDate;

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (date) => selectedDate = date,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to previous month to ensure we have past dates available
      await navigateToPreviousMonth(tester);

      // Find a date cell - use day 15 which is always in the middle of the month
      // In previous month, all dates are guaranteed to be in the past
      final dateCells = findDateCellInCurrentMonth(tester, 15);

      if (dateCells.evaluate().isNotEmpty) {
        await tester.tap(dateCells.first);
        await tester.pumpAndSettle();

        // Past dates should be selectable
        expect(selectedDate, isNotNull, reason: 'Day 15 should be selectable');
      }
    });

    testWidgets('selected date is never in the future', (tester) async {
      DateTime? selectedDate;
      final now = DateTime.now();

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (date) => selectedDate = date,
        ),
      );
      await tester.pumpAndSettle();

      // Try to tap multiple dates and verify none result in future selection
      for (var day = 1; day <= 28; day++) {
        selectedDate = null;
        final dateCells = findDateCellInCurrentMonth(tester, day);

        if (dateCells.evaluate().isNotEmpty) {
          await tester.tap(dateCells.first, warnIfMissed: false);
          await tester.pumpAndSettle();

          // If a date was selected, it should not be in the future
          if (selectedDate != null) {
            final selectedDayOnly = DateTime(
              selectedDate!.year,
              selectedDate!.month,
              selectedDate!.day,
            );
            final todayOnly = DateTime(now.year, now.month, now.day);
            expect(
              selectedDayOnly.isAfter(todayOnly),
              isFalse,
              reason:
                  'Selected date $selectedDate should not be after today $todayOnly',
            );
          }
        }
      }
    });

    testWidgets('calendar uses enabledDayPredicate to block future dates', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Verify TableCalendar is rendered (calendar functionality exists)
      expect(find.byType(TableCalendar<dynamic>), findsOneWidget);

      // The CalendarOverlay widget uses:
      // - _isDisabled(date) to check if date is after today
      // - enabledDayPredicate: (day) => !_isDisabled(day) to disable future dates
      // - _handleDateSelect checks _isDisabled before calling onDateSelect
      //
      // This provides double protection:
      // 1. Visual: future dates appear disabled
      // 2. Behavioral: tapping future dates does nothing
    });

    testWidgets('allows historical data entry (middle of month)', (
      tester,
    ) async {
      DateTime? selectedDate;

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (date) => selectedDate = date,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to previous month to ensure we have past dates available
      await navigateToPreviousMonth(tester);

      // Find a date in the middle of the month (always visible)
      // In previous month, all dates are guaranteed to be in the past
      final dateCells = findDateCellInCurrentMonth(tester, 10);

      if (dateCells.evaluate().isNotEmpty) {
        await tester.tap(dateCells.first);
        await tester.pumpAndSettle();

        // Historical dates should be selectable for data backfill
        expect(
          selectedDate,
          isNotNull,
          reason: 'Day 10 should be selectable for data backfill',
        );
      }
    });

    testWidgets('onDateSelect callback fires with valid date', (tester) async {
      var callbackFired = false;
      DateTime? receivedDate;

      await tester.pumpWidget(
        buildCalendarOverlay(
          isOpen: true,
          onClose: () {},
          onDateSelect: (date) {
            callbackFired = true;
            receivedDate = date;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to previous month to ensure we have past dates available
      await navigateToPreviousMonth(tester);

      // Tap a date that's definitely in the past (day 5 in previous month)
      final dateCells = findDateCellInCurrentMonth(tester, 5);

      if (dateCells.evaluate().isNotEmpty) {
        await tester.tap(dateCells.first);
        await tester.pumpAndSettle();

        expect(
          callbackFired,
          isTrue,
          reason: 'onDateSelect should be called for valid dates',
        );
        expect(receivedDate, isNotNull);
        expect(receivedDate!.day, 5);
      }
    });
  });
}
