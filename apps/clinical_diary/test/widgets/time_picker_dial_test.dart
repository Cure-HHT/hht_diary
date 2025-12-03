// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimePickerDial', () {
    group('future time prevention', () {
      testWidgets(
        'clamps future initialTime to now when allowFutureTimes is false',
        (tester) async {
          final now = DateTime.now();
          final futureTime = now.add(const Duration(minutes: 30));

          DateTime? confirmedTime;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TimePickerDial(
                  title: 'Test',
                  initialTime: futureTime,
                  onConfirm: (time) => confirmedTime = time,
                  allowFutureTimes: false,
                ),
              ),
            ),
          );

          // Tap confirm immediately
          await tester.tap(find.text('Confirm'));
          await tester.pump();

          // The confirmed time should be clamped to now or earlier
          expect(confirmedTime, isNotNull);
          // Allow 2 seconds tolerance for test execution time
          final twoSecondsFromNow = DateTime.now().add(
            const Duration(seconds: 2),
          );
          expect(confirmedTime!.isBefore(twoSecondsFromNow), isTrue);
        },
      );

      testWidgets('prevents +1 button from setting future time', (
        tester,
      ) async {
        final now = DateTime.now();

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: now,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
              ),
            ),
          ),
        );

        // Try to add 1 minute - should show error flash
        await tester.tap(find.text('+1'));
        await tester.pumpAndSettle(); // Wait for error flash timer

        // Confirm to check the time
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        // Time should still be at now, not +1 minute
        expect(confirmedTime, isNotNull);
        final twoSecondsFromNow = DateTime.now().add(
          const Duration(seconds: 2),
        );
        expect(confirmedTime!.isBefore(twoSecondsFromNow), isTrue);
      });

      testWidgets('allows future time when allowFutureTimes is true', (
        tester,
      ) async {
        final now = DateTime.now();
        final futureTime = now.add(const Duration(hours: 1));

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: futureTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        // Future time should be allowed
        expect(confirmedTime, isNotNull);
        expect(confirmedTime!.isAfter(now), isTrue);
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

          DateTime? confirmedTime;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TimePickerDial(
                  title: 'Test',
                  initialTime: pastDayLateTime,
                  onConfirm: (time) => confirmedTime = time,
                  allowFutureTimes: false,
                  maxDateTime: endOfYesterday,
                ),
              ),
            ),
          );

          // Confirm the time - it should be allowed even though 11 PM might be
          // "later" than the current time of day
          await tester.tap(find.text('Confirm'));
          await tester.pump();

          expect(confirmedTime, isNotNull);
          expect(confirmedTime!.hour, 23);
          expect(confirmedTime!.minute, 0);
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

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: tooLateTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        // Should be clamped to end of yesterday
        expect(confirmedTime, isNotNull);
        expect(
          confirmedTime!.isBefore(endOfYesterday) ||
              confirmedTime!.isAtSameMomentAs(endOfYesterday),
          isTrue,
        );
      });

      testWidgets('blocks +15 button when it would exceed maxDateTime', (
        tester,
      ) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        // Start at 11:50 PM yesterday - adding 15 would exceed max
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

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: pastTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          ),
        );

        // Try to add 15 minutes - this would exceed maxDateTime (12:05 AM > 11:59:59 PM)
        await tester.tap(find.text('+15'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        // Time should still be at 11:50 PM since +15 would exceed max
        expect(confirmedTime, isNotNull);
        expect(confirmedTime!.hour, 23);
        expect(confirmedTime!.minute, 50);
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

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: pastTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          ),
        );

        // Add 5 minutes - should work since 11:05 PM < 11:59:59 PM
        await tester.tap(find.text('+5'));
        await tester.pump();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        // Time should be 11:05 PM
        expect(confirmedTime, isNotNull);
        expect(confirmedTime!.hour, 23);
        expect(confirmedTime!.minute, 5);
      });
    });

    group('UI elements', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Select Start Time',
                initialTime: DateTime(2024, 1, 15, 14, 30),
                onConfirm: (_) {},
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        expect(find.text('Select Start Time'), findsOneWidget);
      });

      testWidgets('displays custom confirm label', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: DateTime(2024, 1, 15, 14, 30),
                onConfirm: (_) {},
                confirmLabel: 'Save Time',
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        expect(find.text('Save Time'), findsOneWidget);
      });

      testWidgets('displays all adjustment buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: DateTime.now().subtract(const Duration(hours: 1)),
                onConfirm: (_) {},
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        expect(find.text('-15'), findsOneWidget);
        expect(find.text('-5'), findsOneWidget);
        expect(find.text('-1'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(find.text('+15'), findsOneWidget);
      });
    });

    group('adjustment buttons', () {
      testWidgets('-5 button subtracts 5 minutes', (tester) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);

        DateTime? confirmedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('-5'));
        await tester.pump();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(confirmedTime, isNotNull);
        expect(confirmedTime!.hour, 12);
        expect(confirmedTime!.minute, 25);
      });
    });
  });
}
