// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion B)
//
// Unit tests for StudyEvent format validation and cycle number parsing.

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('StudyEvent.isValid', () {
    test('accepts "Cycle 1 Day 1"', () {
      expect(StudyEvent.isValid('Cycle 1 Day 1'), isTrue);
    });

    test('accepts "Cycle 99 Day 1"', () {
      expect(StudyEvent.isValid('Cycle 99 Day 1'), isTrue);
    });

    test('accepts "Cycle 100 Day 1"', () {
      expect(StudyEvent.isValid('Cycle 100 Day 1'), isTrue);
    });

    test('rejects "Cycle 0 Day 1" (zero)', () {
      expect(StudyEvent.isValid('Cycle 0 Day 1'), isFalse);
    });

    test('rejects "Cycle -1 Day 1" (negative)', () {
      expect(StudyEvent.isValid('Cycle -1 Day 1'), isFalse);
    });

    test('rejects "Cycle Day 1" (missing number)', () {
      expect(StudyEvent.isValid('Cycle Day 1'), isFalse);
    });

    test('rejects empty string', () {
      expect(StudyEvent.isValid(''), isFalse);
    });

    test('rejects random string', () {
      expect(StudyEvent.isValid('hello world'), isFalse);
    });

    test('rejects string exceeding 32 chars', () {
      expect(
        StudyEvent.isValid('Cycle 1 Day 1 extra padding text here'),
        isFalse,
      );
    });

    test('rejects "Cycle 01 Day 1" (leading zero)', () {
      expect(StudyEvent.isValid('Cycle 01 Day 1'), isFalse);
    });

    test('rejects "cycle 1 day 1" (wrong case)', () {
      expect(StudyEvent.isValid('cycle 1 day 1'), isFalse);
    });

    test('rejects "Cycle 1 Day 2" (wrong day)', () {
      expect(StudyEvent.isValid('Cycle 1 Day 2'), isFalse);
    });

    test('rejects "Cycle 1.5 Day 1" (decimal)', () {
      expect(StudyEvent.isValid('Cycle 1.5 Day 1'), isFalse);
    });

    test('rejects end-event strings (not cycle format)', () {
      expect(StudyEvent.isValid('end_of_treatment'), isFalse);
      expect(StudyEvent.isValid('end_of_study'), isFalse);
    });
  });

  group('StudyEvent.isEndEvent', () {
    test('accepts "end_of_treatment"', () {
      expect(StudyEvent.isEndEvent('end_of_treatment'), isTrue);
    });

    test('accepts "end_of_study"', () {
      expect(StudyEvent.isEndEvent('end_of_study'), isTrue);
    });

    test('rejects cycle strings', () {
      expect(StudyEvent.isEndEvent('Cycle 1 Day 1'), isFalse);
    });

    test('rejects random strings', () {
      expect(StudyEvent.isEndEvent('hello'), isFalse);
    });

    test('rejects empty string', () {
      expect(StudyEvent.isEndEvent(''), isFalse);
    });
  });

  group('StudyEvent.parseCycleNumber', () {
    test('extracts 1 from "Cycle 1 Day 1"', () {
      expect(StudyEvent.parseCycleNumber('Cycle 1 Day 1'), equals(1));
    });

    test('extracts 99 from "Cycle 99 Day 1"', () {
      expect(StudyEvent.parseCycleNumber('Cycle 99 Day 1'), equals(99));
    });

    test('extracts 100 from "Cycle 100 Day 1"', () {
      expect(StudyEvent.parseCycleNumber('Cycle 100 Day 1'), equals(100));
    });

    test('returns null for invalid format', () {
      expect(StudyEvent.parseCycleNumber('hello'), isNull);
    });

    test('returns null for empty string', () {
      expect(StudyEvent.parseCycleNumber(''), isNull);
    });

    test('returns null for "Cycle 0 Day 1"', () {
      expect(StudyEvent.parseCycleNumber('Cycle 0 Day 1'), isNull);
    });

    test('returns null for end-event strings', () {
      expect(StudyEvent.parseCycleNumber('end_of_treatment'), isNull);
    });
  });

  group('StudyEvent.format', () {
    test('formats 1 as "Cycle 1 Day 1"', () {
      expect(StudyEvent.format(1), equals('Cycle 1 Day 1'));
    });

    test('formats 99 as "Cycle 99 Day 1"', () {
      expect(StudyEvent.format(99), equals('Cycle 99 Day 1'));
    });

    test('throws for 0', () {
      expect(() => StudyEvent.format(0), throwsArgumentError);
    });

    test('throws for negative number', () {
      expect(() => StudyEvent.format(-1), throwsArgumentError);
    });

    test('roundtrips with parseCycleNumber', () {
      for (final n in [1, 5, 10, 42, 100]) {
        expect(StudyEvent.parseCycleNumber(StudyEvent.format(n)), equals(n));
      }
    });
  });
}
