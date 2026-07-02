import 'package:comms/comms.dart';
import 'package:test/test.dart';

import '_helpers/in_memory_repository.dart';

Envelope _buildEnvelope({
  String id = 'env-1',
  String participantId = 'pat-1',
  String title = 'Account Disconnected',
  String? body = 'You have been disconnected.',
  bool userVisible = true,
  Map<String, dynamic> payload = const <String, dynamic>{
    'action': 'disconnect',
  },
}) {
  return Envelope(
    notificationId: id,
    participantId: participantId,
    type: NotificationType.participantStatusUpdate,
    title: title,
    body: body,
    userVisible: userVisible,
    payload: payload,
    status: EnvelopeStatus.pending,
    createdAt: DateTime.utc(2026, 5, 8, 10, 30),
  );
}

// Verifies: DIARY-DEV-pluggable-push-transport/A — UNREGISTERED triggers onUnregistered callback
// Verifies: DIARY-DEV-push-payload-phi-safety/A+B — tripped guard leaves no pending row
// Verifies: DIARY-DEV-inbound-event-on-receipt/A — state machine pending -> sent / failed
void main() {
  setUp(() {
    PayloadGuard.testOnlyDisable = false;
    PayloadGuard.commonNamePatterns = <RegExp>[];
  });

  group('OutboxWriter.send', () {
    test('happy path: insertPending → dispatch → markSent', () async {
      final repo = InMemoryNotificationRepository();
      final channel = FakeFcmChannel(
        next: const DispatchResult.success('projects/x/messages/0:99'),
      );
      final writer = OutboxWriter(repo: repo, channel: channel);

      final id = await writer.send(_buildEnvelope(), fcmToken: 'tok-1');

      expect(id, equals('env-1'));
      expect(repo.transitions, equals(<String>['insert:env-1', 'sent:env-1']));
      expect(channel.dispatches, hasLength(1));
      final stored = await repo.findById(id, participantId: 'pat-1');
      expect(stored!.status, equals(EnvelopeStatus.sent));
      expect(stored.messageId, equals('projects/x/messages/0:99'));
    });

    test('FCM failure marks the envelope failed with the error', () async {
      final repo = InMemoryNotificationRepository();
      final channel = FakeFcmChannel(
        next: const DispatchResult.failure('FCM API error: 500'),
      );
      final writer = OutboxWriter(repo: repo, channel: channel);

      await writer.send(_buildEnvelope(), fcmToken: 'tok-1');

      final stored = await repo.findById('env-1', participantId: 'pat-1');
      expect(stored!.status, equals(EnvelopeStatus.failed));
      expect(stored.error, contains('500'));
    });

    test(
      'UNREGISTERED marks failed AND fires onUnregistered with the dead token',
      () async {
        final repo = InMemoryNotificationRepository();
        final channel = FakeFcmChannel(
          next: const DispatchResult.unregisteredToken(),
        );
        String? deactivatedToken;
        final writer = OutboxWriter(
          repo: repo,
          channel: channel,
          onUnregistered: (token) async {
            deactivatedToken = token;
          },
        );

        await writer.send(_buildEnvelope(), fcmToken: 'dead-token');

        expect(deactivatedToken, equals('dead-token'));
        final stored = await repo.findById('env-1', participantId: 'pat-1');
        expect(stored!.status, equals(EnvelopeStatus.failed));
        expect(stored.error, equals('UNREGISTERED'));
      },
    );

    test(
      'PayloadGuard tripped on title — no insertPending, no dispatch',
      () async {
        final repo = InMemoryNotificationRepository();
        final channel = FakeFcmChannel();
        final writer = OutboxWriter(repo: repo, channel: channel);

        expect(
          () => writer.send(
            // SubjectKey embedded in title — guard must reject before
            // the row reaches the repo.
            _buildEnvelope(title: 'Participant 999-001-125 disconnected'),
            fcmToken: 'tok-1',
          ),
          throwsA(isA<PhiLeakException>()),
        );
        // Allow any pending microtasks to settle so a buggy implementation
        // would have time to issue the inserts.
        await Future<void>.delayed(Duration.zero);
        expect(repo.transitions, isEmpty);
        expect(channel.dispatches, isEmpty);
      },
    );

    test('PayloadGuard tripped on serialized payload', () async {
      final repo = InMemoryNotificationRepository();
      final channel = FakeFcmChannel();
      final writer = OutboxWriter(repo: repo, channel: channel);

      expect(
        () => writer.send(
          _buildEnvelope(
            payload: <String, dynamic>{
              'action': 'disconnect',
              'note': 'Email user@example.com for details',
            },
          ),
          fcmToken: 'tok-1',
        ),
        throwsA(isA<PhiLeakException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.transitions, isEmpty);
    });

    test(
      'silent envelope (userVisible=false) sends FCM without title/body',
      () async {
        final repo = InMemoryNotificationRepository();
        final channel = FakeFcmChannel();
        final writer = OutboxWriter(repo: repo, channel: channel);

        await writer.send(
          _buildEnvelope(
            id: 'env-silent',
            title: 'Questionnaire Removed',
            body: 'silent body',
            userVisible: false,
            payload: const <String, dynamic>{
              'action': 'remove_task',
              'questionnaire_instance_id': 'inst-1',
            },
          ),
          fcmToken: 'tok-1',
        );

        expect(channel.dispatches, hasLength(1));
        final sent = channel.dispatches.single;
        expect(sent.userVisible, isFalse);
        expect(sent.notificationTitle, isNull);
        expect(sent.notificationBody, isNull);
      },
    );

    test(
      'FCM data carries type, notification_id, and payload entries',
      () async {
        final repo = InMemoryNotificationRepository();
        final channel = FakeFcmChannel();
        final writer = OutboxWriter(repo: repo, channel: channel);

        await writer.send(
          _buildEnvelope(
            payload: const <String, dynamic>{
              'action': 'disconnect',
              'study_id': 's-1',
            },
          ),
          fcmToken: 'tok-1',
        );

        final sent = channel.dispatches.single;
        expect(sent.data['type'], equals('participant_status_update'));
        expect(sent.data['notification_id'], equals('env-1'));
        expect(sent.data['action'], equals('disconnect'));
        expect(sent.data['study_id'], equals('s-1'));
      },
    );
  });
}
