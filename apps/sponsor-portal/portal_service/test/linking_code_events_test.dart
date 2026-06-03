// Verifies: DIARY-DEV-linking-code-lifecycle/A — linking-code lifecycle event types exist.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test(
    'participant_linking_code_used and _revoked are registered entry types',
    () async {
      final db = await databaseFactoryMemory.openDatabase('lc-events.db');
      final store = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );
      await store.append(
        entryType: 'participant_linking_code_used',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_linking_code_used',
        data: const {
          'linking_code': 'CAABCDE123',
          'participant_id': 'P-1',
          'app_uuid': 'dev-1',
          'status': 'used',
          'mobile_linking_status': 'connected',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );
      await store.append(
        entryType: 'participant_linking_code_revoked',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_linking_code_revoked',
        data: const {
          'linking_code': 'CAABCDE123',
          'participant_id': 'P-1',
          'reason': 'superseded',
          'status': 'revoked',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );
      final events = await store.backend.readEventsReverse().toList();
      expect(
        events.map((e) => e.entryType),
        containsAll([
          'participant_linking_code_used',
          'participant_linking_code_revoked',
        ]),
      );
      await store.close();
    },
  );
}
