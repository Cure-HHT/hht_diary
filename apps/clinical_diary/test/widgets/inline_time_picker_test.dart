// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/inline_time_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('InlineTimePicker', () {
    group('null/unset state', () {
      testWidgets('displays --:-- when initialTime is null', (tester) async {
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(initialTime: null, onTimeChanged: (_) {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('--:--'), findsOneWidget);
        expect(find.text('--'), findsOneWidget);
      });

      testWidgets('displays time when initialTime is provided', (tester) async {
        final testTime = DateTime(2024, 1, 15, 14, 30);

        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: testTime,
              onTimeChanged: (_) {},
              allowFutureTimes: true, // Allow any time for this test
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 2:30 PM format
        expect(find.text('2:30'), findsOneWidget);
        expect(find.text('PM'), findsOneWidget);
      });
    });

    group('future time prevention', () {
      testWidgets(
        'clamps future initialTime to now when allowFutureTimes is false',
        (tester) async {
          // Set up a time 30 minutes in the future
          final now = DateTime.now();
          final futureTime = now.add(const Duration(minutes: 30));

          DateTime? changedTime;
          await tester.pumpWidget(
            wrapWithScaffold(
              InlineTimePicker(
                initialTime: futureTime,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // The displayed time should NOT be the future time
          // Instead it should be clamped to approximately now
          // We check this by tapping the -1 button (which should work since we're at now)
          await tester.tap(find.text('-1'));
          await tester.pump();

          // If future time was clamped to now, subtracting 1 minute should work
          // and call onTimeChanged
          expect(changedTime, isNotNull);
          expect(changedTime!.isBefore(now), isTrue);
        },
      );

      testWidgets('prevents +1 button from setting future time', (
        tester,
      ) async {
        final now = DateTime.now();

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: now,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Try to add 1 minute (should fail since we're at now)
        await tester.tap(find.text('+1'));
        await tester.pumpAndSettle(); // Wait for error flash timer

        // onTimeChanged should NOT be called because future time is rejected
        expect(changedTime, isNull);
      });

      testWidgets('allows future time when allowFutureTimes is true', (
        tester,
      ) async {
        final now = DateTime.now();
        final futureTime = now.add(const Duration(hours: 1));

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: futureTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Adding more time should work
        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.isAfter(futureTime), isTrue);
      });
    });

    group('minTime enforcement', () {
      testWidgets('prevents time before minTime', (tester) async {
        final now = DateTime.now();
        final startTime = now.subtract(const Duration(minutes: 30));
        final minTime = now.subtract(const Duration(minutes: 15));

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: startTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
              minTime: minTime,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Try to go 15 minutes earlier (would violate minTime)
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle(); // Wait for error flash timer

        // Should be rejected
        expect(changedTime, isNull);
      });
    });

    group('maxDateTime parameter (CUR-447)', () {
      testWidgets(
        'allows any time on past date when maxDateTime is set to end-of-day',
        (tester) async {
          // Simulate editing a past date (yesterday at 11 PM)
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final pastDayLateTime = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            0,
          );
          // Max is end of yesterday
          final endOfYesterday = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            59,
            59,
          );

          DateTime? changedTime;
          await tester.pumpWidget(
            wrapWithScaffold(
              InlineTimePicker(
                initialTime: pastDayLateTime,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Subtracting time should work since 11 PM is valid
          await tester.tap(find.text('-5'));
          await tester.pump();

          expect(changedTime, isNotNull);
          expect(changedTime!.hour, 22);
          expect(changedTime!.minute, 55);
        },
      );

      testWidgets('clamps initial time to maxDateTime instead of now', (
        tester,
      ) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        // Time that exceeds end of yesterday
        final tooLateTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day + 1, // Actually today
          2,
          0,
        );
        final endOfYesterday = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: tooLateTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Subtracting time should work (we're clamped to end of yesterday)
        await tester.tap(find.text('-1'));
        await tester.pump();

        // Should be clamped to end of yesterday minus 1 minute
        expect(changedTime, isNotNull);
        expect(changedTime!.isBefore(endOfYesterday), isTrue);
      });

      testWidgets('prevents +15 button when it would exceed maxDateTime', (
        tester,
      ) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        // Start at 11:50 PM yesterday
        final pastTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          50,
        );
        final endOfYesterday = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: pastTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Try to add 15 minutes - this would exceed maxDateTime
        await tester.tap(find.text('+15'));
        await tester.pumpAndSettle();

        // Should be rejected
        expect(changedTime, isNull);
      });

      testWidgets('allows +5 button on past date when within maxDateTime', (
        tester,
      ) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        // Start at 11:00 PM yesterday
        final pastTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          0,
        );
        final endOfYesterday = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: pastTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Add 5 minutes - should work since 11:05 PM < 11:59:59 PM
        await tester.tap(find.text('+5'));
        await tester.pump();

        // Time should be 11:05 PM
        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 23);
        expect(changedTime!.minute, 5);
      });
    });

    group('cross-day validation (CUR-447)', () {
      testWidgets(
        'allows end time on future date when minTime is on past date',
        (tester) async {
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final today = DateTime.now();

          // Start time is yesterday at 11 PM
          final startTime = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            0,
          );

          // End date is today (via widget.date)
          final endDate = DateTime(today.year, today.month, today.day);

          // Max is end of today
          final endOfToday = DateTime(
            today.year,
            today.month,
            today.day,
            23,
            59,
            59,
          );

          DateTime? changedTime;
          await tester.pumpWidget(
            wrapWithScaffold(
              InlineTimePicker(
                initialTime: null, // End time not set yet
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: false,
                minTime: startTime, // Yesterday 11 PM
                maxDateTime: endOfToday,
                date: endDate, // Today
                onDateChanged: (_) {}, // Allow date changes
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Add 1 minute - should use today's date context (from widget.date)
          // not yesterday's date (from minTime)
          await tester.tap(find.text('+1'));
          await tester.pump();

          // Should succeed and use today's date
          expect(changedTime, isNotNull);
          expect(changedTime!.year, today.year);
          expect(changedTime!.month, today.month);
          expect(changedTime!.day, today.day);
          // Time should be current hour + 1 minute (approximately)
          expect(changedTime!.isAfter(startTime), isTrue);
        },
      );
    });

    group('adjustment buttons', () {
      testWidgets('displays all adjustment buttons', (tester) async {
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: DateTime.now().subtract(const Duration(hours: 1)),
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('-15'), findsOneWidget);
        expect(find.text('-5'), findsOneWidget);
        expect(find.text('-1'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(find.text('+15'), findsOneWidget);
      });

      testWidgets('-5 button subtracts 5 minutes', (tester) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);

        DateTime? changedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-5'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 12);
        expect(changedTime!.minute, 25);
      });
    });
  });
}
