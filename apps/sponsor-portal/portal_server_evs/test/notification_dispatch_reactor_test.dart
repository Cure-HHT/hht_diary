import 'package:comms/comms.dart' show DispatchResult;
import 'package:event_sourcing/event_sourcing.dart' hide DispatchResult;
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/notification_dispatch_reactor.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import 'support/fake_push_channel.dart';

void main() {
  // Verifies: DIARY-DEV-outgoing-intent-correlation/B+C
  // Verifies: DIARY-DEV-pluggable-push-transport/A — reactor drives a neutral
  //   PushChannel; the recorded `channel` is the transport's name.
  late EventStore store;
  late StorageBackend backend;
  late FakePushChannel channel;
  late NotificationDispatchReactor reactor;
  final t0 = DateTime.utc(2026, 6, 7, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('ndr.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
    channel = FakePushChannel();
    reactor = NotificationDispatchReactor(
      eventStore: store,
      backend: backend,
      channel: channel,
    );
    addTearDown(() => store.close());
  });

  // Seed an active routing token into participant_fcm_tokens using the REAL
  // device wire shape: the diary's register_fcm_token action emits
  // eventType='finalized' with the semantic name in entryType, aggregate id
  // "{pid}:fcm:{platform}". This drives the projection fold through the same
  // axis the device cross-posts on (Bug #1/#2 round-trip).
  Future<void> registerToken(
    String participantId,
    String platform,
    String token,
  ) =>
      store.append(
        entryType: 'fcm_token_registered',
        aggregateType: 'FcmToken',
        aggregateId: '$participantId:fcm:$platform',
        eventType: 'finalized',
        data: <String, Object?>{
          'token': token,
          'platform': platform,
          'registered_at': '2026-06-07T00:00:00Z',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

  StoredEvent questionnaireAssigned(
    String participantId, {
    required String flowToken,
  }) =>
      StoredEvent.synthetic(
        eventId: 'syn-$flowToken',
        aggregateId: 'QI1',
        aggregateType: 'questionnaire_instance',
        entryType: 'questionnaire_assigned',
        eventType: 'questionnaire_assigned',
        flowToken: flowToken,
        data: <String, dynamic>{
          'participant_id': participantId,
          'type': 'nose',
        },
        initiator: const AutomationInitiator(service: 'test'),
        clientTimestamp: t0,
        eventHash: 'fakehash',
      );

  Future<List<StoredEvent>> eventsOfType(String entryType) async {
    final all = await backend.readEventsReverse().toList();
    return all.where((e) => e.entryType == entryType).toList();
  }

  test(
      'questionnaire_assigned sends one FCM with flowToken + records '
      'notification_sent', () async {
    await registerToken('P1', 'android', 'TOK123');

    await reactor
        .handleIntent(questionnaireAssigned('P1', flowToken: 'QST000001'));

    expect(channel.sent, hasLength(1));
    final push = channel.sent.single;
    expect(push.target.routingToken, 'TOK123');
    expect(push.target.participantId, 'P1');
    expect(push.target.platform, 'android');
    expect(push.message.userVisible, isTrue);
    expect(push.message.data['type'], 'questionnaire_assigned');
    expect(push.message.data['flowToken'], 'QST000001');

    final sent = await eventsOfType('notification_sent');
    expect(sent, hasLength(1));
    expect(sent.single.data['participant_id'], 'P1');
    expect(sent.single.data['channel'], 'fake-push');
    expect(sent.single.data['intent_entry_type'], 'questionnaire_assigned');
    expect(sent.single.data['fcm_token_aggregate_id'], 'P1:fcm:android');
    expect(sent.single.flowToken, 'QST000001');
  });

  test('no active token records notification_dispatch_failed(no_active_token)',
      () async {
    // No token registered for NOPE.
    await reactor
        .handleIntent(questionnaireAssigned('NOPE', flowToken: 'QST000002'));

    expect(channel.sent, isEmpty);
    final failed = await eventsOfType('notification_dispatch_failed');
    expect(failed, hasLength(1));
    expect(failed.single.data['participant_id'], 'NOPE');
    expect(failed.single.data['reason'], 'no_active_token');
  });

  test('UNREGISTERED terminal emits fcm_token_deactivated for the dead token',
      () async {
    await registerToken('P3', 'android', 'DEAD');
    channel.resultForToken['DEAD'] = const DispatchResult.unregisteredToken();

    await reactor.handleIntent(StoredEvent.synthetic(
      eventId: 'syn-PAT000001',
      aggregateId: 'P3',
      aggregateType: 'participant',
      entryType: 'participant_disconnected',
      eventType: 'participant_disconnected',
      flowToken: 'PAT000001',
      data: const <String, dynamic>{},
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: t0,
      eventHash: 'fakehash',
    ));

    expect(channel.sent, hasLength(1));
    expect(channel.sent.single.target.routingToken, 'DEAD');

    final deactivated = await eventsOfType('fcm_token_deactivated');
    expect(deactivated, hasLength(1));
    expect(deactivated.single.aggregateId, 'P3:fcm:android');
    // Deactivation is a tombstone (eventType) so the participant_fcm_tokens
    // projection's removeEventTypes:{'tombstone'} drops the dead-token row.
    expect(deactivated.single.eventType, 'tombstone');

    final failed = await eventsOfType('notification_dispatch_failed');
    expect(failed, hasLength(1));
    expect(failed.single.data['reason'], 'UNREGISTERED');
  });

  test(
      'a thrown dispatch (transport fault) still records '
      'notification_dispatch_failed', () async {
    await registerToken('P4', 'android', 'TOKX');
    // Simulate send() throwing instead of returning a terminal (e.g. ADC
    // resolution failure, or a TimeoutException from the send timeout).
    channel.throwOnSend = StateError('metadata server unreachable');

    await reactor
        .handleIntent(questionnaireAssigned('P4', flowToken: 'QST000004'));

    expect(channel.sent, hasLength(1));
    final failed = await eventsOfType('notification_dispatch_failed');
    expect(failed, hasLength(1));
    expect(failed.single.data['participant_id'], 'P4');
    expect(failed.single.data['fcm_token_aggregate_id'], 'P4:fcm:android');
    expect(failed.single.data['reason'], startsWith('dispatch_threw:'));
    expect(failed.single.flowToken, 'QST000004');
    // No success event recorded for a thrown dispatch.
    expect(await eventsOfType('notification_sent'), isEmpty);
  });

  // Verifies: DIARY-DEV-outgoing-intent-correlation/B (recall delivered via existing push path, silent)
  test('questionnaire_recall_notice sends a silent push carrying flow token',
      () async {
    await registerToken('P1', 'android', 'TOK1');
    await reactor.handleIntent(
      StoredEvent.synthetic(
        eventId: 'syn-rn1',
        aggregateId: 'P1:recall:QI1',
        aggregateType: 'questionnaire_recall_notice',
        entryType: 'questionnaire_recall_notice',
        eventType: 'questionnaire_recall_notice',
        flowToken: 'QST000009',
        data: <String, dynamic>{'participant_id': 'P1', 'instance_id': 'QI1'},
        initiator: const AutomationInitiator(service: 'test'),
        clientTimestamp: t0,
        eventHash: 'h',
      ),
    );
    expect(channel.sent, hasLength(1));
    expect(channel.sent.single.message.userVisible, isFalse);
    expect(channel.sent.single.message.data['type'],
        'questionnaire_recall_notice');
    expect(channel.sent.single.message.data['flowToken'], 'QST000009');
  });
}
