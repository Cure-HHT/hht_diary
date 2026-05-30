// Verifies: DIARY-DEV-action-write-path/A
// Verifies: DIARY-DEV-shared-events-catalog/A (participant_linked, P4)
import 'package:clinical_diary/actions/record_participant_linked_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx({Principal? principal}) => ActionContext(
  // Linking establishes identity; the action records it regardless of principal.
  principal: principal ?? const AnonymousPrincipal(),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2025, 10, 16, 12),
);

void main() {
  const action = RecordParticipantLinkedAction();

  test(
    'emits a finalized participant_linked on the Participant aggregate',
    () async {
      final input = action.parseInput(const {
        'user_id': 'U-1',
        'linked_at': '2025-10-16T08:30:00.000Z',
        'participant_id': 'P-42',
        'site_id': 'SITE-3',
        'sponsor_id': 'callisto',
      });
      action.validate(input);
      final res = await action.execute(input, _ctx());
      final draft = res.events.single;
      expect(draft.aggregateType, 'Participant');
      expect(draft.aggregateId, 'U-1'); // keyed on the stable user id
      expect(draft.entryType, 'participant_linked');
      expect(draft.eventType, 'finalized');
      expect(draft.data['participant_id'], 'P-42');
      expect(draft.data['sponsor_id'], 'callisto');
      expect(draft.data.containsKey('jwt'), isFalse);
      expect(res.result, 'U-1');
    },
  );

  test('parseInput rejects a payload missing user_id', () {
    expect(
      () => action.parseInput(const {'linked_at': '2025-10-16T08:30:00.000Z'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('validate rejects a non-ISO linked_at', () {
    final input = action.parseInput(const {
      'user_id': 'U-1',
      'linked_at': 'whenever',
    });
    expect(() => action.validate(input), throwsArgumentError);
  });
}
