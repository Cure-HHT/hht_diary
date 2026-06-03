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
  // NOTE: `status` and `mobile_linking_status` in the seeded event data below are
  // the post-A3 wire contract. The production LinkParticipantAction does not emit
  // them until Task A3 hardens it, so these tests validate the projection against
  // the intended contract, not current production output.
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

  // Verifies: DIARY-DEV-linking-code-lifecycle/C
  test(
    'linking_codes revoked overwrites status and drops absent fields',
    () async {
      final store = await _open('lc-proj-3');

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
        entryType: 'participant_linking_code_revoked',
        aggregateId: 'P-1',
        aggregateType: 'participant',
        eventType: 'participant_linking_code_revoked',
        data: const <String, Object?>{
          'linking_code': 'CAABCDE123',
          'participant_id': 'P-1',
          'reason': 'superseded',
          'status': 'revoked',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

      final rows = await store.backend.findViewRows('linking_codes');
      final row = rows.firstWhere((r) => r['linking_code'] == 'CAABCDE123');
      expect(row['status'], 'revoked');
      // WholePayload overwrite: the thinner revoked event does not carry
      // expires_at, so it must be absent from the row.
      expect(row.containsKey('expires_at'), isFalse);

      await store.close();
    },
  );
}
