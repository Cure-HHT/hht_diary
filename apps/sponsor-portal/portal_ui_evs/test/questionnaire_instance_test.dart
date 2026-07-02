import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/questionnaire_instance.dart';

void main() {
  group('statusFromQuestionnaireEntryType', () {
    test('questionnaire_assigned -> sent', () {
      expect(
        statusFromQuestionnaireEntryType('questionnaire_assigned'),
        QuestionnaireInstanceStatus.sent,
      );
    });

    test('questionnaire_submission_received -> readyToReview', () {
      expect(
        statusFromQuestionnaireEntryType('questionnaire_submission_received'),
        QuestionnaireInstanceStatus.readyToReview,
      );
    });

    test('questionnaire_locked -> closed', () {
      expect(
        statusFromQuestionnaireEntryType('questionnaire_locked'),
        QuestionnaireInstanceStatus.closed,
      );
    });

    test('legacy questionnaire_finalized (pre-CUR-1539 logs) -> closed', () {
      // CUR-1539: frozen legacy alias of questionnaire_locked.
      expect(
        statusFromQuestionnaireEntryType('questionnaire_finalized'),
        QuestionnaireInstanceStatus.closed,
      );
    });

    test('null -> unknown', () {
      expect(
        statusFromQuestionnaireEntryType(null),
        QuestionnaireInstanceStatus.unknown,
      );
    });

    test('unrecognised entryType -> unknown', () {
      expect(
        statusFromQuestionnaireEntryType('questionnaire_called_back'),
        QuestionnaireInstanceStatus.unknown,
      );
    });
  });

  group('QuestionnaireInstance.fromRow', () {
    test('maps all fields from a questionnaire_instance row', () {
      final row = <String, Object?>{
        'aggregateId': 'inst-42',
        'participant_id': 'P-7',
        'type': 'phq9',
        'study_event': 'Cycle 1 Day 1',
        'entryType': 'questionnaire_assigned',
      };

      final qi = QuestionnaireInstance.fromRow(row);

      expect(qi.instanceId, 'inst-42');
      expect(qi.participantId, 'P-7');
      expect(qi.type, 'phq9');
      expect(qi.studyEvent, 'Cycle 1 Day 1');
      expect(qi.status, QuestionnaireInstanceStatus.sent);
      expect(qi.endEvent, isNull);
    });

    test('locked row with a terminal end_event surfaces endEvent', () {
      final qi = QuestionnaireInstance.fromRow(<String, Object?>{
        'aggregateId': 'inst-term',
        'participant_id': 'P-9',
        'type': 'nose_hht',
        'study_event': 'Cycle 3 Day 1',
        'entryType': 'questionnaire_locked',
        'end_event': 'end_of_treatment',
      });

      expect(qi.status, QuestionnaireInstanceStatus.closed);
      expect(qi.endEvent, 'end_of_treatment');
    });

    test('locked row -> closed status', () {
      final qi = QuestionnaireInstance.fromRow(<String, Object?>{
        'aggregateId': 'inst-99',
        'participant_id': 'P-1',
        'type': 'gad7',
        'study_event': 'Cycle 2 Day 1',
        'entryType': 'questionnaire_locked',
      });

      expect(qi.status, QuestionnaireInstanceStatus.closed);
    });

    test('defends against missing/null columns', () {
      final qi = QuestionnaireInstance.fromRow(const <String, Object?>{});

      expect(qi.instanceId, '?');
      expect(qi.participantId, '?');
      expect(qi.type, '?');
      expect(qi.studyEvent, isNull);
      expect(qi.status, QuestionnaireInstanceStatus.unknown);
      expect(qi.endEvent, isNull);
    });

    test('label is exposed on each status', () {
      expect(QuestionnaireInstanceStatus.notSent.label, 'Not Sent');
      expect(QuestionnaireInstanceStatus.sent.label, 'Sent');
      expect(
        QuestionnaireInstanceStatus.readyToReview.label,
        'Ready to Review',
      );
      expect(QuestionnaireInstanceStatus.closed.label, 'Closed');
      expect(QuestionnaireInstanceStatus.unknown.label, 'Unknown');
    });
  });
}
