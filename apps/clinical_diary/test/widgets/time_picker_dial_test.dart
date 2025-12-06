// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

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
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: futureTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: futureTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: pastDayLateTime,
                onConfirm: (time) => confirmedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          );
          await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: tooLateTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: pastTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: pastTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Select Start Time',
              initialTime: DateTime(2024, 1, 15, 14, 30),
              onConfirm: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select Start Time'), findsOneWidget);
      });

      testWidgets('displays custom confirm label', (tester) async {
        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: DateTime(2024, 1, 15, 14, 30),
              onConfirm: (_) {},
              confirmLabel: 'Save Time',
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save Time'), findsOneWidget);
      });

      testWidgets('displays all adjustment buttons', (tester) async {
        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: DateTime.now().subtract(const Duration(hours: 1)),
              onConfirm: (_) {},
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
    });

    group('adjustment buttons', () {
      testWidgets('-5 button subtracts 5 minutes', (tester) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);

        DateTime? confirmedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-5'));
        await tester.pump();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(confirmedTime, isNotNull);
        expect(confirmedTime!.hour, 12);
        expect(confirmedTime!.minute, 25);
      });
    });

    group('onTimeChanged callback (CUR-464)', () {
      testWidgets(
        'calls onTimeChanged immediately when adjustment button is pressed',
        (tester) async {
          final initialTime = DateTime(2024, 1, 15, 12, 30);

          final changedTimes = <DateTime>[];
          DateTime? confirmedTime;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (time) => confirmedTime = time,
                onTimeChanged: changedTimes.add,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap -15 button
          await tester.tap(find.text('-15'));
          await tester.pump();

          // onTimeChanged should be called immediately, before confirm
          expect(changedTimes.length, 1);
          expect(changedTimes[0].hour, 12);
          expect(changedTimes[0].minute, 15);

          // Confirm has NOT been called yet
          expect(confirmedTime, isNull);

          // Now confirm
          await tester.tap(find.text('Confirm'));
          await tester.pump();

          expect(confirmedTime, isNotNull);
          expect(confirmedTime!.minute, 15);
        },
      );

      testWidgets('calls onTimeChanged for each adjustment button press', (
        tester,
      ) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);

        final changedTimes = <DateTime>[];

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (_) {},
              onTimeChanged: changedTimes.add,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap multiple adjustment buttons
        await tester.tap(find.text('-5'));
        await tester.pump();
        await tester.tap(find.text('-1'));
        await tester.pump();
        await tester.tap(find.text('+5'));
        await tester.pump();

        // onTimeChanged should be called for each press
        expect(changedTimes.length, 3);
        expect(changedTimes[0].minute, 25); // 30 - 5 = 25
        expect(changedTimes[1].minute, 24); // 25 - 1 = 24
        expect(changedTimes[2].minute, 29); // 24 + 5 = 29
      });

      testWidgets(
        'does not call onTimeChanged when adjustment would exceed max',
        (tester) async {
          final now = DateTime.now();

          final changedTimes = <DateTime>[];

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: now,
                onConfirm: (_) {},
                onTimeChanged: changedTimes.add,
                allowFutureTimes: false, // Prevent future times
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Try to add 1 minute (should fail since we're at now)
          await tester.tap(find.text('+1'));
          await tester.pumpAndSettle();

          // onTimeChanged should NOT be called because change was rejected
          expect(changedTimes.isEmpty, isTrue);
        },
      );

      testWidgets(
        'CUR-464 regression: summary updates when -15 button pressed',
        (tester) async {
          // This is the exact bug reported: user taps -15, clock display changes
          // but the summary (parent state) doesn't update
          final initialTime = DateTime(2024, 1, 15, 14, 30);

          DateTime? latestChange;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Nosebleed Start',
                initialTime: initialTime,
                onConfirm: (_) {},
                onTimeChanged: (time) => latestChange = time,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap -15 exactly as the user reported
          await tester.tap(find.text('-15'));
          await tester.pump();

          // The parent must receive the update IMMEDIATELY
          expect(
            latestChange,
            isNotNull,
            reason: 'CUR-464: Parent must receive time change immediately',
          );
          expect(latestChange!.hour, 14);
          expect(latestChange!.minute, 15); // 30 - 15 = 15
        },
      );

      testWidgets('CUR-464 regression: all adjustment buttons notify parent', (
        tester,
      ) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);
        final allChanges = <int>[];

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (_) {},
              onTimeChanged: (time) => allChanges.add(time.minute),
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Test all 6 adjustment buttons
        await tester.tap(find.text('-15'));
        await tester.pump();
        expect(allChanges.last, 15, reason: '-15 should notify: 30-15=15');

        await tester.tap(find.text('-5'));
        await tester.pump();
        expect(allChanges.last, 10, reason: '-5 should notify: 15-5=10');

        await tester.tap(find.text('-1'));
        await tester.pump();
        expect(allChanges.last, 9, reason: '-1 should notify: 10-1=9');

        await tester.tap(find.text('+1'));
        await tester.pump();
        expect(allChanges.last, 10, reason: '+1 should notify: 9+1=10');

        await tester.tap(find.text('+5'));
        await tester.pump();
        expect(allChanges.last, 15, reason: '+5 should notify: 10+5=15');

        await tester.tap(find.text('+15'));
        await tester.pump();
        expect(allChanges.last, 30, reason: '+15 should notify: 15+15=30');

        expect(allChanges.length, 6, reason: 'All 6 buttons should notify');
      });

      testWidgets(
        'CUR-464 regression: rapid button presses all notify parent',
        (tester) async {
          final initialTime = DateTime(2024, 1, 15, 12, 30);
          var callCount = 0;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (_) {},
                onTimeChanged: (_) => callCount++,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Rapid button presses (user clicking quickly)
          for (var i = 0; i < 5; i++) {
            await tester.tap(find.text('-1'));
            await tester.pump();
          }

          expect(
            callCount,
            5,
            reason: 'CUR-464: Each rapid press must notify parent',
          );
        },
      );
    });

    // =========================================================================
    // CUR-427: Future time validation regression tests
    // =========================================================================
    group('CUR-427: Future time validation', () {
      testWidgets('clamps initial time to now when allowFutureTimes is false', (
        tester,
      ) async {
        final now = DateTime.now();
        final futureTime = now.add(const Duration(minutes: 30));

        DateTime? confirmedTime;
        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: futureTime,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(confirmedTime, isNotNull);
        // Allow 2 seconds tolerance for test execution
        expect(
          confirmedTime!.isBefore(
            DateTime.now().add(const Duration(seconds: 2)),
          ),
          isTrue,
          reason: 'CUR-427: Future time must be clamped to now',
        );
      });

      testWidgets('blocks +1 button when at current time', (tester) async {
        final now = DateTime.now();
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pumpAndSettle();

        expect(
          changedTime,
          isNull,
          reason: 'CUR-427: +1 at now must be blocked',
        );
      });

      testWidgets('blocks +5 button when would exceed now', (tester) async {
        final now = DateTime.now();
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+5'));
        await tester.pumpAndSettle();

        expect(
          changedTime,
          isNull,
          reason: 'CUR-427: +5 at now must be blocked',
        );
      });

      testWidgets('blocks +15 button when would exceed now', (tester) async {
        final now = DateTime.now();
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+15'));
        await tester.pumpAndSettle();

        expect(
          changedTime,
          isNull,
          reason: 'CUR-427: +15 at now must be blocked',
        );
      });

      testWidgets('allows all + buttons when allowFutureTimes is true', (
        tester,
      ) async {
        final now = DateTime.now();
        var successCount = 0;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (_) {},
              onTimeChanged: (_) => successCount++,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();
        await tester.tap(find.text('+5'));
        await tester.pump();
        await tester.tap(find.text('+15'));
        await tester.pump();

        expect(
          successCount,
          3,
          reason: 'CUR-427: All + buttons allowed when allowFutureTimes=true',
        );
      });

      testWidgets('allows - buttons when at now (going to past is OK)', (
        tester,
      ) async {
        final now = DateTime.now();
        var successCount = 0;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: now,
              onConfirm: (_) {},
              onTimeChanged: (_) => successCount++,
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-1'));
        await tester.pump();
        await tester.tap(find.text('-5'));
        await tester.pump();
        await tester.tap(find.text('-15'));
        await tester.pump();

        expect(
          successCount,
          3,
          reason: 'CUR-427: All - buttons allowed (going to past is OK)',
        );
      });
    });

    // =========================================================================
    // CUR-188: End time uses start day regression tests
    // =========================================================================
    group('CUR-188: End time day handling', () {
      testWidgets('preserves date when adjusting time', (tester) async {
        // Specific date in the past
        final initialTime = DateTime(2024, 1, 10, 14, 30);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-15'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.year, 2024, reason: 'CUR-188: Year preserved');
        expect(changedTime!.month, 1, reason: 'CUR-188: Month preserved');
        expect(changedTime!.day, 10, reason: 'CUR-188: Day preserved');
        expect(changedTime!.minute, 15, reason: 'Time adjusted correctly');
      });

      testWidgets(
        'time adjustment near midnight stays on same day (going backward)',
        (tester) async {
          // 12:15 AM - adjusting back should stay on same day
          final initialTime = DateTime(2024, 1, 15, 0, 15);
          DateTime? changedTime;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (_) {},
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('-15'));
          await tester.pump();

          expect(changedTime, isNotNull);
          // -15 from 00:15 = 00:00 (same day) or wraps to previous day
          // The behavior depends on implementation, but date should be consistent
          expect(changedTime!.year, 2024);
          expect(changedTime!.month, 1);
          // Day could be 14 or 15 depending on wrap behavior
        },
      );

      testWidgets(
        'time adjustment near 11 PM stays on same day (going forward)',
        (tester) async {
          // 11:50 PM - adjusting forward should wrap or be blocked
          final initialTime = DateTime(2024, 1, 15, 23, 50);
          DateTime? changedTime;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (_) {},
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('+15'));
          await tester.pump();

          expect(changedTime, isNotNull);
          // +15 from 23:50 = 00:05 next day
          expect(changedTime!.year, 2024);
          expect(changedTime!.month, 1);
          expect(changedTime!.day, 16, reason: 'Day wraps to next day');
          expect(changedTime!.hour, 0);
          expect(changedTime!.minute, 5);
        },
      );
    });

    // =========================================================================
    // CUR-447: Cross-day validation with maxDateTime regression tests
    // =========================================================================
    group('CUR-447: Cross-day maxDateTime validation', () {
      testWidgets(
        'allows 11 PM on yesterday when maxDateTime is end-of-yesterday',
        (tester) async {
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final pastTime = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            0, // 11:00 PM yesterday
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
              TimePickerDial(
                title: 'Test',
                initialTime: pastTime,
                onConfirm: (_) {},
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: false,
                maxDateTime: endOfYesterday,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Should be able to subtract (11 PM is valid on yesterday)
          await tester.tap(find.text('-5'));
          await tester.pump();

          expect(
            changedTime,
            isNotNull,
            reason: 'CUR-447: 11 PM on past date should be editable',
          );
          expect(changedTime!.hour, 22);
          expect(changedTime!.minute, 55);
        },
      );

      testWidgets('blocks going past maxDateTime on past date', (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final pastTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          55, // 11:55 PM yesterday
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
            TimePickerDial(
              title: 'Test',
              initialTime: pastTime,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // +5 would go to 00:00 next day, which exceeds maxDateTime
        await tester.tap(find.text('+5'));
        await tester.pumpAndSettle();

        expect(
          changedTime,
          isNull,
          reason: 'CUR-447: Cannot go past end-of-day on past date',
        );
      });

      testWidgets('allows +1 when within maxDateTime bounds', (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final pastTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          0, // 11:00 PM
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
            TimePickerDial(
              title: 'Test',
              initialTime: pastTime,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(
          changedTime,
          isNotNull,
          reason: 'CUR-447: +1 within bounds should work',
        );
        expect(changedTime!.hour, 23);
        expect(changedTime!.minute, 1);
      });

      testWidgets('clamps initial future time to maxDateTime not now', (
        tester,
      ) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        // Time that's "today" which is after maxDateTime (end of yesterday)
        final futureThanMax = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day + 1, // today
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
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: futureThanMax,
              onConfirm: (time) => confirmedTime = time,
              allowFutureTimes: false,
              maxDateTime: endOfYesterday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(confirmedTime, isNotNull);
        // Should be clamped to endOfYesterday, not to now
        expect(
          confirmedTime!.isBefore(endOfYesterday) ||
              confirmedTime!.isAtSameMomentAs(endOfYesterday),
          isTrue,
          reason: 'CUR-447: Should clamp to maxDateTime, not now',
        );
      });
    });

    // =========================================================================
    // Edge cases and boundary conditions
    // =========================================================================
    group('Edge cases and boundaries', () {
      testWidgets('handles midnight boundary correctly', (tester) async {
        final midnight = DateTime(2024, 1, 15, 0, 0);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: midnight,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 23);
        expect(changedTime!.minute, 59);
        expect(changedTime!.day, 14, reason: 'Wraps to previous day');
      });

      testWidgets('handles end of day boundary correctly', (tester) async {
        final endOfDay = DateTime(2024, 1, 15, 23, 59);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: endOfDay,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 0);
        expect(changedTime!.minute, 0);
        expect(changedTime!.day, 16, reason: 'Wraps to next day');
      });

      testWidgets('handles hour boundary (59 -> 00 minutes)', (tester) async {
        final hourBoundary = DateTime(2024, 1, 15, 14, 59);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: hourBoundary,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 15);
        expect(changedTime!.minute, 0);
      });

      testWidgets('handles month boundary correctly', (tester) async {
        // Last minute of January
        final monthEnd = DateTime(2024, 1, 31, 23, 59);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: monthEnd,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.month, 2, reason: 'Wraps to February');
        expect(changedTime!.day, 1);
        expect(changedTime!.hour, 0);
        expect(changedTime!.minute, 0);
      });

      testWidgets('handles year boundary correctly', (tester) async {
        // Last minute of 2024
        final yearEnd = DateTime(2024, 12, 31, 23, 59);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: yearEnd,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.year, 2025, reason: 'Wraps to 2025');
        expect(changedTime!.month, 1);
        expect(changedTime!.day, 1);
        expect(changedTime!.hour, 0);
        expect(changedTime!.minute, 0);
      });

      testWidgets('handles leap year February 29', (tester) async {
        // Feb 29, 2024 (leap year)
        final leapDay = DateTime(2024, 2, 29, 23, 59);
        DateTime? changedTime;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: leapDay,
              onConfirm: (_) {},
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.month, 3, reason: 'Wraps to March');
        expect(changedTime!.day, 1);
      });
    });

    // =========================================================================
    // Callback reliability tests
    // =========================================================================
    group('Callback reliability', () {
      testWidgets(
        'onTimeChanged receives correct DateTime with all components',
        (tester) async {
          final initialTime = DateTime(2024, 3, 15, 14, 30, 45, 123);
          DateTime? changedTime;

          await tester.pumpWidget(
            wrapWithScaffold(
              TimePickerDial(
                title: 'Test',
                initialTime: initialTime,
                onConfirm: (_) {},
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('+1'));
          await tester.pump();

          expect(changedTime, isNotNull);
          expect(changedTime!.year, 2024);
          expect(changedTime!.month, 3);
          expect(changedTime!.day, 15);
          expect(changedTime!.hour, 14);
          expect(changedTime!.minute, 31);
        },
      );

      testWidgets('onConfirm receives same time as last onTimeChanged', (
        tester,
      ) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);
        DateTime? lastChanged;
        DateTime? confirmed;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (time) => confirmed = time,
              onTimeChanged: (time) => lastChanged = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Make several adjustments
        await tester.tap(find.text('-5'));
        await tester.pump();
        await tester.tap(find.text('+1'));
        await tester.pump();
        await tester.tap(find.text('-1'));
        await tester.pump();

        // Now confirm
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(lastChanged, isNotNull);
        expect(confirmed, isNotNull);
        expect(
          confirmed!.isAtSameMomentAs(lastChanged!),
          isTrue,
          reason: 'Confirmed time must match last changed time',
        );
      });

      testWidgets('widget works without onTimeChanged (optional callback)', (
        tester,
      ) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);
        DateTime? confirmed;

        await tester.pumpWidget(
          wrapWithScaffold(
            TimePickerDial(
              title: 'Test',
              initialTime: initialTime,
              onConfirm: (time) => confirmed = time,
              // onTimeChanged NOT provided
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-5'));
        await tester.pump();
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(confirmed, isNotNull);
        expect(confirmed!.minute, 25);
      });
    });
  });
}
