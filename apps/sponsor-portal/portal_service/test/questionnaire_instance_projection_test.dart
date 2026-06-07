// Verifies: DIARY-PRD-questionnaire-system/B — the questionnaire_instance view
//   tracks Completion Status per instance; a questionnaire_assigned event folds
//   into a row keyed by the instance id, carrying participant_id + type.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('questionnaire_assigned folds into a per-instance row', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('qi-1');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);
    addTearDown(store.close);

    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI-1',
      eventType: 'questionnaire_assigned',
      data: const <String, Object?>{
        'participant_id': 'P-1',
        'type': 'nose_hht',
        'study_event': 'Cycle 1 Day 1',
      },
      initiator: const UserInitiator('coordinator-1'),
    );

    final rows = await store.backend.findViewRows('questionnaire_instance');
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['aggregateId'], 'QI-1');
    expect(row['entryType'], 'questionnaire_assigned');
    expect(row['participant_id'], 'P-1');
    expect(row['type'], 'nose_hht');
    expect(row['study_event'], 'Cycle 1 Day 1');
  });
}
