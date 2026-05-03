// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion F)
//
// Typed enum for the terminal study-event types that permanently close
// a questionnaire type for a patient once finalized.

/// Terminal study-event type set during questionnaire finalization.
///
/// When an Investigator finalizes a questionnaire as an end event, no further
/// questionnaires of that type can be sent to the patient
/// (REQ-CAL-p00080 Assertion F/G).
enum EndEvent {
  /// Patient has reached End of Treatment
  endOfTreatment('end_of_treatment', 'End of Treatment'),

  /// Patient has reached End of Study
  endOfStudy('end_of_study', 'End of Study');

  const EndEvent(this.value, this.displayName);

  /// Wire format value (used in JSON, API, database)
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Parse from wire format string. Throws [ArgumentError] if unknown.
  static EndEvent fromValue(String value) {
    return EndEvent.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown end event: $value'),
    );
  }
}
