// Pure questionnaire-instance read model. The Manage Questionnaires modal
// subscribes to the `questionnaire_instance` view (gated portal.questionnaire.view_status,
// filtered client-side to the selected participant) to show live status. Each
// view row is ONE instance (aggregateId == instanceId); the latest folded
// lifecycle event lands on `entryType`, from which we derive a display status.
//
// Implements: DIARY-PRD-questionnaire-system/B — questionnaire_instance projects
//   the Completion Status per instance, which this read model surfaces.

/// Display status of a questionnaire instance, derived from the latest folded
/// lifecycle `entryType` on its `questionnaire_instance` row.
///
/// Mirrors the registry statuses relevant at this stage. Delivery Failed and
/// the `<id>_survey` -> Ready-to-Review join arrive in later phases; what is
/// available now is `questionnaire_assigned` -> [sent] and
/// `questionnaire_finalized` -> [closed]. A (participant, type) with NO row
/// means the questionnaire was never sent — the modal handles that absence,
/// but [notSent] is included for completeness, with [unknown] as the fallback.
///
/// Implements: DIARY-BASE-questionnaire-manage-modal/E — status drives the
///   per-status action matrix in the modal.
enum QuestionnaireInstanceStatus {
  notSent('Not Sent'),
  sent('Sent'),
  readyToReview('Ready to Review'),
  closed('Closed'),
  unknown('Unknown');

  const QuestionnaireInstanceStatus(this.label);

  /// Human-readable label for display.
  final String label;
}

/// Maps the latest folded lifecycle `entryType` to a
/// [QuestionnaireInstanceStatus]. `questionnaire_assigned` means the instance
/// is out (Sent); `questionnaire_submission_received` means the participant has
/// submitted (Ready to Review); `questionnaire_finalized` means it is Closed.
/// Anything unrecognised (including null, and the tombstoning
/// `questionnaire_called_back` — a called-back row is removed from the view, so
/// it should not be observed here) maps to
/// [QuestionnaireInstanceStatus.unknown].
///
/// Implements: DIARY-PRD-questionnaire-system/B
QuestionnaireInstanceStatus statusFromQuestionnaireEntryType(
  String? entryType,
) => switch (entryType) {
  'questionnaire_assigned' => QuestionnaireInstanceStatus.sent,
  'questionnaire_submission_received' =>
    QuestionnaireInstanceStatus.readyToReview,
  'questionnaire_finalized' => QuestionnaireInstanceStatus.closed,
  _ => QuestionnaireInstanceStatus.unknown,
};

/// One `questionnaire_instance` view row: aggregateId == instanceId (the row
/// key), plus the owning participant, the questionnaire type, the study event
/// (e.g. "Cycle 1 Day 1"), and the derived [status].
class QuestionnaireInstance {
  const QuestionnaireInstance({
    required this.instanceId,
    required this.participantId,
    required this.type,
    required this.studyEvent,
    required this.status,
    this.endEvent,
    this.finalizedAt,
  });

  /// Instance id == the view row's aggregateId.
  final String instanceId;

  /// The participant the instance belongs to.
  final String participantId;

  /// The questionnaire type.
  final String type;

  /// The study event (cycle/visit) the instance is bound to, if recorded.
  final String? studyEvent;

  /// Display status derived from the latest folded lifecycle entryType.
  final QuestionnaireInstanceStatus status;

  /// The terminal close marker on a finalized instance (`'end_of_treatment'` /
  /// `'end_of_study'`), or null for a normal cycle finalize / non-finalized
  /// row. A non-null value means the type is permanently Closed.
  final String? endEvent;

  /// When the instance's latest lifecycle event was folded onto the row (the
  /// intrinsic `updatedAt` stamp). For a finalized (closed) instance this is
  /// the moment of finalization — the modal surfaces it next to the "Last:"
  /// cycle so a coordinator sees exactly when the questionnaire was finalized.
  ///
  /// Implements: DIARY-BASE-questionnaire-finalization/D
  final DateTime? finalizedAt;

  /// Builds a [QuestionnaireInstance] from a raw view row, defending against
  /// missing/null columns (mirrors the `_P.fromRow` mapper pattern).
  ///
  /// Implements: DIARY-PRD-questionnaire-system/B
  /// Implements: DIARY-BASE-questionnaire-finalization/D — reads the intrinsic `updatedAt` fold stamp
  ///   so the after-finalize row can display the finalization date and time.
  static QuestionnaireInstance fromRow(Map<String, Object?> row) =>
      QuestionnaireInstance(
        instanceId: (row['aggregateId'] as String?) ?? '?',
        participantId: (row['participant_id'] as String?) ?? '?',
        type: (row['type'] as String?) ?? '?',
        studyEvent: row['study_event'] as String?,
        status: statusFromQuestionnaireEntryType(row['entryType'] as String?),
        endEvent: row['end_event'] as String?,
        finalizedAt: switch (row['updatedAt']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
      );
}
