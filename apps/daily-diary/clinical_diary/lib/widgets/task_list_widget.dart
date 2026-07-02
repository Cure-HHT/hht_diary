// Task list widget displayed at the top of the home screen.
// Tasks are actionable items at the top of the screen, displayed in priority
// order, each linking to the relevant screen.

import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Widget that displays the participant's task list at the top of the home screen.
///
/// Shows actionable items (questionnaires, incomplete records, etc.)
/// sorted by priority.
// Implements: DIARY-GUI-participant-task-list/A+C+D
// Implements: DIARY-PRD-questionnaire-portal-sent-rules
class TaskListWidget extends StatelessWidget {
  const TaskListWidget({
    required this.taskService,
    this.onTaskTap,
    this.limit,
    super.key,
  });

  final TaskService taskService;

  /// Callback when a task is tapped (navigates to relevant screen).
  final ValueChanged<Task>? onTaskTap;

  /// When set, render at most [limit] highest-priority tasks. Used by the home
  /// screen to show only the single top task in its collapsed inline slot;
  /// null (the default) renders the full list (e.g. on the Important page).
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskService,
      builder: (context, _) {
        final allTasks = taskService.tasks;
        final tasks = limit == null
            ? allTasks
            : allTasks.take(limit!).toList(growable: false);
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: _TaskCard(
                  task: task,
                  onTap: () => onTaskTap?.call(task),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.onTap});

  final Task task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor(theme),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(theme), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(_taskIcon, color: _iconColor(theme), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: _textColor(theme),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (task.subtitle != null)
                    Text(
                      task.subtitle!,
                      style: TextStyle(
                        color: _textColor(theme).withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _iconColor(theme), size: 20),
          ],
        ),
      ),
    );
  }

  IconData get _taskIcon {
    switch (task.taskType) {
      case TaskType.questionnaire:
        return Icons.assignment;
      case TaskType.incompleteRecord:
        return Icons.warning_amber_rounded;
      case TaskType.yesterdayReminder:
        return Icons.today;
      case TaskType.missingDays:
        return Icons.calendar_today;
    }
  }

  Color _backgroundColor(ThemeData theme) {
    switch (task.taskType) {
      case TaskType.questionnaire:
        return Colors.blue.shade50;
      case TaskType.incompleteRecord:
        return Colors.orange.shade50;
      case TaskType.yesterdayReminder:
        return Colors.amber.shade50;
      case TaskType.missingDays:
        return Colors.grey.shade100;
    }
  }

  Color _borderColor(ThemeData theme) {
    switch (task.taskType) {
      case TaskType.questionnaire:
        return Colors.blue.shade200;
      case TaskType.incompleteRecord:
        return Colors.orange.shade200;
      case TaskType.yesterdayReminder:
        return Colors.amber.shade200;
      case TaskType.missingDays:
        return Colors.grey.shade300;
    }
  }

  Color _iconColor(ThemeData theme) {
    switch (task.taskType) {
      case TaskType.questionnaire:
        return Colors.blue.shade700;
      case TaskType.incompleteRecord:
        return Colors.orange.shade700;
      case TaskType.yesterdayReminder:
        return Colors.amber.shade700;
      case TaskType.missingDays:
        return Colors.grey.shade600;
    }
  }

  Color _textColor(ThemeData theme) {
    switch (task.taskType) {
      case TaskType.questionnaire:
        return Colors.blue.shade900;
      case TaskType.incompleteRecord:
        return Colors.orange.shade900;
      case TaskType.yesterdayReminder:
        return Colors.amber.shade900;
      case TaskType.missingDays:
        return Colors.grey.shade800;
    }
  }
}
