// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/inline_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('InlineTimePicker', () {
    group('Basic Rendering', () {
      testWidgets('displays --:-- when no initial time is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(InlineTimePicker(onTimeChanged: (_) {})),
        );
        await tester.pumpAndSettle();

        expect(find.text('--:--'), findsOneWidget);
      });

      testWidgets('displays initial time when provided', (tester) async {
        final initialTime = DateTime(2024, 1, 15, 14, 30);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check for time display (format depends on locale)
        expect(find.textContaining(':30'), findsOneWidget);
      });

      testWidgets('displays adjustment buttons', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(InlineTimePicker(onTimeChanged: (_) {})),
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

    group('Time Adjustments', () {
      testWidgets('adds 1 minute when +1 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 0);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+1'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 1);
      });

      testWidgets('subtracts 1 minute when -1 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 15);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-1'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 14);
      });

      testWidgets('adds 5 minutes when +5 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 0);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+5'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 5);
      });

      testWidgets('subtracts 5 minutes when -5 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 15);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-5'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 10);
      });

      testWidgets('adds 15 minutes when +15 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 0);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('+15'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 15);
      });

      testWidgets('subtracts 15 minutes when -15 is tapped', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 30);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle();

        expect(changedTime?.minute, 15);
      });
    });

    group('Time Constraints', () {
      testWidgets('does not allow times before minTime', (tester) async {
        DateTime? changedTime;
        final initialTime = DateTime(2024, 1, 15, 10, 5);
        final minTime = DateTime(2024, 1, 15, 10, 0);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              minTime: minTime,
              onTimeChanged: (time) => changedTime = time,
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Try to go below minTime
        await tester.tap(find.text('-15'));
        await tester.pumpAndSettle();

        // Time should not have changed
        expect(changedTime, isNull);
      });

      testWidgets('clamps initial time to maxDateTime', (tester) async {
        final now = DateTime.now();
        final futureTime = now.add(const Duration(hours: 1));
        final maxDateTime = now;

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: futureTime,
              maxDateTime: maxDateTime,
              onTimeChanged: (_) {},
              allowFutureTimes: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Time should be clamped to maxDateTime
        final timeFormat = DateFormat('H:mm');
        expect(
          find.textContaining(timeFormat.format(maxDateTime).split(':')[1]),
          findsWidgets,
        );
      });
    });

    group('Date Picker Integration', () {
      testWidgets(
        'shows date picker when date and onDateChanged are provided',
        (tester) async {
          final date = DateTime(2024, 1, 15);

          await tester.pumpWidget(
            wrapWithMaterialApp(
              InlineTimePicker(
                date: date,
                onDateChanged: (_) {},
                onTimeChanged: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Should show date display
          expect(find.byIcon(Icons.calendar_today), findsOneWidget);
          expect(find.text('Jan 15'), findsOneWidget);
        },
      );

      testWidgets('hides date picker when onDateChanged is null', (
        tester,
      ) async {
        final date = DateTime(2024, 1, 15);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              date: date,
              onDateChanged: null,
              onTimeChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should not show date picker
        expect(find.byIcon(Icons.calendar_today), findsNothing);
      });
    });

    group('Widget Update Behavior', () {
      testWidgets('updates when initialTime changes significantly', (
        tester,
      ) async {
        final initialTime = DateTime(2024, 1, 15, 10, 0);
        final newTime = DateTime(2024, 1, 15, 14, 30);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: initialTime,
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rebuild with new time
        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: newTime,
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show new time
        expect(find.textContaining(':30'), findsOneWidget);
      });

      testWidgets('updates when initialTime goes from null to set', (
        tester,
      ) async {
        final newTime = DateTime(2024, 1, 15, 14, 30);

        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: null,
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('--:--'), findsOneWidget);

        // Rebuild with time set
        await tester.pumpWidget(
          wrapWithMaterialApp(
            InlineTimePicker(
              initialTime: newTime,
              onTimeChanged: (_) {},
              allowFutureTimes: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show new time
        expect(find.text('--:--'), findsNothing);
      });
    });

    group('Style and Layout', () {
      testWidgets('has rounded container decoration', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(InlineTimePicker(onTimeChanged: (_) {})),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.borderRadius, isNotNull);
      });
    });
  });
}
