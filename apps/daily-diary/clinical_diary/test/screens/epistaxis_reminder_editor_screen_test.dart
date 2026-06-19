// Verifies: DIARY-PRD-notification-ongoing-epistaxis/H — the participant can add,
//   remove, and adjust intervals in the personal Reminder Schedule editor.
import 'package:clinical_diary/screens/epistaxis_reminder_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, List<int> initial) async {
  await tester.pumpWidget(
    MaterialApp(home: EpistaxisReminderEditorScreen(initialMinutes: initial)),
  );
}

void main() {
  testWidgets('renders one row per interval with its minutes', (tester) async {
    await _pump(tester, const [5, 10]);
    expect(find.text('Reminder 1'), findsOneWidget);
    expect(find.text('Reminder 2'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('add reminder appends a new interval', (tester) async {
    await _pump(tester, const [5]);
    expect(find.text('Reminder 2'), findsNothing);
    await tester.tap(find.text('Add reminder'));
    await tester.pump();
    expect(find.text('Reminder 2'), findsOneWidget);
  });

  testWidgets('remove deletes the interval', (tester) async {
    await _pump(tester, const [5, 10]);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pump();
    expect(find.text('Reminder 2'), findsNothing);
  });

  testWidgets('increase/decrease adjusts the minutes within bounds', (
    tester,
  ) async {
    await _pump(tester, const [5]);
    await tester.tap(find.byTooltip('Increase'));
    await tester.pump();
    expect(find.text('6 min'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease'));
    await tester.pump();
    expect(find.text('5 min'), findsOneWidget);
  });

  testWidgets('empty schedule shows the off message and can be reset', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.textContaining('Reminders are off'), findsOneWidget);
    await tester.tap(find.textContaining('Reset to recommended'));
    await tester.pump();
    // Default schedule 5/10/15/30 → four rows.
    expect(find.text('Reminder 4'), findsOneWidget);
  });
}
