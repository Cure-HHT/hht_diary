/// Status of a questionnaire instance in its lifecycle.
///
/// Lifecycle:
///   Not Sent -> Sent -> In Progress -> Ready to Review -> Finalized -> Not Sent
///
/// Delete is allowed at any status before finalization.
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/G+I+J+M — submit -> review -> finalize -> reset lifecycle
// Implements: DIARY-PRD-questionnaire-portal-sent-rules/H — assigned-questionnaire workflow status
enum QuestionnaireStatus {
  /// Questionnaire has not been sent to the participant yet
  notSent('not_sent', 'Not Sent'),

  /// Questionnaire has been sent; participant has received notification
  sent('sent', 'Sent'),

  /// Participant has opened the questionnaire and started answering
  inProgress('in_progress', 'In Progress'),

  /// Participant has submitted all answers; awaiting investigator review
  readyToReview('ready_to_review', 'Ready to Review'),

  /// Investigator has finalized; questionnaire is read-only
  finalized('finalized', 'Finalized');

  const QuestionnaireStatus(this.value, this.displayName);

  /// Wire format value (used in JSON, API, database)
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Parse from wire format string. Throws [ArgumentError] if unknown.
  static QuestionnaireStatus fromValue(String value) {
    return QuestionnaireStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => throw ArgumentError('Unknown questionnaire status: $value'),
    );
  }

  /// Whether the questionnaire can be deleted at this status.
  // Implements: DIARY-BASE-questionnaire-coordinator-workflow/E — recall/deletion is NOT allowed after finalization
  bool get canDelete => this != QuestionnaireStatus.finalized;

  /// Whether the participant can edit responses at this status.
  // Implements: DIARY-PRD-questionnaire-portal-sent-rules/N+O — editable until finalized, not after
  bool get canEdit =>
      this == QuestionnaireStatus.sent ||
      this == QuestionnaireStatus.inProgress ||
      this == QuestionnaireStatus.readyToReview;
}
