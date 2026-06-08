// Verifies: DIARY-DEV-native-outbound-sync/A — the participant_fcm_tokens
//   projection folds the device's REAL FcmToken wire shape (eventType
//   'finalized', name in entryType) into a routing-token row, and a tombstone
//   removes it. This locks Bug #2 (the projection previously gated on the wrong
//   axis — entryType strings on the eventType slot — so the row was never
//   inserted from the device's finalized events).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:portal_service/src/fcm_projections.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fcmActiveTokensSpec spec axes select eventType finalized/tombstone',
    () {
      expect(fcmActiveTokensSpec.viewName, 'participant_fcm_tokens');
      expect(fcmActiveTokensSpec.rowKey, isA<AggregateIdKey>());
      expect(fcmActiveTokensSpec.interest.aggregateTypes, contains('FcmToken'));
      // The fold gates on eventType (NOT entryType): device tokens carry
      // eventType='finalized'; deactivation is a 'tombstone'.
      expect(
        fcmActiveTokensSpec.interest.eventTypes,
        containsAll(<String>{'finalized', 'tombstone'}),
      );
      expect(fcmActiveTokensSpec.insertEventTypes, contains('finalized'));
      expect(fcmActiveTokensSpec.removeEventTypes, contains('tombstone'));
    },
  );

  test(
    'real device token shape folds into a row, tombstone removes it',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('fcm_proj.db');
      final backend = SembastBackend(database: db);
      final store = await openPortalEventStore(backend: backend);
      addTearDown(() => store.close());

      // Append the REAL device wire shape the register_fcm_token action emits:
      // entryType carries the semantic name, eventType is 'finalized'.
      await store.append(
        entryType: 'fcm_token_registered',
        aggregateType: 'FcmToken',
        aggregateId: 'P1:fcm:android',
        eventType: 'finalized',
        data: <String, Object?>{
          'token': 'TOK-ABC',
          'platform': 'android',
          'registered_at': '2026-06-07T00:00:00Z',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

      final afterRegister = await backend.findViewRows(
        'participant_fcm_tokens',
      );
      final row = afterRegister.singleWhere(
        (r) => r['aggregateId'] == 'P1:fcm:android',
      );
      expect(row['token'], 'TOK-ABC');
      expect(row['platform'], 'android');

      // A deactivation tombstone (eventType='tombstone') removes the dead-token
      // row via the projection's removeEventTypes.
      await store.append(
        entryType: 'fcm_token_deactivated',
        aggregateType: 'FcmToken',
        aggregateId: 'P1:fcm:android',
        eventType: 'tombstone',
        data: const <String, Object?>{'reason': 'UNREGISTERED'},
        initiator: const AutomationInitiator(service: 'test'),
      );

      final afterTombstone = await backend.findViewRows(
        'participant_fcm_tokens',
      );
      expect(
        afterTombstone.where((r) => r['aggregateId'] == 'P1:fcm:android'),
        isEmpty,
      );
    },
  );
}
