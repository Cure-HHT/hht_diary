// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00080: Questionnaire Study Event Association
//   REQ-CAL-p00047: Hard-Coded Questionnaires

import 'package:trial_data_types/src/questionnaire_status.dart';
import 'package:trial_data_types/src/questionnaire_type.dart';

/// A questionnaire instance sent to a specific patient.
///
/// Tracks the full lifecycle from "Sent" through "Finalized"
/// per REQ-CAL-p00023.
class QuestionnaireInstance {
  const QuestionnaireInstance({
    required this.id,
    required this.questionnaireType,
    required this.status,
    required this.patientId,
    required this.version,
    this.sentAt,
    this.submittedAt,
    this.finalizedAt,
    this.studyEvent,
    this.deletedAt,
    this.deleteReason,
    this.score,
  });

  /// Create from JSON map (API response / local storage)
  factory QuestionnaireInstance.fromJson(Map<String, dynamic> json) {
    return QuestionnaireInstance(
      id: json['id'] as String,
      questionnaireType: QuestionnaireType.fromValue(
        json['questionnaire_type'] as String,
      ),
      status: QuestionnaireStatus.fromValue(json['status'] as String),
      patientId: json['patient_id'] as String,
      version: json['version'] as String,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      finalizedAt: json['finalized_at'] != null
          ? DateTime.parse(json['finalized_at'] as String)
          : null,
      studyEvent: json['study_event'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      deleteReason: json['delete_reason'] as String?,
      score: json['score'] as int?,
    );
  }

  /// Unique instance identifier (UUID)
  final String id;

  /// Type of questionnaire (eq, nose_hht, qol)
  final QuestionnaireType questionnaireType;

  /// Current status in the lifecycle
  final QuestionnaireStatus status;

  /// Patient this questionnaire was sent to
  final String patientId;

  /// When sent by coordinator (null if not yet sent)
  final DateTime? sentAt;

  /// When patient submitted responses
  final DateTime? submittedAt;

  /// When investigator finalized
  final DateTime? finalizedAt;

  /// Study event identifier per REQ-CAL-p00080 (e.g., "Cycle 1 Day 1")
  final String? studyEvent;

  /// Questionnaire version identifier per REQ-CAL-p00047-E
  final String version;

  /// Soft delete timestamp (null if not deleted)
  final DateTime? deletedAt;

  /// Reason for deletion per REQ-CAL-p00066 (max 25 chars)
  final String? deleteReason;

  /// Calculated score (populated after finalization per REQ-CAL-p00007)
  final int? score;

  /// Whether this instance has been soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Whether the patient can still edit responses
  bool get isEditable => status.canEdit && !isDeleted;

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionnaire_type': questionnaireType.value,
      'status': status.value,
      'patient_id': patientId,
      'version': version,
      'sent_at': sentAt?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'finalized_at': finalizedAt?.toIso8601String(),
      'study_event': studyEvent,
      'deleted_at': deletedAt?.toIso8601String(),
      'delete_reason': deleteReason,
      'score': score,
    };
  }

  /// Create a copy with updated fields
  QuestionnaireInstance copyWith({
    QuestionnaireStatus? status,
    DateTime? sentAt,
    DateTime? submittedAt,
    DateTime? finalizedAt,
    String? studyEvent,
    DateTime? deletedAt,
    String? deleteReason,
    int? score,
  }) {
    return QuestionnaireInstance(
      id: id,
      questionnaireType: questionnaireType,
      status: status ?? this.status,
      patientId: patientId,
      version: version,
      sentAt: sentAt ?? this.sentAt,
      submittedAt: submittedAt ?? this.submittedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      studyEvent: studyEvent ?? this.studyEvent,
      deletedAt: deletedAt ?? this.deletedAt,
      deleteReason: deleteReason ?? this.deleteReason,
      score: score ?? this.score,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionnaireInstance &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'QuestionnaireInstance(id: $id, type: ${questionnaireType.value}, '
      'status: ${status.value}, patient: $patientId)';
}
