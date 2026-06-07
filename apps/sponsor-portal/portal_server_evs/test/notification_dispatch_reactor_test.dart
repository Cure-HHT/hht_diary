import 'package:comms/comms.dart' show DispatchResult;
import 'package:event_sourcing/event_sourcing.dart' hide DispatchResult;
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/notification_dispatch_reactor.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import 'support/fake_fcm_channel.dart';

void main() {
  // Verifies: DIARY-DEV-outgoing-intent-correlation/B+C
  // Verifies: DIARY-DEV-push-token-routing/B+C
  late EventStore store;
  late StorageBackend backend;
  late FakeFcmChannel channel;
  late NotificationDispatchReactor reactor;
  final t0 = DateTime.utc(2026, 6, 7, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('ndr.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
    channel = FakeFcmChannel();
    reactor = NotificationDispatchReactor(
      eventStore: store,
      backend: backend,
      channel: channel,
    );
    addTearDown(() => store.close());
  });

  // Seed an active routing token into participant_fcm_tokens (device-authored
  // fcm_token_registered, aggregate id "{pid}:fcm:{platform}").
  Future<void> registerToken(
    String participantId,
    String platform,
    String token,
  ) =>
      store.append(
        entryType: 'fcm_token_registered',
        aggregateType: 'FcmToken',
        aggregateId: '$participantId:fcm:$platform',
        eventType: 'fcm_token_registered',
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
    final msg = channel.sent.single;
    expect(msg.fcmToken, 'TOK123');
    expect(msg.userVisible, isTrue);
    expect(msg.data['type'], 'questionnaire_assigned');
    expect(msg.data['flowToken'], 'QST000001');

    final sent = await eventsOfType('notification_sent');
    expect(sent, hasLength(1));
    expect(sent.single.data['participant_id'], 'P1');
    expect(sent.single.data['channel'], 'fcm');
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
    expect(channel.sent.single.fcmToken, 'DEAD');

    final deactivated = await eventsOfType('fcm_token_deactivated');
    expect(deactivated, hasLength(1));
    expect(deactivated.single.aggregateId, 'P3:fcm:android');

    final failed = await eventsOfType('notification_dispatch_failed');
    expect(failed, hasLength(1));
    expect(failed.single.data['reason'], 'UNREGISTERED');
  });
}
