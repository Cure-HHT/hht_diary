// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/inline_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InlineTimePicker', () {
    group('null/unset state', () {
      testWidgets('displays --:-- when initialTime is null', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(initialTime: null, onTimeChanged: (_) {}),
            ),
          ),
        );

        expect(find.text('--:--'), findsOneWidget);
        expect(find.text('--'), findsOneWidget);
      });

      testWidgets('displays time when initialTime is provided', (tester) async {
        final testTime = DateTime(2024, 1, 15, 14, 30);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: testTime,
                onTimeChanged: (_) {},
                allowFutureTimes: true, // Allow any time for this test
              ),
            ),
          ),
        );

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
            MaterialApp(
              home: Scaffold(
                body: InlineTimePicker(
                  initialTime: futureTime,
                  onTimeChanged: (time) => changedTime = time,
                  allowFutureTimes: false,
                ),
              ),
            ),
          );

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
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: now,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: false,
              ),
            ),
          ),
        );

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
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: futureTime,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
              ),
            ),
          ),
        );

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
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: startTime,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
                minTime: minTime,
              ),
            ),
          ),
        );

        // Try to go 15 minutes earlier (would violate minTime)
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle(); // Wait for error flash timer

        // Should be rejected
        expect(changedTime, isNull);
      });
    });

    group('adjustment buttons', () {
      testWidgets('displays all adjustment buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: DateTime.now().subtract(const Duration(hours: 1)),
                onTimeChanged: (_) {},
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

      testWidgets('-5 button subtracts 5 minutes', (tester) async {
        final initialTime = DateTime(2024, 1, 15, 12, 30);

        DateTime? changedTime;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineTimePicker(
                initialTime: initialTime,
                onTimeChanged: (time) => changedTime = time,
                allowFutureTimes: true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('-5'));
        await tester.pump();

        expect(changedTime, isNotNull);
        expect(changedTime!.hour, 12);
        expect(changedTime!.minute, 25);
      });
    });
  });
}
