import 'package:trial_data_types/src/questionnaire_type.dart';
import 'package:trial_data_types/src/task_type.dart';

/// A participant task displayed at the top of the mobile app screen.
///
// Implements: REQ-CAL-p00081/A — Tasks are actionable items that require
//   participant attention. They are displayed in priority order (REQ-CAL-p00081/C)
//   and each links directly to the relevant screen (REQ-CAL-p00081/D).
class Task {
  // Implements: REQ-CAL-p00081/A+C+D — task identity, priority, and navigation
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
  // Implements: REQ-CAL-p00081/A+C+D — deserialise all task fields including
  //   questionnaire association (REQ-CAL-p00080)
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
  // Implements: REQ-CAL-p00081/A — questionnaire task created from push notification
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
  // Implements: REQ-CAL-p00081/A
  final String id;

  /// Type of task (determines priority and behavior)
  // Implements: REQ-CAL-p00081/C
  final TaskType taskType;

  /// Display title (e.g., "NOSE HHT Questionnaire")
  final String title;

  /// Optional subtitle or status text
  final String? subtitle;

  /// When the task was created
  final DateTime createdAt;

  /// ID of the linked entity (e.g., questionnaire instance ID)
  // Implements: REQ-CAL-p00081/D
  final String? targetId;

  /// For questionnaire tasks: the questionnaire type
  // Implements: REQ-CAL-p00080 — questionnaire-study-event association
  final QuestionnaireType? questionnaireType;

  /// CUR-856 (REQ-CAL-p00080): Study-event cycle label assigned by the
  /// portal coordinator (e.g., "Cycle 2 Day 1"). Round-trips through
  /// [toJson] so resumed and submitted surveys carry the cycle label.
  // Implements: REQ-CAL-p00080
  final String? studyEvent;

  /// Portal-reported questionnaire lifecycle status.
  /// One of: sent | ready_to_review | finalized | unlocked; null for non-questionnaire tasks.
  // Implements: DIARY-GUI-participant-task-list/J — portal-reported lifecycle status
  //   (sent | ready_to_review | finalized | unlocked); null for non-questionnaire tasks.
  final String? status;

  /// Display priority per REQ-CAL-p00081-C
  // Implements: REQ-CAL-p00081/C
  int get priority => taskType.priority;

  /// Serialize to JSON map
  // Implements: REQ-CAL-p00081/A+C+D — round-trips all task fields for local storage
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
