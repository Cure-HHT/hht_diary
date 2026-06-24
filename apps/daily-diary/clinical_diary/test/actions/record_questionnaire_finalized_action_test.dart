// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S
import 'package:clinical_diary/actions/record_questionnaire_finalized_action.dart';
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

void main() {
  group('RecordQuestionnaireFinalizedAction', () {
    const action = RecordQuestionnaireFinalizedAction();

    test('name is record_questionnaire_finalized', () {
      expect(action.name, 'record_questionnaire_finalized');
    });

    test(
      'emits one questionnaire_finalized event on the questionnaire_instance aggregate',
      () async {
        final input = action.parseInput({'instance_id': 'i1'});
        action.validate(input);
        final result = await action.execute(input, _ctx());
        final draft = result.events.single;
        expect(draft.aggregateType, 'questionnaire_instance');
        expect(draft.aggregateId, 'i1');
        expect(draft.entryType, 'questionnaire_finalized');
        expect(draft.eventType, 'questionnaire_finalized');
        expect(draft.data, <String, Object?>{'source': 'portal-state-sync'});
        expect(result.result, 'i1');
      },
    );

    test('validate rejects missing instance_id', () {
      final input = action.parseInput({});
      expect(() => action.validate(input), throwsArgumentError);
    });

    test('validate rejects empty instance_id', () {
      final input = action.parseInput({'instance_id': ''});
      expect(() => action.validate(input), throwsArgumentError);
    });
  });

  group('RecordQuestionnaireUnlockedAction', () {
    const action = RecordQuestionnaireUnlockedAction();

    test('name is record_questionnaire_unlocked', () {
      expect(action.name, 'record_questionnaire_unlocked');
    });

    test(
      'emits one questionnaire_unlocked event on the questionnaire_instance aggregate',
      () async {
        final input = action.parseInput({'instance_id': 'i1'});
        action.validate(input);
        final result = await action.execute(input, _ctx());
        final draft = result.events.single;
        expect(draft.aggregateType, 'questionnaire_instance');
        expect(draft.aggregateId, 'i1');
        expect(draft.entryType, 'questionnaire_unlocked');
        expect(draft.eventType, 'questionnaire_unlocked');
        expect(draft.data, <String, Object?>{'source': 'portal-state-sync'});
        expect(result.result, 'i1');
      },
    );

    test('validate rejects missing instance_id', () {
      final input = action.parseInput({});
      expect(() => action.validate(input), throwsArgumentError);
    });
  });
}
