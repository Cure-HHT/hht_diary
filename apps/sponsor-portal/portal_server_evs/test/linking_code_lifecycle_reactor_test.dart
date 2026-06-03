import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/linking_code_lifecycle_reactor.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-linking-code-lifecycle/B+D
  late EventStore store;
  late StorageBackend backend;
  final t0 = DateTime.utc(2026, 6, 1, 12);

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('lcl.db');
    backend = SembastBackend(database: db);
    store = await openPortalEventStore(backend: backend);
    addTearDown(() => store.close());
  });

  Future<void> issue(
    String participantId,
    String code, {
    String siteId = 'site-1',
    String generatedBy = 'admin@site.org',
    String expiresAt = '2026-06-04T12:00:00.000Z',
    String purpose = 'link',
  }) =>
      store.append(
        entryType: 'participant_linking_code_issued',
        aggregateType: 'participant',
        aggregateId: participantId,
        eventType: 'participant_linking_code_issued',
        data: <String, Object?>{
          'linking_code': code,
          'participant_id': participantId,
          'site_id': siteId,
          'generated_by': generatedBy,
          'expires_at': expiresAt,
          'purpose': purpose,
          'status': 'active',
          'mobile_linking_status': 'linking_in_progress',
        },
        initiator: const AutomationInitiator(service: 'test'),
      );

  StoredEvent issuedEvent(String participantId, String code) =>
      StoredEvent.synthetic(
        eventId: 'syn-$code',
        aggregateId: participantId,
        aggregateType: 'participant',
        entryType: 'participant_linking_code_issued',
        eventType: 'participant_linking_code_issued',
        data: <String, dynamic>{
          'linking_code': code,
          'participant_id': participantId,
          'site_id': 'site-1',
          'generated_by': 'admin@site.org',
          'expires_at': '2026-06-04T12:00:00.000Z',
          'purpose': 'link',
          'status': 'active',
          'mobile_linking_status': 'linking_in_progress',
        },
        initiator: const AutomationInitiator(service: 'test'),
        clientTimestamp: t0,
        eventHash: 'fakehash',
      );

  test('supersession: new issued code revokes prior active code for P',
      () async {
    await issue('P-1', 'XXCODE0001');
    await issue('P-1', 'XXCODE0002');

    final reactor = LinkingCodeLifecycleReactor(
      eventStore: store,
      backend: backend,
    );
    await reactor.handleIssued(issuedEvent('P-1', 'XXCODE0002'));

    final rows = await backend.findViewRows('linking_codes');
    final c1 = rows.firstWhere((r) => r['linking_code'] == 'XXCODE0001');
    final c2 = rows.firstWhere((r) => r['linking_code'] == 'XXCODE0002');
    expect(c1['status'], 'revoked');
    expect(c2['status'], 'active');

    // participant_record must NOT be clobbered by the revoke of the old code:
    // it must reflect the current active code C2, not the revoked C1.
    final precs = await backend.findViewRows('participant_record');
    final p1 = precs.firstWhere((r) => r['aggregateId'] == 'P-1');
    expect(p1['linking_code'], 'XXCODE0002');
    expect(p1['status'], 'active');
  });

  test('collision self-heal: same code on two participants reissues fresh code',
      () async {
    await issue('P-1', 'CAFIXED01');
    await issue('P-2', 'CAFIXED01'); // forced collision (same code)

    final reactor = LinkingCodeLifecycleReactor(
      eventStore: store,
      backend: backend,
      linkingPrefix: 'CA',
    );
    await reactor.handleIssued(issuedEvent('P-2', 'CAFIXED01'));

    final precs = await backend.findViewRows('participant_record');
    final p1 = precs.firstWhere((r) => r['aggregateId'] == 'P-1');
    final p2 = precs.firstWhere((r) => r['aggregateId'] == 'P-2');

    expect(p1['linking_code'], 'CAFIXED01');
    expect(p1['status'], 'active');
    expect(p2['linking_code'], isNot('CAFIXED01'));
    expect(p2['status'], 'active');
    expect(p1['linking_code'], isNot(p2['linking_code']));
  });
}
