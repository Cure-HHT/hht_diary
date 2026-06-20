// Verifies: DIARY-DEV-outgoing-intent-correlation/B (durable participant-facing recall row)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test(
    'recall notice row appears on notice event, removed on ack(finalized)',
    () async {
      final db = await newDatabaseFactoryMemory().openDatabase('recall.db');
      final store = await openPortalEventStore(
        backend: SembastBackend(database: db),
      );
      final backend = store.backend;

      await store.append(
        entryType: 'questionnaire_recall_notice',
        aggregateType: 'questionnaire_recall_notice',
        aggregateId: 'P1:recall:QI1',
        eventType: 'questionnaire_recall_notice',
        data: <String, Object?>{
          'participant_id': 'P1',
          'instance_id': 'QI1',
          'study_event': 'Cycle 4 Day 1',
          'recalled_at': '2026-06-20T00:00:00Z',
          'flow_token': 'QST000009',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );
      var rows = await backend.findViewRows('questionnaire_recall_notice');
      expect(rows.where((r) => r['instance_id'] == 'QI1'), hasLength(1));

      await store.append(
        entryType: 'questionnaire_recall_acked',
        aggregateType: 'questionnaire_recall_notice',
        aggregateId: 'P1:recall:QI1',
        eventType: 'finalized',
        data: <String, Object?>{'instance_id': 'QI1', 'participant_id': 'P1'},
        initiator: const AutomationInitiator(service: 'test'),
      );
      rows = await backend.findViewRows('questionnaire_recall_notice');
      expect(rows.where((r) => r['instance_id'] == 'QI1'), isEmpty);

      await store.close();
    },
  );
}
