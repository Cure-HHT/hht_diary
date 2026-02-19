// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00047: Hard-Coded Questionnaires
//   REQ-p01065: Clinical Questionnaire System

/// Types of questionnaires available in the system.
///
/// Each type corresponds to a hard-coded questionnaire component
/// per REQ-CAL-p00047-A: questionnaire definitions are embedded
/// directly into the application code.
enum QuestionnaireType {
  /// Epistaxis Questionnaire - sent once at trial start via Start Trial
  eq('eq', 'Epistaxis Questionnaire'),

  /// NOSE HHT - 29 questions across 3 categories (Physical, Functional, Emotional)
  noseHht('nose_hht', 'NOSE HHT Questionnaire'),

  /// HHT Quality of Life - 4 questions about HHT impact on daily activities
  qol('qol', 'Quality of Life Questionnaire');

  const QuestionnaireType(this.value, this.displayName);

  /// Wire format value (used in JSON, API, database)
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Parse from wire format string. Throws [ArgumentError] if unknown.
  static QuestionnaireType fromValue(String value) {
    return QuestionnaireType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => throw ArgumentError('Unknown questionnaire type: $value'),
    );
  }
}
