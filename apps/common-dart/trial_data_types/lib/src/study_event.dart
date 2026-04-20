// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// StudyEvent format validation and cycle number parsing.
// Used by both portal server (cycle computation) and portal UI (display).

import 'package:trial_data_types/src/end_event.dart';

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

  // Phase 2 end-event wire-format constants (snake_case DB values).
  // These MUST match EndEvent.endOfTreatment.value / EndEvent.endOfStudy.value.
  // Dart const does not allow accessing enum fields at compile time, so the
  // string literals are duplicated here. A test in study_event_test.dart
  // asserts they stay in sync.
  static const endOfTreatment = 'end_of_treatment';
  static const endOfStudy = 'end_of_study';

  /// Returns the human-readable display label for an end-event wire value.
  ///
  /// Delegates to [EndEvent.displayName] so the label is defined in exactly
  /// one place. Falls back to the raw value for unknown inputs.
  static String endEventDisplayLabel(String endEventValue) {
    try {
      return EndEvent.fromValue(endEventValue).displayName;
    } catch (_) {
      return endEventValue;
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

  /// Returns true if the value is a known end-event wire value.
  ///
  /// Delegates to [EndEvent] so the set of valid values is defined once.
  static bool isEndEvent(String value) {
    return EndEvent.values.any((e) => e.value == value);
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
