// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion F)
//
// Unit tests for the EndEvent enum and its interaction with StudyEvent.

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  // Guard against accidentally adding a third end-event without updating
  // StudyEvent constants, display labels, and the DB enum type.
  test('EndEvent has exactly 2 variants', () {
    expect(EndEvent.values, hasLength(2));
  });

  group('EndEvent.fromValue', () {
    test('parses end_of_treatment', () {
      expect(EndEvent.fromValue('end_of_treatment'), EndEvent.endOfTreatment);
    });

    test('parses end_of_study', () {
      expect(EndEvent.fromValue('end_of_study'), EndEvent.endOfStudy);
    });

    test('throws ArgumentError for unknown value', () {
      expect(
        () => EndEvent.fromValue('end_of_something_else'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for empty string', () {
      expect(() => EndEvent.fromValue(''), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError for snake_case cycle string', () {
      expect(
        () => EndEvent.fromValue('cycle_1_day_1'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('EndEvent.value (wire format)', () {
    test('endOfTreatment wire value is end_of_treatment', () {
      expect(EndEvent.endOfTreatment.value, 'end_of_treatment');
    });

    test('endOfStudy wire value is end_of_study', () {
      expect(EndEvent.endOfStudy.value, 'end_of_study');
    });
  });

  group('EndEvent.displayName', () {
    test('endOfTreatment display name is End of Treatment', () {
      expect(EndEvent.endOfTreatment.displayName, 'End of Treatment');
    });

    test('endOfStudy display name is End of Study', () {
      expect(EndEvent.endOfStudy.displayName, 'End of Study');
    });
  });

  group('EndEvent round-trip', () {
    test('fromValue(value) round-trips endOfTreatment', () {
      const e = EndEvent.endOfTreatment;
      expect(EndEvent.fromValue(e.value), e);
    });

    test('fromValue(value) round-trips endOfStudy', () {
      const e = EndEvent.endOfStudy;
      expect(EndEvent.fromValue(e.value), e);
    });
  });

  // Sync guard: StudyEvent.endOfTreatment / endOfStudy must match the
  // EndEvent enum values. Dart const does not allow compile-time access to
  // enum fields, so the literals are duplicated — this test catches drift.
  group('StudyEvent constants stay in sync with EndEvent', () {
    test('StudyEvent.endOfTreatment matches EndEvent.endOfTreatment.value', () {
      expect(StudyEvent.endOfTreatment, EndEvent.endOfTreatment.value);
    });

    test('StudyEvent.endOfStudy matches EndEvent.endOfStudy.value', () {
      expect(StudyEvent.endOfStudy, EndEvent.endOfStudy.value);
    });
  });

  group('StudyEvent.endEventDisplayLabel delegates to EndEvent', () {
    test('returns correct label for end_of_treatment', () {
      expect(
        StudyEvent.endEventDisplayLabel('end_of_treatment'),
        EndEvent.endOfTreatment.displayName,
      );
    });

    test('returns correct label for end_of_study', () {
      expect(
        StudyEvent.endEventDisplayLabel('end_of_study'),
        EndEvent.endOfStudy.displayName,
      );
    });

    test('falls back to raw value for unknown input', () {
      expect(StudyEvent.endEventDisplayLabel('unknown_event'), 'unknown_event');
    });
  });

  group('StudyEvent.isEndEvent delegates to EndEvent', () {
    test('returns true for end_of_treatment', () {
      expect(StudyEvent.isEndEvent('end_of_treatment'), isTrue);
    });

    test('returns true for end_of_study', () {
      expect(StudyEvent.isEndEvent('end_of_study'), isTrue);
    });

    test('returns false for cycle string', () {
      expect(StudyEvent.isEndEvent('Cycle 1 Day 1'), isFalse);
    });

    test('returns false for empty string', () {
      expect(StudyEvent.isEndEvent(''), isFalse);
    });
  });
}
