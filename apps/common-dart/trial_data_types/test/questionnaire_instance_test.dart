// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00080: Questionnaire Study Event Association
//
// Verifies: REQ-CAL-p00023 — full lifecycle JSON round-trip incl. nullable fields
// Verifies: REQ-CAL-p00080 — endEvent serializes/deserialises against EndEvent enum

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

QuestionnaireInstance _baseFixture() => QuestionnaireInstance(
  id: 'inst-001',
  questionnaireType: QuestionnaireType.noseHht,
  status: QuestionnaireStatus.sent,
  patientId: 'pat-001',
  version: '1.0',
  sentAt: DateTime.utc(2026, 5, 1, 9, 0),
);

void main() {
  group('JSON round-trip', () {
    test('minimal instance round-trips', () {
      final original = _baseFixture();
      final round = QuestionnaireInstance.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.questionnaireType, original.questionnaireType);
      expect(round.status, original.status);
      expect(round.patientId, original.patientId);
      expect(round.version, original.version);
      expect(round.sentAt, original.sentAt);
      expect(round.submittedAt, isNull);
      expect(round.finalizedAt, isNull);
      expect(round.endEvent, isNull);
      expect(round.deletedAt, isNull);
    });

    test('fully-populated instance round-trips, including endEvent', () {
      final original = _baseFixture().copyWith(
        status: QuestionnaireStatus.finalized,
        submittedAt: DateTime.utc(2026, 5, 2, 10, 0),
        finalizedAt: DateTime.utc(2026, 5, 3, 11, 0),
        studyEvent: 'Cycle 1 Day 1',
        endEvent: EndEvent.endOfTreatment,
        deletedAt: DateTime.utc(2026, 5, 4, 12, 0),
        deleteReason: 'patient withdrew',
        score: 12,
      );

      final round = QuestionnaireInstance.fromJson(original.toJson());

      expect(round.status, QuestionnaireStatus.finalized);
      expect(round.submittedAt, original.submittedAt);
      expect(round.finalizedAt, original.finalizedAt);
      expect(round.studyEvent, 'Cycle 1 Day 1');
      expect(round.endEvent, EndEvent.endOfTreatment);
      expect(round.deletedAt, original.deletedAt);
      expect(round.deleteReason, 'patient withdrew');
      expect(round.score, 12);
    });
  });

  group('derived properties', () {
    test('isDeleted true iff deletedAt present', () {
      expect(_baseFixture().isDeleted, isFalse);
      expect(
        _baseFixture().copyWith(deletedAt: DateTime.now()).isDeleted,
        isTrue,
      );
    });

    test('isEditable false when status is finalized OR isDeleted', () {
      final fin = _baseFixture().copyWith(
        status: QuestionnaireStatus.finalized,
      );
      expect(fin.isEditable, isFalse);

      final deleted = _baseFixture().copyWith(deletedAt: DateTime.now());
      expect(deleted.isEditable, isFalse);
    });

    test('isEditable true while status canEdit and not deleted', () {
      final s = _baseFixture().copyWith(status: QuestionnaireStatus.inProgress);
      expect(s.isEditable, isTrue);
    });
  });

  group('equality', () {
    test('equal by id, regardless of mutable fields', () {
      final a = _baseFixture();
      final b = a.copyWith(status: QuestionnaireStatus.inProgress, score: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when ids differ', () {
      final a = _baseFixture();
      final b = QuestionnaireInstance(
        id: 'other',
        questionnaireType: a.questionnaireType,
        status: a.status,
        patientId: a.patientId,
        version: a.version,
      );
      expect(a, isNot(b));
    });
  });

  group('toString', () {
    test('contains identifying fields', () {
      final s = _baseFixture().toString();
      expect(s, contains('inst-001'));
      expect(s, contains('nose_hht'));
      expect(s, contains('sent'));
      expect(s, contains('pat-001'));
    });
  });
}
