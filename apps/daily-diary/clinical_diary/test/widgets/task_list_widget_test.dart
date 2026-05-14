// Tests for task_list_widget.dart
// Covers: Task display and interaction, priority ordering

import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    required TaskService taskService,
    ValueChanged<Task>? onTaskTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TaskListWidget(taskService: taskService, onTaskTap: onTaskTap),
      ),
    );
  }

  group('TaskListWidget', () {
    testWidgets('shows nothing when task list is empty', (tester) async {
      final taskService = TaskService();

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byType(TaskListWidget), findsOneWidget);
      // Should render SizedBox.shrink when no tasks
      expect(find.byType(InkWell), findsNothing);

      taskService.dispose();
    });

    testWidgets('displays task title', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Complete Questionnaire',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.text('Complete Questionnaire'), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('displays task subtitle when present', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Questionnaire',
          subtitle: 'Due today',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.text('Questionnaire'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('displays multiple tasks', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Task One',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      taskService.addTask(
        Task(
          id: 'task-2',
          title: 'Task Two',
          taskType: TaskType.incompleteRecord,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.text('Task One'), findsOneWidget);
      expect(find.text('Task Two'), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('tapping task calls onTaskTap', (tester) async {
      Task? tappedTask;
      final taskService = TaskService();
      final task = Task(
        id: 'task-1',
        title: 'Tappable Task',
        taskType: TaskType.questionnaire,
        createdAt: DateTime(2026, 1, 1),
      );
      taskService.addTask(task);

      await tester.pumpWidget(
        buildTestWidget(
          taskService: taskService,
          onTaskTap: (t) => tappedTask = t,
        ),
      );

      await tester.tap(find.text('Tappable Task'));
      await tester.pumpAndSettle();

      expect(tappedTask, isNotNull);
      expect(tappedTask!.id, 'task-1');

      taskService.dispose();
    });

    testWidgets('shows correct icon for questionnaire task', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Questionnaire Task',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byIcon(Icons.assignment), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('shows correct icon for incomplete record task', (
      tester,
    ) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Incomplete Record',
          taskType: TaskType.incompleteRecord,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('shows correct icon for yesterday reminder task', (
      tester,
    ) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Yesterday Reminder',
          taskType: TaskType.yesterdayReminder,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byIcon(Icons.today), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('shows correct icon for missing days task', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Missing Days',
          taskType: TaskType.missingDays,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('shows chevron icon for navigation', (tester) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Task',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('updates when task service changes', (tester) async {
      final taskService = TaskService();

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      expect(find.text('New Task'), findsNothing);

      // Add a task
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'New Task',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pump();

      expect(find.text('New Task'), findsOneWidget);

      taskService.dispose();
    });

    testWidgets('applies correct color scheme for questionnaire', (
      tester,
    ) async {
      final taskService = TaskService();
      taskService.addTask(
        Task(
          id: 'task-1',
          title: 'Questionnaire',
          taskType: TaskType.questionnaire,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(buildTestWidget(taskService: taskService));

      // Find the container with decoration
      final containers = tester.widgetList<Container>(find.byType(Container));
      final decoratedContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
      );
      final decoration = decoratedContainer.decoration as BoxDecoration;

      // Questionnaire uses blue colors
      expect(decoration.color, Colors.blue.shade50);

      taskService.dispose();
    });
  });
}
