// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-p01064: Investigator Questionnaire Approval Workflow

/// Status of a questionnaire instance in its lifecycle.
///
/// Lifecycle per REQ-p01064:
///   Not Sent -> Sent -> In Progress -> Ready to Review -> Finalized
///   Ready to Review -> In Progress (patient edits after submission)
///
/// Patient can edit at any status before finalization (REQ-p01064-H).
/// Delete is allowed at any status after sending and before finalization (REQ-p01064-M/N).
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
  /// Per REQ-p01064-M/N: deletion is allowed after sending, NOT after finalization.
  bool get canDelete =>
      this != QuestionnaireStatus.notSent &&
      this != QuestionnaireStatus.finalized;

  /// Whether the patient can edit responses at this status.
  /// Per REQ-p01064-H: patient can edit any time before finalization.
  bool get canEdit =>
      this == QuestionnaireStatus.sent ||
      this == QuestionnaireStatus.inProgress ||
      this == QuestionnaireStatus.readyToReview;
}
