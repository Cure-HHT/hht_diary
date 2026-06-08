// Verifies: DIARY-DEV-native-outbound-sync/A — the system-events destination
//   selects the device's FCM aggregates (FcmToken / InboundMessage, eventType
//   'finalized'), and the diary-entries destination does NOT — so FCM token +
//   receipt events ship to the portal via SystemEventsDestination while clinical
//   diary entries continue to ship via DiaryServerDestination (locks Bug #1: a
//   token event was rejected by the only destination's aggregateTypes gate).

import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/destinations/system_events_destination.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

StoredEvent _event({
  required String aggregateType,
  required String entryType,
  String eventType = 'finalized',
}) => StoredEvent.synthetic(
  eventId: 'evt-1',
  aggregateId: 'P1:fcm:android',
  aggregateType: aggregateType,
  entryType: entryType,
  eventType: eventType,
  data: const {'token': 'TOK', 'platform': 'android'},
  initiator: const UserInitiator('u-1'),
  clientTimestamp: DateTime.utc(2026, 1, 1),
  eventHash: 'h',
);

DiaryServerDestination _diaryDest() => DiaryServerDestination(
  client: MockClient((_) async => http.Response('', 200)),
  resolveIngestUrl: () async => Uri.parse('https://x/ingest'),
  authToken: () async => 'jwt',
);

SystemEventsDestination _systemDest() => SystemEventsDestination(
  client: MockClient((_) async => http.Response('', 200)),
  resolveIngestUrl: () async => Uri.parse('https://x/ingest'),
  authToken: () async => 'jwt',
);

void main() {
  group('SystemEventsDestination identity + wire flags', () {
    final d = _systemDest();
    test('id is system', () => expect(d.id, 'system'));
    test('shares the canonical native wire shape', () {
      expect(d.wireFormat, BatchEnvelope.wireFormat);
      expect(d.serializesNatively, isTrue);
      expect(d.maxAccumulateTime, Duration.zero);
    });
  });

  group('FCM token routing (Bug #1)', () {
    final fcmTokenEvent = _event(
      aggregateType: 'FcmToken',
      entryType: 'fcm_token_registered',
    );
    final inboundMsgEvent = _event(
      aggregateType: 'InboundMessage',
      entryType: 'fcm_message_received',
    );
    final diaryEvent = _event(
      aggregateType: diaryEntryAggregateType,
      entryType: 'epistaxis_event',
    );

    test('SystemEventsDestination selects FcmToken/finalized', () {
      expect(_systemDest().filter.matches(fcmTokenEvent), isTrue);
    });
    test('SystemEventsDestination selects InboundMessage/finalized', () {
      expect(_systemDest().filter.matches(inboundMsgEvent), isTrue);
    });
    test('SystemEventsDestination rejects DiaryEntry', () {
      expect(_systemDest().filter.matches(diaryEvent), isFalse);
    });

    test(
      'DiaryServerDestination does NOT select FcmToken (the Bug #1 gap)',
      () {
        expect(_diaryDest().filter.matches(fcmTokenEvent), isFalse);
      },
    );
    test('DiaryServerDestination still selects DiaryEntry/finalized', () {
      expect(_diaryDest().filter.matches(diaryEvent), isTrue);
    });
  });

  test('SystemEventsDestination selects FcmToken tombstone (deactivation)', () {
    final tombstone = _event(
      aggregateType: 'FcmToken',
      entryType: 'fcm_token_deactivated',
      eventType: 'tombstone',
    );
    expect(_systemDest().filter.matches(tombstone), isTrue);
  });
}
