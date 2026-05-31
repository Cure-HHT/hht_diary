// Verifies: DIARY-DEV-participant-site-index/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('folds participant_synced_from_edc into participant_site_index; '
      're-sync overwrites the site', () async {
    final store = await _open('psi-1');
    await store.append(
      entryType: 'participant_synced_from_edc',
      aggregateType: 'participant',
      aggregateId: 'p-1',
      eventType: 'participant_synced_from_edc',
      data: <String, Object?>{'participant_id': 'p-1', 'site_id': 'site-1'},
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    var rows = await store.backend.findViewRows('participant_site_index');
    expect(rows, hasLength(1));
    expect(rows.single['participant_id'], 'p-1');
    expect(rows.single['site_id'], 'site-1');

    // Re-sync with a new site overwrites the row (participant site changed).
    await store.append(
      entryType: 'participant_synced_from_edc',
      aggregateType: 'participant',
      aggregateId: 'p-1',
      eventType: 'participant_synced_from_edc',
      data: <String, Object?>{'participant_id': 'p-1', 'site_id': 'site-2'},
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );
    rows = await store.backend.findViewRows('participant_site_index');
    expect(rows, hasLength(1));
    expect(rows.single['site_id'], 'site-2');
  });
}
