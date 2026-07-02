import 'package:trial_data_types/src/end_event.dart';
import 'package:trial_data_types/src/questionnaire_status.dart';
import 'package:trial_data_types/src/questionnaire_type.dart';

/// A questionnaire instance sent to a specific participant.
///
/// Tracks the full lifecycle from "Sent" through "Finalized".
// Implements: DIARY-PRD-questionnaire-portal-sent-rules/H — assigned-questionnaire lifecycle tracking
// Implements: DIARY-PRD-questionnaire-system/A — questionnaire instance as a coded component
class QuestionnaireInstance {
  const QuestionnaireInstance({
    required this.id,
    required this.questionnaireType,
    required this.status,
    required this.participantId,
    required this.version,
    this.sentAt,
    this.submittedAt,
    this.finalizedAt,
    this.studyEvent,
    this.endEvent,
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
      participantId: json['participant_id'] as String,
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
      endEvent: json['end_event'] != null
          ? EndEvent.fromValue(json['end_event'] as String)
          : null,
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

  /// Participant this questionnaire was sent to
  final String participantId;

  /// When sent by coordinator (null if not yet sent)
  final DateTime? sentAt;

  /// When participant submitted responses
  final DateTime? submittedAt;

  /// When investigator finalized
  final DateTime? finalizedAt;

  /// Study event identifier (e.g., "Cycle 1 Day 1")
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/A — study-event/cycle label
  final String? studyEvent;

  /// Terminal event type.
  /// Null for normal cycles. Set to [EndEvent.endOfTreatment] or
  /// [EndEvent.endOfStudy] during finalization. Stored separately from
  /// [studyEvent] to preserve the cycle number.
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/F — terminal end-event type
  final EndEvent? endEvent;

  /// Questionnaire version identifier
  // Implements: DIARY-PRD-questionnaire-system/A — versioned coded questionnaire component
  final String version;

  /// Soft delete timestamp (null if not deleted)
  final DateTime? deletedAt;

  /// Reason for deletion (max 25 chars)
  // Implements: DIARY-PRD-reason-field-constraints/B — bounded reason input length
  final String? deleteReason;

  /// Calculated score (populated after finalization)
  // Implements: DIARY-PRD-questionnaire-score-calculation/B — score stored with the record
  final int? score;

  /// Whether this instance has been soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Whether the participant can still edit responses
  bool get isEditable => status.canEdit && !isDeleted;

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionnaire_type': questionnaireType.value,
      'status': status.value,
      'participant_id': participantId,
      'version': version,
      'sent_at': sentAt?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'finalized_at': finalizedAt?.toIso8601String(),
      'study_event': studyEvent,
      'end_event': endEvent?.value,
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
    EndEvent? endEvent,
    DateTime? deletedAt,
    String? deleteReason,
    int? score,
  }) {
    return QuestionnaireInstance(
      id: id,
      questionnaireType: questionnaireType,
      status: status ?? this.status,
      participantId: participantId,
      version: version,
      sentAt: sentAt ?? this.sentAt,
      submittedAt: submittedAt ?? this.submittedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      studyEvent: studyEvent ?? this.studyEvent,
      endEvent: endEvent ?? this.endEvent,
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
      'status: ${status.value}, participant: $participantId)';
}
