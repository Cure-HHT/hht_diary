// Verifies: DIARY-GUI-main-screen-layout/A+C — the Important page consolidates
//   active alerts and tasks into one place, alerts above tasks, in priority
//   order. (The consolidated/collapse model is not yet in the requirement's
//   assertions; that divergence is to be reconciled in a later spec pass.)
//
// Covers the "N more important items" overflow destination: the two-section
// (Alerts / Tasks) page, the chevron affordance shown only for actionable
// alerts, and the pop-then-invoke behaviour of an alert row.

import 'package:clinical_diary/screens/important_screen.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Task questionnaireTask() => Task(
    id: 't1',
    taskType: TaskType.questionnaire,
    title: 'Daily Questionnaire',
    createdAt: DateTime(2026, 1, 1),
    subtitle: 'Tap to complete',
  );

  testWidgets('renders Alerts and Tasks sections', (tester) async {
    final tasks = TaskService();
    addTearDown(tasks.dispose);
    tasks.addTask(questionnaireTask());

    await tester.pumpWidget(
      MaterialApp(
        home: ImportantScreen(
          alerts: [
            const ImportantAlert(
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              title: 'Disconnected from Study',
            ),
            ImportantAlert(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              title: '2 incomplete records',
              onTap: () {},
            ),
          ],
          taskService: tasks,
        ),
      ),
    );

    expect(find.text('Important'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('TASKS'), findsOneWidget);
    expect(find.text('Disconnected from Study'), findsOneWidget);
    expect(find.text('2 incomplete records'), findsOneWidget);
    expect(find.text('Daily Questionnaire'), findsOneWidget);
  });

  testWidgets('chevron shows only for actionable alerts', (tester) async {
    final tasks = TaskService();
    addTearDown(tasks.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ImportantScreen(
          alerts: [
            // Informational (no onTap) — no chevron.
            const ImportantAlert(
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              title: 'Disconnected from Study',
            ),
            // Actionable (onTap) — chevron.
            ImportantAlert(
              icon: Icons.merge_type,
              color: Colors.amber,
              title: '1 overlapping record needs resolving',
              onTap: () {},
            ),
          ],
          taskService: tasks,
        ),
      ),
    );

    // Exactly one alert row carries a chevron (the actionable one); the
    // informational disconnection row carries none.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('Tasks section is absent when there are no tasks', (
    tester,
  ) async {
    final tasks = TaskService();
    addTearDown(tasks.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ImportantScreen(
          alerts: const [
            ImportantAlert(
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              title: 'Disconnected from Study',
            ),
          ],
          taskService: tasks,
        ),
      ),
    );

    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('TASKS'), findsNothing);
  });

  testWidgets('tapping an actionable alert pops the page and invokes onTap', (
    tester,
  ) async {
    final tasks = TaskService();
    addTearDown(tasks.dispose);
    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ImportantScreen(
                    alerts: [
                      ImportantAlert(
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orange,
                        title: '2 incomplete records',
                        onTap: () => invoked = true,
                      ),
                    ],
                    taskService: tasks,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportantScreen), findsOneWidget);

    await tester.tap(find.text('2 incomplete records'));
    await tester.pumpAndSettle();

    expect(invoked, isTrue);
    expect(find.byType(ImportantScreen), findsNothing, reason: 'page popped');
  });

  testWidgets('TaskListWidget honours its limit', (tester) async {
    final tasks = TaskService();
    addTearDown(tasks.dispose);
    for (var i = 0; i < 3; i++) {
      tasks.addTask(
        Task(
          id: 'q$i',
          taskType: TaskType.questionnaire,
          title: 'Questionnaire $i',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskListWidget(taskService: tasks, limit: 1)),
      ),
    );

    expect(find.textContaining('Questionnaire'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskListWidget(taskService: tasks)),
      ),
    );

    expect(find.textContaining('Questionnaire'), findsNWidgets(3));
  });
}
