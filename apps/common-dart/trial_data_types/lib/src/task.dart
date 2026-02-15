// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System

import 'package:trial_data_types/src/questionnaire_type.dart';
import 'package:trial_data_types/src/task_type.dart';

/// A patient task displayed at the top of the mobile app screen.
///
/// Per REQ-CAL-p00081-A: Tasks are actionable items that require
/// patient attention. They are displayed in priority order (REQ-CAL-p00081-C)
/// and each links directly to the relevant screen (REQ-CAL-p00081-D).
class Task {
  const Task({
    required this.id,
    required this.taskType,
    required this.title,
    required this.createdAt,
    this.subtitle,
    this.targetId,
    this.questionnaireType,
  });

  /// Create from JSON map (FCM data message or local storage)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      taskType: TaskType.fromValue(json['task_type'] as String),
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      subtitle: json['subtitle'] as String?,
      targetId: json['target_id'] as String?,
      questionnaireType: json['questionnaire_type'] != null
          ? QuestionnaireType.fromValue(json['questionnaire_type'] as String)
          : null,
    );
  }

  /// Create a questionnaire task from an FCM data message
  factory Task.fromFcmData(Map<String, dynamic> data) {
    final questionnaireType = QuestionnaireType.fromValue(
      data['questionnaire_type'] as String,
    );
    return Task(
      id: data['questionnaire_instance_id'] as String,
      taskType: TaskType.questionnaire,
      title: questionnaireType.displayName,
      createdAt: DateTime.now(),
      targetId: data['questionnaire_instance_id'] as String,
      questionnaireType: questionnaireType,
    );
  }

  /// Unique task identifier
  final String id;

  /// Type of task (determines priority and behavior)
  final TaskType taskType;

  /// Display title (e.g., "NOSE HHT Questionnaire")
  final String title;

  /// Optional subtitle or status text
  final String? subtitle;

  /// When the task was created
  final DateTime createdAt;

  /// ID of the linked entity (e.g., questionnaire instance ID)
  final String? targetId;

  /// For questionnaire tasks: the questionnaire type
  final QuestionnaireType? questionnaireType;

  /// Display priority per REQ-CAL-p00081-C
  int get priority => taskType.priority;

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_type': taskType.value,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'subtitle': subtitle,
      'target_id': targetId,
      'questionnaire_type': questionnaireType?.value,
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
