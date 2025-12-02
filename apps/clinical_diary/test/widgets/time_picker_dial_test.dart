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
