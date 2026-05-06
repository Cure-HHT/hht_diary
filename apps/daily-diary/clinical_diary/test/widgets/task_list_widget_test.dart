// CUR-1292: TaskListWidget tests for the "In progress" pill that
// indicates a questionnaire task has a checkpointed-but-not-finalized
// aggregate in the materialized view.

import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  /// Build a questionnaire task with a known target id so the WIP-set
  /// match logic is exercised the way the home screen invokes it.
  Task questionnaireTask({
    required String id,
    String? targetId,
    String title = 'NOSE HHT Survey',
  }) {
    return Task(
      id: id,
      taskType: TaskType.questionnaire,
      title: title,
      createdAt: DateTime.utc(2026, 5, 5),
      subtitle: 'Cycle 1 Day 1',
      targetId: targetId ?? id,
      questionnaireType: QuestionnaireType.noseHht,
      studyEvent: 'Cycle 1 Day 1',
    );
  }

  Widget host(TaskService service, {Set<String> wipAggregateIds = const {}}) {
    return MaterialApp(
      home: Scaffold(
        body: TaskListWidget(
          taskService: service,
          wipAggregateIds: wipAggregateIds,
        ),
      ),
    );
  }

  testWidgets(
    'renders the In progress pill when the task target is in the WIP set',
    (tester) async {
      final service = TaskService()..addTask(questionnaireTask(id: 'agg-1'));
      addTearDown(service.dispose);

      await tester.pumpWidget(host(service, wipAggregateIds: const {'agg-1'}));
      await tester.pumpAndSettle();

      expect(find.text('NOSE HHT Survey'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
    },
  );

  testWidgets(
    'does NOT render the pill when the task target is absent from the WIP set',
    (tester) async {
      final service = TaskService()..addTask(questionnaireTask(id: 'agg-1'));
      addTearDown(service.dispose);

      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();

      expect(find.text('NOSE HHT Survey'), findsOneWidget);
      expect(find.text('In progress'), findsNothing);
    },
  );

  testWidgets('matches by targetId not by task.id when they differ', (
    tester,
  ) async {
    final service = TaskService()
      ..addTask(questionnaireTask(id: 'task-id', targetId: 'agg-xyz'));
    addTearDown(service.dispose);

    // WIP set carries the aggregate id (matches Task.targetId).
    await tester.pumpWidget(host(service, wipAggregateIds: const {'agg-xyz'}));
    await tester.pumpAndSettle();
    expect(find.text('In progress'), findsOneWidget);

    // WIP set carrying the task.id should NOT match — the pill
    // contract is "aggregate has in-progress events", not "task id
    // matches" (the two diverge for tasks with explicit targetId).
    await tester.pumpWidget(host(service, wipAggregateIds: const {'task-id'}));
    await tester.pumpAndSettle();
    expect(find.text('In progress'), findsNothing);
  });

  testWidgets(
    'does NOT render the pill on non-questionnaire tasks even when their '
    'id is in the WIP set',
    (tester) async {
      final service = TaskService()
        ..addTask(
          Task(
            id: 'agg-1',
            taskType: TaskType.incompleteRecord,
            title: 'Finish nosebleed',
            createdAt: DateTime.utc(2026, 5, 5),
            targetId: 'agg-1',
          ),
        );
      addTearDown(service.dispose);

      await tester.pumpWidget(host(service, wipAggregateIds: const {'agg-1'}));
      await tester.pumpAndSettle();

      expect(find.text('In progress'), findsNothing);
    },
  );
}
