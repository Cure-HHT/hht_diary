// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-p01064: Investigator Questionnaire Approval Workflow
//
// Verifies: REQ-CAL-p00023-I — finalized questionnaires cannot be deleted
// Verifies: REQ-CAL-p00023-M — patient editing window

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  test('exactly 5 statuses (drift guard)', () {
    expect(QuestionnaireStatus.values, hasLength(5));
  });

  group('fromValue', () {
    for (final s in QuestionnaireStatus.values) {
      test('round-trips ${s.value}', () {
        expect(QuestionnaireStatus.fromValue(s.value), s);
      });
    }

    test('throws on unknown', () {
      expect(
        () => QuestionnaireStatus.fromValue('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty', () {
      expect(
        () => QuestionnaireStatus.fromValue(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('canDelete (REQ-CAL-p00023-I)', () {
    test('not finalized -> true', () {
      expect(QuestionnaireStatus.notSent.canDelete, isTrue);
      expect(QuestionnaireStatus.sent.canDelete, isTrue);
      expect(QuestionnaireStatus.inProgress.canDelete, isTrue);
      expect(QuestionnaireStatus.readyToReview.canDelete, isTrue);
    });

    test('finalized -> false', () {
      expect(QuestionnaireStatus.finalized.canDelete, isFalse);
    });
  });

  group('canEdit (REQ-CAL-p00023-M)', () {
    test('editable: sent, inProgress, readyToReview', () {
      expect(QuestionnaireStatus.sent.canEdit, isTrue);
      expect(QuestionnaireStatus.inProgress.canEdit, isTrue);
      expect(QuestionnaireStatus.readyToReview.canEdit, isTrue);
    });

    test('non-editable: notSent, finalized', () {
      expect(QuestionnaireStatus.notSent.canEdit, isFalse);
      expect(QuestionnaireStatus.finalized.canEdit, isFalse);
    });
  });

  group('display name uniqueness', () {
    test('all display names unique', () {
      final names = QuestionnaireStatus.values
          .map((s) => s.displayName)
          .toSet();
      expect(names, hasLength(QuestionnaireStatus.values.length));
    });

    test('all wire values unique', () {
      final values = QuestionnaireStatus.values.map((s) => s.value).toSet();
      expect(values, hasLength(QuestionnaireStatus.values.length));
    });
  });
}
