// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// StudyEvent format validation and cycle number parsing.
// Used by both portal server (cycle computation) and portal UI (display).

/// Utility class for StudyEvent format validation and cycle number parsing.
///
/// Phase 1 valid format: "Cycle N Day 1" where N is a positive integer.
/// Phase 2 adds end-event constants (End of Treatment, End of Study).
class StudyEvent {
  StudyEvent._();

  /// Maximum length for a study_event value (enforced by DB CHECK constraint).
  static const maxLength = 32;

  /// Phase 1 format: "Cycle N Day 1" where N >= 1.
  static final _cyclePattern = RegExp(r'^Cycle ([1-9]\d*) Day 1$');

  // Phase 2 end-event constants (snake_case DB values).
  static const endOfTreatment = 'end_of_treatment';
  static const endOfStudy = 'end_of_study';

  /// Display labels for end events.
  static String endEventDisplayLabel(String endEvent) {
    switch (endEvent) {
      case endOfTreatment:
        return 'End of Treatment';
      case endOfStudy:
        return 'End of Study';
      default:
        return endEvent;
    }
  }

  /// Validates a study_event string against the "Cycle N Day 1" format.
  ///
  /// Returns true for valid cycle-based study events like "Cycle 1 Day 1",
  /// "Cycle 99 Day 1". Returns false for empty strings, "Cycle 0 Day 1",
  /// negative numbers, or any other format.
  static bool isValid(String value) {
    if (value.length > maxLength) return false;
    return _cyclePattern.hasMatch(value);
  }

  /// Returns true if the value is an end-event literal
  /// ("End of Treatment" or "End of Study").
  static bool isEndEvent(String value) {
    return value == endOfTreatment || value == endOfStudy;
  }

  /// Extracts the cycle number N from a "Cycle N Day 1" string.
  ///
  /// Returns null if the string does not match the expected format.
  static int? parseCycleNumber(String value) {
    final match = _cyclePattern.firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Formats a cycle number into a study_event string.
  ///
  /// Throws [ArgumentError] if [cycleNumber] is not a positive integer.
  static String format(int cycleNumber) {
    if (cycleNumber < 1) {
      throw ArgumentError.value(
        cycleNumber,
        'cycleNumber',
        'Must be a positive integer',
      );
    }
    return 'Cycle $cycleNumber Day 1';
  }
}
