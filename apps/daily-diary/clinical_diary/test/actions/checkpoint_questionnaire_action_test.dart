// Verifies: DIARY-PRD-questionnaire-portal-sent-rules/H
// Verifies: DIARY-DEV-action-write-path/A
import 'package:clinical_diary/actions/checkpoint_questionnaire_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx({Principal? principal}) => ActionContext(
  principal:
      principal ??
      UserPrincipal(
        userId: 'P-42',
        roles: const {'participant'},
        activeRole: 'participant',
      ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2025, 10, 16, 12),
);

// A portal-assigned survey, partially answered (1 of N questions).
Map<String, Object?> _partialPortalRaw() => <String, Object?>{
  'instance_id': 'inst-portal-1',
  'questionnaire_type': 'qol',
  'schema_version': 's1',
  'content_version': 'c2',
  'gui_version': 'g3',
  'completed_at': '2025-10-16T08:30:00.000-05:00',
  'flowToken': 'flow-abc',
  'responses': <String, Object?>{
    'q1': <String, Object?>{
      'value': 3,
      'display_label': 'Moderately',
      'normalized_label': 'moderate',
    },
  },
};

void main() {
  const action = CheckpointQuestionnaireAction();

  test(
    'emits a CHECKPOINT <id>_survey event (stays diary-local, never synced)',
    () async {
      final input = action.parseInput(_partialPortalRaw());
      action.validate(input);
      final result = await action.execute(input, _ctx());
      final draft = result.events.single;
      expect(draft.entryType, 'qol_survey');
      // The point of the whole feature: a draft is a `checkpoint`, NOT a
      // `finalized` — so DiaryServerDestination never ships it to the portal.
      expect(draft.eventType, 'checkpoint');
      // Aggregate id = the portal-minted instance id, carried through (D6) so a
      // later `finalized` lands on the SAME aggregate and self-removes the draft.
      expect(draft.aggregateId, 'inst-portal-1');
      expect(result.result, 'inst-portal-1');
    },
  );

  test(
    'carries the partial responses + version refs + echoed flowToken',
    () async {
      final draft = (await action.execute(
        action.parseInput(_partialPortalRaw()),
        _ctx(),
      )).events.single;
      expect(draft.data['schema_version'], 's1');
      expect(draft.data['content_version'], 'c2');
      expect(draft.data['gui_version'], 'g3');
      expect(draft.data['flowToken'], 'flow-abc'); // echoed (P5)
      final responses = draft.data['responses']! as Map<String, Object?>;
      expect(responses.keys, ['q1']);
      expect((responses['q1']! as Map)['value'], 3);
    },
  );

  test('diary-initiated survey: diary-minted instance, no flowToken', () async {
    final input = action.parseInput(const {
      'instance_id': 'inst-diary-1',
      'questionnaire_type': 'daily',
      'schema_version': 's1',
      'content_version': 'c1',
      'gui_version': 'g1',
      'completed_at': '2025-10-16T08:30:00.000-05:00',
      'responses': <String, Object?>{
        'q1': <String, Object?>{'value': 1},
      },
    });
    final draft = (await action.execute(input, _ctx())).events.single;
    expect(draft.entryType, 'daily_survey');
    expect(draft.aggregateId, 'inst-diary-1');
    expect(draft.eventType, 'checkpoint');
    expect(draft.data.containsKey('flowToken'), isFalse);
  });

  test('validate accepts a partial (sparse) responses map', () {
    final input = action.parseInput(_partialPortalRaw());
    expect(() => action.validate(input), returnsNormally);
  });

  test('parseInput rejects a payload missing instance_id', () {
    expect(
      () => action.parseInput(const {
        'questionnaire_type': 'qol',
        'schema_version': 's1',
        'content_version': 'c1',
        'gui_version': 'g1',
        'completed_at': '2025-10-16T08:30:00.000-05:00',
        'responses': <String, Object?>{
          'q1': <String, Object?>{'value': 1},
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('validate rejects a non-ISO completed_at', () {
    final input = action.parseInput(const {
      'instance_id': 'inst-1',
      'questionnaire_type': 'qol',
      'schema_version': 's1',
      'content_version': 'c1',
      'gui_version': 'g1',
      'completed_at': 'not-a-timestamp',
      'responses': <String, Object?>{
        'q1': <String, Object?>{'value': 1},
      },
    });
    expect(() => action.validate(input), throwsArgumentError);
  });

  test('requires an identified participant', () async {
    final input = action.parseInput(_partialPortalRaw());
    expect(
      () => action.execute(input, _ctx(principal: const AnonymousPrincipal())),
      throwsStateError,
    );
  });
}
