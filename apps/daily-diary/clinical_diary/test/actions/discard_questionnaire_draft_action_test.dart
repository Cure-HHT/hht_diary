// Verifies: DIARY-PRD-questionnaire-session-timeout/C — on Session Expiry the
//   local checkpoint draft is discarded via a diary-local `draft_discarded`
//   event (never the cross-wire `tombstone`, which would ship to the portal).
// Verifies: DIARY-GUI-questionnaire-session-expiry/B
// Verifies: DIARY-DEV-action-write-path/A
import 'package:clinical_diary/actions/discard_questionnaire_draft_action.dart';
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
  requestStartedAt: DateTime.utc(2026, 6, 26, 12),
);

Map<String, Object?> _raw({String? reason}) => <String, Object?>{
  'instance_id': 'inst-expired-1',
  'questionnaire_type': 'nose_hht',
  'reason': ?reason,
};

void main() {
  const action = DiscardQuestionnaireDraftAction();

  test(
    'emits a diary-local draft_discarded event on the <id>_survey aggregate',
    () async {
      final input = action.parseInput(_raw());
      action.validate(input);
      final result = await action.execute(input, _ctx());
      final event = result.events.single;
      expect(event.aggregateId, 'inst-expired-1');
      expect(event.entryType, 'nose_hht_survey');
      // The point: NOT a `tombstone` — DiaryServerDestination ships
      // finalized/tombstone DiaryEntry events, and a draft the portal never
      // saw must not ship a tombstone for an unknown aggregate.
      expect(event.eventType, 'draft_discarded');
      expect(event.data['reason'], 'session-expired');
      expect(result.result, 'inst-expired-1');
    },
  );

  test('carries an explicit reason when supplied', () async {
    final result = await action.execute(
      action.parseInput(_raw(reason: 'in-flow-expiry')),
      _ctx(),
    );
    expect(result.events.single.data['reason'], 'in-flow-expiry');
  });

  test('rejects missing instance_id / questionnaire_type', () {
    expect(
      () => action.parseInput(const {'questionnaire_type': 'qol'}),
      throwsFormatException,
    );
    expect(
      () => action.parseInput(const {'instance_id': 'i-1'}),
      throwsFormatException,
    );
  });

  test('requires an identified participant principal', () async {
    final input = action.parseInput(_raw());
    expect(
      () => action.execute(input, _ctx(principal: const AnonymousPrincipal())),
      throwsStateError,
    );
  });
}
