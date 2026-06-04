// Verifies: DIARY-DEV-participant-ingest/C — ingested diary events materialize into
//   the diary_entries view on the portal store.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('a finalized diary event materializes a diary_entries row', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('proj.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);

    await store.append(
      entryType: 'no_epistaxis_event',
      aggregateId: 'P-test:2025-10-15',
      aggregateType: diaryEntryAggregateType,
      eventType: 'finalized',
      data: const {'date': '2025-10-15'},
      initiator: const AutomationInitiator(service: 'test'),
    );

    final rows = await backend.findViewRows(diaryEntriesViewName);
    expect(rows.map((r) => r['aggregateId']), contains('P-test:2025-10-15'));
    await store.close();
  });
}
