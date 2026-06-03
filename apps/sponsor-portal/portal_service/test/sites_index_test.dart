// Verifies: DIARY-DEV-rave-edc-ingest/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('folds site_synced_from_edc into sites_index; re-sync upserts by '
      'site_id (deactivation = is_active=false, no row removal)', () async {
    final store = await _open('sites-1');
    await store.append(
      entryType: 'site_synced_from_edc',
      aggregateType: 'site',
      aggregateId: 'DEV-001',
      eventType: 'site_synced_from_edc',
      data: <String, Object?>{
        'site_id': 'DEV-001',
        'site_name': 'One',
        'site_number': '001',
        'is_active': true,
      },
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    var rows = await store.backend.findViewRows('sites_index');
    expect(rows, hasLength(1));
    expect(rows.single['site_id'], 'DEV-001');
    expect(rows.single['site_name'], 'One');
    expect(rows.single['is_active'], true);

    // Re-sync with is_active:false upserts the existing row (no removal).
    await store.append(
      entryType: 'site_synced_from_edc',
      aggregateType: 'site',
      aggregateId: 'DEV-001',
      eventType: 'site_synced_from_edc',
      data: <String, Object?>{
        'site_id': 'DEV-001',
        'site_name': 'One',
        'site_number': '001',
        'is_active': false,
      },
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );
    rows = await store.backend.findViewRows('sites_index');
    expect(rows, hasLength(1));
    expect(rows.single['is_active'], false);
  });
}
