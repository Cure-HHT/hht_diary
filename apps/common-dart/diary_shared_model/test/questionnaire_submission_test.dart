// Verifies: DIARY-DEV-shared-events-catalog/A+D
//   Verifies: DIARY-PRD-questionnaire-versioning/J+K+L (response carries the
//     three version identifiers; translation ref recorded when present)
//
// The cross-wire questionnaire-submission payload (decision 1d / surface D6):
// portal-minted instance_id carried through, schema/content/gui (+ translation)
// version refs, completed_at, optional flowToken, and the
// `question_id -> {value, display_label, normalized_label}` responses map.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('QuestionResponse', () {
    test('round-trips value + display/normalized labels', () {
      const r = QuestionResponse(
        value: 3,
        displayLabel: 'Moderately',
        normalizedLabel: 'moderate',
      );
      final back = QuestionResponse.fromJson(r.toJson());
      expect(back.value, 3);
      expect(back.displayLabel, 'Moderately');
      expect(back.normalizedLabel, 'moderate');
    });

    test('labels are optional', () {
      const r = QuestionResponse(value: true);
      final json = r.toJson();
      expect(json.containsKey('display_label'), isFalse);
      expect(json.containsKey('normalized_label'), isFalse);
      final back = QuestionResponse.fromJson(json);
      expect(back.value, true);
      expect(back.displayLabel, isNull);
      expect(back.normalizedLabel, isNull);
    });
  });

  group('QuestionnaireSubmissionPayload', () {
    QuestionnaireSubmissionPayload full() =>
        const QuestionnaireSubmissionPayload(
          instanceId: 'inst-portal-1',
          questionnaireType: 'qol',
          schemaVersion: 's1',
          contentVersion: 'c2',
          guiVersion: 'g3',
          translationVersion: 'es-1',
          completedAt: '2025-10-16T08:30:00.000-05:00',
          flowToken: 'flow-abc',
          responses: {
            'q1': QuestionResponse(
              value: 3,
              displayLabel: 'Moderately',
              normalizedLabel: 'moderate',
            ),
            'q2': QuestionResponse(value: 'yes'),
          },
        );

    test(
      'DIARY-PRD-questionnaire-versioning/J+K+L: round-trips a full payload',
      () {
        final back = QuestionnaireSubmissionPayload.fromJson(full().toJson());
        expect(back.instanceId, 'inst-portal-1');
        expect(back.questionnaireType, 'qol');
        expect(back.schemaVersion, 's1');
        expect(back.contentVersion, 'c2');
        expect(back.guiVersion, 'g3');
        expect(back.translationVersion, 'es-1');
        expect(back.completedAt, '2025-10-16T08:30:00.000-05:00');
        expect(back.flowToken, 'flow-abc');
        expect(back.responses.keys, containsAll(<String>['q1', 'q2']));
        expect(back.responses['q1']!.displayLabel, 'Moderately');
        expect(back.responses['q2']!.value, 'yes');
      },
    );

    test(
      'responses serialize as a question_id -> object map (decision 1d)',
      () {
        final json = full().toJson();
        final responses = json['responses']! as Map<String, Object?>;
        expect(responses.keys, containsAll(<String>['q1', 'q2']));
        final q1 = responses['q1']! as Map<String, Object?>;
        expect(q1['value'], 3);
        expect(q1['display_label'], 'Moderately');
        expect(q1['normalized_label'], 'moderate');
      },
    );

    test(
      'flowToken + translationVersion are optional (diary-initiated survey)',
      () {
        const p = QuestionnaireSubmissionPayload(
          instanceId: 'inst-diary-1',
          questionnaireType: 'daily',
          schemaVersion: 's1',
          contentVersion: 'c1',
          guiVersion: 'g1',
          completedAt: '2025-10-16T08:30:00.000-05:00',
          responses: {'q1': QuestionResponse(value: 1)},
        );
        final json = p.toJson();
        expect(json.containsKey('flowToken'), isFalse);
        expect(json.containsKey('translation_version'), isFalse);
        final back = QuestionnaireSubmissionPayload.fromJson(json);
        expect(back.flowToken, isNull);
        expect(back.translationVersion, isNull);
      },
    );

    test(
      'DIARY-DEV-shared-events-catalog/D: payload carries no session/OTP tokens',
      () {
        // flowToken is a correlation token, not a secret; the schema has no field
        // for credentials. Guard against accidental leakage of known secret keys.
        final json = full().toJson();
        for (final forbidden in const [
          'otp',
          'recovery',
          'session',
          'password',
          'token',
        ]) {
          expect(
            json.keys.any((k) => k.toLowerCase() == forbidden),
            isFalse,
            reason: 'submission payload must not contain a `$forbidden` field',
          );
        }
      },
    );
  });
}
