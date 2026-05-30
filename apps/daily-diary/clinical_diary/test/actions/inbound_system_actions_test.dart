// Verifies: DIARY-DEV-inbound-event-on-receipt/A+B
// Verifies: DIARY-DEV-action-write-path/A
import 'package:clinical_diary/actions/inbound_system_actions.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx({Principal? principal}) => ActionContext(
  // System events fire before a participant is linked — anonymous is valid.
  principal: principal ?? const AnonymousPrincipal(),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2025, 10, 16, 12),
);

void main() {
  group('RecordFcmMessageReceivedAction', () {
    const action = RecordFcmMessageReceivedAction();

    test(
      'emits finalized fcm_message_received echoing flowToken (P5)',
      () async {
        final input = action.parseInput(const {
          'aggregateId': 'rcv-1',
          'received_at': '2025-10-16T08:30:00.000Z',
          'channel': 'fcm',
          'message_type': 'questionnaire_assigned',
          'flowToken': 'flow-abc',
        });
        action.validate(input);
        final draft = (await action.execute(input, _ctx())).events.single;
        expect(draft.entryType, 'fcm_message_received');
        expect(draft.eventType, 'finalized');
        expect(draft.aggregateId, 'rcv-1');
        expect(draft.data['flowToken'], 'flow-abc');
        expect(draft.data['channel'], 'fcm');
      },
    );

    test('does not require a UserPrincipal (fires pre-link)', () async {
      final input = action.parseInput(const {
        'aggregateId': 'rcv-2',
        'received_at': '2025-10-16T08:30:00.000Z',
        'channel': 'poll',
        'message_type': 'tombstone',
      });
      final draft = (await action.execute(input, _ctx())).events.single;
      expect(draft.data.containsKey('flowToken'), isFalse);
    });

    test('parseInput requires aggregateId', () {
      expect(
        () => action.parseInput(const {
          'received_at': '2025-10-16T08:30:00.000Z',
          'channel': 'fcm',
          'message_type': 'tombstone',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('validate rejects a non-ISO received_at', () {
      final input = action.parseInput(const {
        'aggregateId': 'rcv-3',
        'received_at': 'whenever',
        'channel': 'fcm',
        'message_type': 'tombstone',
      });
      expect(() => action.validate(input), throwsArgumentError);
    });
  });

  group('RegisterFcmTokenAction', () {
    const action = RegisterFcmTokenAction();

    test(
      'emits finalized fcm_token_registered with token + platform',
      () async {
        final input = action.parseInput(const {
          'aggregateId': 'tok-evt-1',
          'token': 'tok-123',
          'platform': 'android',
          'registered_at': '2025-10-16T08:30:00.000Z',
        });
        action.validate(input);
        final draft = (await action.execute(input, _ctx())).events.single;
        expect(draft.entryType, 'fcm_token_registered');
        expect(draft.data['token'], 'tok-123');
        expect(draft.data['platform'], 'android');
      },
    );

    test('validate rejects an empty token', () {
      final input = action.parseInput(const {
        'aggregateId': 'tok-evt-2',
        'token': '',
        'platform': 'ios',
        'registered_at': '2025-10-16T08:30:00.000Z',
      });
      expect(() => action.validate(input), throwsArgumentError);
    });

    test('parseInput rejects an unknown platform', () {
      expect(
        () => action.parseInput(const {
          'aggregateId': 'tok-evt-3',
          'token': 'tok-123',
          'platform': 'blackberry',
          'registered_at': '2025-10-16T08:30:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
