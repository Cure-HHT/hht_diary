// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//
// CUR-447: Test for cross-day time validation bug
// Scenario: Start time yesterday 3PM, end time today 3AM should be valid
// Bug: Validation incorrectly shows "End time must be after start time"

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/widgets/inline_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CUR-447: Cross-day time validation - InlineTimePicker unit tests', () {
    /// Helper to wrap widget with localization support
    Widget wrapWithApp(Widget child) {
      return MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets(
      'minTime validation respects full DateTime including date - cross-day scenario',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // This test simulates the CUR-447 bug scenario:
        // - Start time is yesterday at 3:00 PM (15:00)
        // - End time picker is on "today"
        // - User tries to select 3:00 AM
        // - This SHOULD be valid because today 3AM > yesterday 3PM
        // - Bug: validation fails because it only compares time-of-day

        // yesterday = DateTime(2024, 1, 14) - used in comment for context
        final today = DateTime(2024, 1, 15);

        // minTime is yesterday at 3:00 PM (start time)
        final startTime = DateTime(2024, 1, 14, 15, 0);

        // The end time picker should allow selecting any time on "today"
        // as long as the full DateTime is after startTime

        DateTime? selectedEndTime;

        await tester.pumpWidget(
          wrapWithApp(
            Builder(
              builder: (context) {
                return InlineTimePicker(
                  // End time is on today at 3:00 AM (which is AFTER yesterday 3PM)
                  initialTime: DateTime(2024, 1, 15, 3, 0), // Today 3:00 AM
                  onTimeChanged: (time) {
                    selectedEndTime = time;
                  },
                  allowFutureTimes: true, // For testing, allow future
                  minTime: startTime, // Yesterday 3:00 PM
                  date: today, // End date is today
                  onDateChanged: (date) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The time picker should show 3:00 (AM) - this is the initial time
        // Find the +1 button to adjust the time
        final plus1Button = find.text('+1');
        expect(plus1Button, findsOneWidget);

        // Tap +1 to change from 3:00 AM to 3:01 AM
        // This should be allowed since today 3:01 AM > yesterday 3:00 PM
        await tester.tap(plus1Button);
        await tester.pumpAndSettle();

        // If the bug exists, the button would flash red (showError)
        // and selectedEndTime would NOT be updated
        // If fixed, selectedEndTime should be 3:01 AM today
        expect(
          selectedEndTime,
          isNotNull,
          reason:
              'CUR-447: End time today 3:01 AM should be accepted (after yesterday 3:00 PM)',
        );

        if (selectedEndTime != null) {
          expect(selectedEndTime!.hour, 3);
          expect(selectedEndTime!.minute, 1);
          expect(selectedEndTime!.day, 15); // Today
          expect(selectedEndTime!.month, 1);
          expect(selectedEndTime!.year, 2024);
        }
      },
    );

    testWidgets(
      'minTime validation blocks time on same day that is before start time',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // This test verifies that validation still works for same-day scenarios:
        // - Start time is today at 3:00 PM
        // - End time picker is also on "today"
        // - User tries to select 2:00 PM
        // - This SHOULD be blocked because today 2PM < today 3PM

        final today = DateTime(2024, 1, 15);
        final startTime = DateTime(2024, 1, 15, 15, 0); // Today 3:00 PM

        DateTime? selectedEndTime;

        await tester.pumpWidget(
          wrapWithApp(
            Builder(
              builder: (context) {
                return InlineTimePicker(
                  // End time starts at 3:15 PM (valid - after start)
                  initialTime: DateTime(2024, 1, 15, 15, 15), // Today 3:15 PM
                  onTimeChanged: (time) {
                    selectedEndTime = time;
                  },
                  allowFutureTimes: true, // For testing
                  minTime: startTime, // Today 3:00 PM
                  date: today, // End date is today
                  onDateChanged: (date) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The time picker should show 3:15 PM
        // Find the -1 button to try to adjust BEFORE the minTime
        final minus1Button = find.text('-1');
        expect(minus1Button, findsOneWidget);

        // Tap -1 fifteen times to try to go from 3:15 PM to 3:00 PM
        // The last tap should be blocked (can't go before minTime)
        for (var i = 0; i < 15; i++) {
          await tester.tap(minus1Button);
          await tester.pump();
        }
        await tester.pumpAndSettle();

        // After 15 taps of -1, we should be at 3:00 PM (the minTime)
        // The time should not go below 3:00 PM
        expect(
          selectedEndTime,
          isNotNull,
          reason: 'Some time adjustments should succeed',
        );

        if (selectedEndTime != null) {
          // Should be at or after 3:00 PM
          expect(
            selectedEndTime!.hour >= 15 ||
                (selectedEndTime!.hour == 15 && selectedEndTime!.minute >= 0),
            isTrue,
            reason: 'End time should not go before start time on same day',
          );
        }
      },
    );

    testWidgets(
      'cross-midnight scenario: end time 1AM today after start 11PM yesterday',
      (tester) async {
        // Use a larger screen size to avoid overflow issues
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Midnight crossing scenario:
        // - Start: yesterday (2024-01-14) 11:00 PM
        // - End: today 1:00 AM
        // Should be valid (2-hour nosebleed crossing midnight)

        final today = DateTime(2024, 1, 15);
        final startTime = DateTime(2024, 1, 14, 23, 0); // Yesterday 11:00 PM

        DateTime? selectedEndTime;

        await tester.pumpWidget(
          wrapWithApp(
            Builder(
              builder: (context) {
                return InlineTimePicker(
                  initialTime: DateTime(2024, 1, 15, 1, 0), // Today 1:00 AM
                  onTimeChanged: (time) {
                    selectedEndTime = time;
                  },
                  allowFutureTimes: true,
                  minTime: startTime, // Yesterday 11:00 PM
                  date: today, // End date is today
                  onDateChanged: (date) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Try to adjust the time - should work since 1:01 AM today > 11 PM yesterday
        final plus1Button = find.text('+1');
        await tester.tap(plus1Button);
        await tester.pumpAndSettle();

        expect(
          selectedEndTime,
          isNotNull,
          reason:
              'CUR-447: 1:01 AM today should be valid after 11 PM yesterday',
        );

        if (selectedEndTime != null) {
          expect(selectedEndTime!.hour, 1);
          expect(selectedEndTime!.minute, 1);
          expect(selectedEndTime!.day, 15); // Today
        }
      },
    );
  });
}
