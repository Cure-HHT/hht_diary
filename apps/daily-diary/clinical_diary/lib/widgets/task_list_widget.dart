// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Participant Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Task list widget displayed at the top of the home screen.
// Per REQ-CAL-p00081-A: Tasks are actionable items at the top of the screen.
// Per REQ-CAL-p00081-C: Tasks displayed in priority order.
// Per REQ-CAL-p00081-D: Each task links to the relevant screen.

import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Widget that displays the participant's task list at the top of the home screen.
///
/// Shows actionable items (questionnaires, incomplete records, etc.)
/// sorted by priority per REQ-CAL-p00081-C.
class TaskListWidget extends StatelessWidget {
  const TaskListWidget({
    required this.taskService,
    this.onTaskTap,
    this.wipAggregateIds = const <String>{},
    this.submittedAggregateIds = const <String>{},
    super.key,
  });

  final TaskService taskService;

  /// Callback when a task is tapped (navigates to relevant screen per
  /// REQ-CAL-p00081-D)
  final ValueChanged<Task>? onTaskTap;

  /// CUR-1292: aggregate ids of questionnaires the participant has started
  /// but not yet submitted. Used to render an "In progress" pill on
  /// the matching questionnaire task card so the participant knows tapping
  /// it will resume rather than restart.
  final Set<String> wipAggregateIds;

  /// CUR-1292: aggregate ids of questionnaires the participant has already
  /// submitted (a `finalized` event landed locally). Once submitted the
  /// questionnaire lives in the timeline (today/yesterday/calendar) as
  /// an event entry; it should not also appear here as a task. The
  /// matching task remains in [taskService] so the timeline tap can
  /// look it up and route into the editable flow until the portal
  /// coordinator clicks Finalize and the server drops it from /tasks.
  final Set<String> submittedAggregateIds;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskService,
      builder: (context, _) {
        final tasks = taskService.tasks
            .where(
              (t) =>
                  t.taskType != TaskType.questionnaire ||
                  !submittedAggregateIds.contains(t.targetId ?? t.id),
            )
            .toList();
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
                  isInProgress:
                      task.taskType == TaskType.questionnaire &&
                      wipAggregateIds.contains(task.targetId ?? task.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.onTap, this.isInProgress = false});

  final Task task;
  final VoidCallback? onTap;
  final bool isInProgress;

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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: _textColor(theme),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isInProgress) ...[
                        const SizedBox(width: 8),
                        _InProgressPill(textColor: _textColor(theme)),
                      ],
                    ],
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
      case TaskType.cancelledQuestionnaire:
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
      case TaskType.cancelledQuestionnaire:
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
      case TaskType.cancelledQuestionnaire:
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
      case TaskType.cancelledQuestionnaire:
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
      case TaskType.cancelledQuestionnaire:
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

/// CUR-1292: small chip rendered next to a questionnaire task title
/// when the participant has answered at least one question but hasn't yet
/// submitted. Tapping the task resumes from where they left off rather
/// than restarting from readiness.
class _InProgressPill extends StatelessWidget {
  const _InProgressPill({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'In progress',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
