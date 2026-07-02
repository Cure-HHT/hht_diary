import 'package:trial_data_types/src/questionnaire_type.dart';
import 'package:trial_data_types/src/task_type.dart';

/// A participant task displayed at the top of the mobile app screen.
///
// Implements: DIARY-GUI-participant-task-list/A+C+D — Tasks are actionable items
//   that require participant attention, displayed in priority order, each linking
//   directly to the relevant screen.
class Task {
  // Implements: DIARY-GUI-participant-task-list/A+C+D — task identity, priority, and navigation
  const Task({
    required this.id,
    required this.taskType,
    required this.title,
    required this.createdAt,
    this.subtitle,
    this.targetId,
    this.questionnaireType,
    this.studyEvent,
    this.status,
  });

  /// Create from JSON map (REST API response or local storage)
  // Implements: DIARY-GUI-participant-task-list/A+C+D — deserialise all task fields
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/A — questionnaire/study-event association
  factory Task.fromJson(Map<String, dynamic> json) {
    final studyEvent = json['study_event'] as String?;
    return Task(
      id: json['id'] as String,
      taskType: TaskType.fromValue(json['task_type'] as String),
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      subtitle: json['subtitle'] as String? ?? studyEvent,
      targetId: json['target_id'] as String?,
      questionnaireType: json['questionnaire_type'] != null
          ? QuestionnaireType.fromValue(json['questionnaire_type'] as String)
          : null,
      studyEvent: studyEvent,
      status: json['status'] as String?,
    );
  }

  /// Create a questionnaire task from an FCM data message or a /user/tasks
  /// sync entry.
  ///
  /// `questionnaire_type` may be null for entries whose lifecycle has ended
  /// (e.g. `status:'recalled'`) — the type is treated as unknown in that case
  /// and `questionnaireType` is left null rather than throwing.
  // Implements: DIARY-GUI-participant-task-list/A — questionnaire task created from push notification
  factory Task.fromFcmData(Map<String, dynamic> data) {
    final rawType = data['questionnaire_type'] as String?;
    final questionnaireType = rawType != null
        ? QuestionnaireType.fromValue(rawType)
        : null;
    final studyEvent = data['study_event'] as String?;
    return Task(
      id: data['questionnaire_instance_id'] as String,
      taskType: TaskType.questionnaire,
      title: questionnaireType?.displayName ?? 'Questionnaire',
      createdAt: DateTime.now(),
      // CUR-856: Surface the cycle label ("Cycle 2 Day 1") on the task card
      // by populating the existing subtitle slot when no other subtitle is
      // present in the payload.
      subtitle: data['subtitle'] as String? ?? studyEvent,
      targetId: data['questionnaire_instance_id'] as String,
      questionnaireType: questionnaireType,
      studyEvent: studyEvent,
      status: data['status'] as String?,
    );
  }

  /// Unique task identifier
  // Implements: DIARY-GUI-participant-task-list/A
  final String id;

  /// Type of task (determines priority and behavior)
  // Implements: DIARY-GUI-participant-task-list/C
  final TaskType taskType;

  /// Display title (e.g., "NOSE HHT Questionnaire")
  final String title;

  /// Optional subtitle or status text
  final String? subtitle;

  /// When the task was created
  final DateTime createdAt;

  /// ID of the linked entity (e.g., questionnaire instance ID)
  // Implements: DIARY-GUI-participant-task-list/D
  final String? targetId;

  /// For questionnaire tasks: the questionnaire type
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/A — questionnaire-study-event association
  final QuestionnaireType? questionnaireType;

  /// CUR-856 (DIARY-BASE-questionnaire-cycle-tracking): Study-event cycle label assigned by the
  /// portal coordinator (e.g., "Cycle 2 Day 1"). Round-trips through
  /// [toJson] so resumed and submitted surveys carry the cycle label.
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/A
  final String? studyEvent;

  /// Portal-reported questionnaire lifecycle status.
  /// One of: sent | ready_to_review | finalized | unlocked; null for non-questionnaire tasks.
  // Implements: DIARY-GUI-participant-task-list/J — portal-reported lifecycle status
  //   (sent | ready_to_review | finalized | unlocked); null for non-questionnaire tasks.
  final String? status;

  /// Display priority per DIARY-GUI-participant-task-list/C
  // Implements: DIARY-GUI-participant-task-list/C
  int get priority => taskType.priority;

  /// Serialize to JSON map
  // Implements: DIARY-GUI-participant-task-list/A+C+D — round-trips all task fields for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_type': taskType.value,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'subtitle': subtitle,
      'target_id': targetId,
      'questionnaire_type': questionnaireType?.value,
      'study_event': studyEvent,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Task(id: $id, type: ${taskType.value}, title: $title)';
}
