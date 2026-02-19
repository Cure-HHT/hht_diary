// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-p01064: Investigator Questionnaire Approval Workflow

/// Status of a questionnaire instance in its lifecycle.
///
/// Lifecycle per REQ-CAL-p00023:
///   Not Sent -> Sent -> In Progress -> Ready to Review -> Finalized -> Not Sent
///
/// Delete is allowed at any status before finalization (REQ-CAL-p00023-F/I).
enum QuestionnaireStatus {
  /// Questionnaire has not been sent to the patient yet
  notSent('not_sent', 'Not Sent'),

  /// Questionnaire has been sent; patient has received notification
  sent('sent', 'Sent'),

  /// Patient has opened the questionnaire and started answering
  inProgress('in_progress', 'In Progress'),

  /// Patient has submitted all answers; awaiting investigator review
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
  /// Per REQ-CAL-p00023-I: deletion is NOT allowed after finalization.
  bool get canDelete => this != QuestionnaireStatus.finalized;

  /// Whether the patient can edit responses at this status.
  /// Per REQ-CAL-p00023-M: editable until finalized.
  bool get canEdit =>
      this == QuestionnaireStatus.sent ||
      this == QuestionnaireStatus.inProgress ||
      this == QuestionnaireStatus.readyToReview;
}
