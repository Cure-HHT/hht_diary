// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//
// Verifies: round-trip JSON for QuestionResponse and QuestionnaireSubmission

import 'package:test/test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  group('QuestionResponse', () {
    test('round-trips through fromJson/toJson', () {
      const original = QuestionResponse(
        questionId: 'q1',
        value: 3,
        displayLabel: 'Severe problem',
        normalizedLabel: '3',
      );
      final round = QuestionResponse.fromJson(original.toJson());
      expect(round.questionId, original.questionId);
      expect(round.value, original.value);
      expect(round.displayLabel, original.displayLabel);
      expect(round.normalizedLabel, original.normalizedLabel);
    });

    test('throws when value type is wrong', () {
      expect(
        () => QuestionResponse.fromJson({
          'question_id': 'q1',
          'value': '3', // string instead of int
          'display_label': 'x',
          'normalized_label': '3',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('QuestionnaireSubmission', () {
    test('toJson preserves response order', () {
      final submission = QuestionnaireSubmission(
        instanceId: 'i1',
        questionnaireType: 'nose_hht',
        version: '1.0',
        responses: const [
          QuestionResponse(
            questionId: 'q1',
            value: 1,
            displayLabel: 'a',
            normalizedLabel: '1',
          ),
          QuestionResponse(
            questionId: 'q2',
            value: 2,
            displayLabel: 'b',
            normalizedLabel: '2',
          ),
          QuestionResponse(
            questionId: 'q3',
            value: 0,
            displayLabel: 'c',
            normalizedLabel: '0',
          ),
        ],
        completedAt: DateTime.utc(2026, 5, 9, 12, 30, 0),
      );

      final j = submission.toJson();
      expect(j['instance_id'], 'i1');
      expect(j['questionnaire_type'], 'nose_hht');
      expect(j['version'], '1.0');
      final responses = (j['responses'] as List).cast<Map<String, dynamic>>();
      expect(responses, hasLength(3));
      expect(responses[0]['question_id'], 'q1');
      expect(responses[2]['question_id'], 'q3');
      expect(j['completed_at'], '2026-05-09T12:30:00.000Z');
    });
  });
}
