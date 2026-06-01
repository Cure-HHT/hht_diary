// Verifies: DIARY-DEV-participant-status-projection/A+B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('participant_record folds linking-lifecycle events into one row; '
      'stamps latest entryType and key-wise merges data forward', () async {
    final store = await _open('precord-1');

    await store.append(
      entryType: 'participant_synced_from_edc',
      aggregateType: 'participant',
      aggregateId: 'p-1',
      eventType: 'participant_synced_from_edc',
      data: <String, Object?>{'participant_id': 'p-1', 'site_id': 's-1'},
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    var rows = await store.backend.findViewRows('participant_record');
    expect(rows, hasLength(1));
    expect(rows.single['entryType'], 'participant_synced_from_edc');
    expect(rows.single['site_id'], 's-1');

    // A later lifecycle event re-stamps entryType and merges its data forward,
    // leaving prior keys (site_id) intact.
    await store.append(
      entryType: 'participant_linking_code_issued',
      aggregateType: 'participant',
      aggregateId: 'p-1',
      eventType: 'participant_linking_code_issued',
      data: <String, Object?>{'linking_code': 'ABC', 'purpose': 'link'},
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    rows = await store.backend.findViewRows('participant_record');
    expect(rows, hasLength(1));
    expect(rows.single['entryType'], 'participant_linking_code_issued');
    expect(rows.single['site_id'], 's-1');
    expect(rows.single['linking_code'], 'ABC');
  });
}
