// Verifies: DIARY-DEV-linking-code-lifecycle/C — projection folds issued/used/revoked by code.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('linking_codes view folds status by code', () async {
    final store = await _open('lc-proj-1');

    await store.append(
      entryType: 'participant_linking_code_issued',
      aggregateId: 'P-1',
      aggregateType: 'participant',
      eventType: 'participant_linking_code_issued',
      data: const <String, Object?>{
        'linking_code': 'CAABCDE123',
        'participant_id': 'P-1',
        'site_id': 'S-1',
        'expires_at': '2026-06-06T00:00:00Z',
        'purpose': 'link',
        'status': 'active',
        'mobile_linking_status': 'linking_in_progress',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );

    var rows = await store.backend.findViewRows('linking_codes');
    expect(
      rows.firstWhere((r) => r['linking_code'] == 'CAABCDE123')['status'],
      'active',
    );

    await store.append(
      entryType: 'participant_linking_code_used',
      aggregateId: 'P-1',
      aggregateType: 'participant',
      eventType: 'participant_linking_code_used',
      data: const <String, Object?>{
        'linking_code': 'CAABCDE123',
        'participant_id': 'P-1',
        'app_uuid': 'dev-1',
        'status': 'used',
        'mobile_linking_status': 'connected',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );

    rows = await store.backend.findViewRows('linking_codes');
    expect(
      rows.firstWhere((r) => r['linking_code'] == 'CAABCDE123')['status'],
      'used',
    );

    await store.close();
  });

  test(
    'participant_record exposes mobile_linking_status + app_uuid after used',
    () async {
      final store = await _open('lc-proj-2');

      await store.append(
        entryType: 'participant_synced_from_edc',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_synced_from_edc',
        data: const <String, Object?>{
          'participant_id': 'P-1',
          'site_id': 'S-1',
        },
        initiator: const AutomationInitiator(service: 'edc_sync'),
      );

      await store.append(
        entryType: 'participant_linking_code_issued',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_linking_code_issued',
        data: const <String, Object?>{
          'linking_code': 'CAABCDE123',
          'participant_id': 'P-1',
          'site_id': 'S-1',
          'expires_at': '2026-06-06T00:00:00Z',
          'purpose': 'link',
          'status': 'active',
          'mobile_linking_status': 'linking_in_progress',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

      await store.append(
        entryType: 'participant_linking_code_used',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_linking_code_used',
        data: const <String, Object?>{
          'linking_code': 'CAABCDE123',
          'participant_id': 'P-1',
          'app_uuid': 'dev-1',
          'status': 'used',
          'mobile_linking_status': 'connected',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

      final rows = await store.backend.findViewRows('participant_record');
      final row = rows.singleWhere((r) => r['participant_id'] == 'P-1');
      expect(row['mobile_linking_status'], 'connected');
      expect(row['app_uuid'], 'dev-1');

      await store.close();
    },
  );
}
