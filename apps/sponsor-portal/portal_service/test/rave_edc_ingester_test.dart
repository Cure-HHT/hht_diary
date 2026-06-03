// Verifies: DIARY-DEV-rave-edc-ingest/A+B+C+D
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:portal_service/portal_service.dart';
import 'package:rave_integration/rave_integration.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

/// Local fake RaveClient that returns real RaveSite/RaveSubject model
/// instances (public const ctors) and can be wired to throw on fetch.
class _FakeRaveClient implements RaveClient {
  _FakeRaveClient({
    this.sites = const <RaveSite>[],
    this.subjects = const <RaveSubject>[],
    this.sitesThrows,
    this.failIfCalled = false,
  });

  final List<RaveSite> sites;
  final List<RaveSubject> subjects;
  final Object? sitesThrows;
  final bool failIfCalled;
  int getSitesCalls = 0;
  int getSubjectsCalls = 0;

  @override
  Future<List<RaveSite>> getSites({String? studyOid}) async {
    if (failIfCalled) {
      fail('getSites must not be called when locked/skipped');
    }
    getSitesCalls++;
    if (sitesThrows != null) throw sitesThrows!;
    return sites;
  }

  @override
  Future<List<RaveSubject>> getSubjects({required String studyOid}) async {
    if (failIfCalled) {
      fail('getSubjects must not be called when locked/skipped');
    }
    getSubjectsCalls++;
    return subjects;
  }

  @override
  Future<String> getVersion() async => '1.0';

  @override
  Future<String> getStudies() async => '<studies/>';

  @override
  void close() {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const cfg = LockoutConfig(threshold: 3, cooldown: Duration(hours: 24));
  final now = DateTime.utc(2026, 5, 31, 12, 0, 0);

  Future<Map<String, Object?>> readStatus(EventStore store) async {
    final rows = await store.backend.findViewRows('rave_sync_status');
    return rows.isEmpty
        ? <String, Object?>{}
        : Map<String, Object?>.from(rows.single);
  }

  test('syncAll emits site + participant edge events; counts correct; '
      're-sync is a no-op (dedupeByContent)', () async {
    final store = await _open('rei-1');
    final client = _FakeRaveClient(
      sites: const [
        RaveSite(
          oid: 'SITE-1',
          name: 'Site One',
          isActive: true,
          studySiteNumber: '001',
          studyOid: 'STUDY-1',
        ),
        RaveSite(oid: 'SITE-2', name: 'Site Two', isActive: false),
      ],
      subjects: const [
        RaveSubject(subjectKey: 'P-1', siteOid: 'SITE-1', siteNumber: '001'),
        RaveSubject(subjectKey: 'P-2', siteOid: 'SITE-2'),
      ],
    );
    final ingester = RaveEdcIngester(
      client: client,
      store: store,
      studyOids: const ['STUDY-1'],
      lockoutConfig: cfg,
    );

    final result = await ingester.syncAll(now: now);
    expect(result.skipped, isFalse);
    expect(result.sitesCount, 2);
    expect(result.participantsCount, 2);

    final sites = await store.backend.findViewRows('sites_index');
    expect(sites, hasLength(2));
    expect(sites.map((r) => r['site_id']).toSet(), {'SITE-1', 'SITE-2'});
    // siteNumber falls back to oid when studySiteNumber is null.
    final site2 = sites.firstWhere((r) => r['site_id'] == 'SITE-2');
    expect(site2['site_number'], 'SITE-2');

    final participants = await store.backend.findViewRows(
      'participant_site_index',
    );
    expect(participants, hasLength(2));
    expect(participants.map((r) => r['participant_id']).toSet(), {
      'P-1',
      'P-2',
    });
    final p1 = participants.firstWhere((r) => r['participant_id'] == 'P-1');
    expect(p1['site_id'], 'SITE-1');

    final statusAfterFirst = await readStatus(store);
    expect(statusAfterFirst['sites_count'], 2);
    expect(statusAfterFirst['participants_count'], 2);

    // Re-run identical sync: dedupeByContent makes the edge appends no-ops.
    // Observe via append's StoredEvent? return: a re-synced site/participant
    // returns null. Drive a direct re-append to prove the dedupe path, then
    // assert projection rows are unchanged.
    final dup = await store.append(
      entryType: 'site_synced_from_edc',
      aggregateType: 'site',
      aggregateId: 'SITE-1',
      eventType: 'site_synced_from_edc',
      data: const SiteSyncedFromEdcPayload(
        siteId: 'SITE-1',
        siteName: 'Site One',
        siteNumber: '001',
        isActive: true,
        studyOid: 'STUDY-1',
        edcSyncedAt: '2026-05-31T12:00:00.000Z',
      ).toJson(),
      initiator: const AutomationInitiator(service: 'edc_sync'),
      dedupeByContent: true,
    );
    expect(dup, isNull, reason: 'identical content dedupes to a no-op');

    final result2 = await ingester.syncAll(now: now);
    expect(result2.skipped, isFalse);
    final sites2 = await store.backend.findViewRows('sites_index');
    expect(sites2, hasLength(2));
    final participants2 = await store.backend.findViewRows(
      'participant_site_index',
    );
    expect(participants2, hasLength(2));
  });

  test('auth failure records rave_auth_failed and increments counter; '
      'threshold triggers hard lockout', () async {
    final store = await _open('rei-2');
    final client = _FakeRaveClient(
      sitesThrows: const RaveAuthenticationException(reasonCode: 'BAD_CREDS'),
    );
    final ingester = RaveEdcIngester(
      client: client,
      store: store,
      studyOids: const ['STUDY-1'],
      lockoutConfig: cfg,
    );

    // Each recorded failure stamps last_failure_at, so the lockout gate would
    // otherwise hold the next attempt in cooldown. Advance `now` past the
    // cooldown window between attempts so the gate re-opens and the counter can
    // accumulate to the hard-lockout threshold.
    final t1 = now;
    final t2 = now.add(const Duration(hours: 25));
    final t3 = t2.add(const Duration(hours: 25));

    await expectLater(
      ingester.syncAll(now: t1),
      throwsA(isA<RaveAuthenticationException>()),
    );
    var status = await readStatus(store);
    expect(status['consecutive_auth_failures'], 1);
    expect(status['reason_code'], 'BAD_CREDS');
    expect(status['locked_at'], isNull);

    // Second failure -> counter 2, still not locked.
    await expectLater(
      ingester.syncAll(now: t2),
      throwsA(isA<RaveAuthenticationException>()),
    );
    status = await readStatus(store);
    expect(status['consecutive_auth_failures'], 2);

    // Third failure -> counter 3 == threshold -> hard lockout recorded.
    await expectLater(
      ingester.syncAll(now: t3),
      throwsA(isA<RaveAuthenticationException>()),
    );
    status = await readStatus(store);
    expect(status['consecutive_auth_failures'], 3);
    expect(status['locked_at'], isNotNull);
    expect(
      classifyLockout(status, now: t3, config: cfg).kind,
      LockoutKind.locked,
    );
  });

  test('network failure records edc_sync_failed but does NOT advance the '
      'lockout counter (transient, classifyLockout -> proceed)', () async {
    final store = await _open('rei-3');
    final client = _FakeRaveClient(
      sitesThrows: const RaveNetworkException('down'),
    );
    final ingester = RaveEdcIngester(
      client: client,
      store: store,
      studyOids: const ['STUDY-1'],
      lockoutConfig: cfg,
    );

    await expectLater(
      ingester.syncAll(now: now),
      throwsA(isA<RaveNetworkException>()),
    );
    final status = await readStatus(store);
    // The failure is now recorded for audit/display...
    expect(status['last_sync_error_at'], isNotNull);
    expect(status['reason_code'], 'NETWORK');
    // ...but the lockout counter is NOT advanced (network blips never lock).
    final failures = (status['consecutive_auth_failures'] as int?) ?? 0;
    expect(failures, 0);
    expect(status['last_failure_at'], isNull);
    // The lockout gate is unaffected: a network failure leaves us free to retry.
    expect(
      classifyLockout(status, now: now, config: cfg).kind,
      LockoutKind.proceed,
    );
  });

  test('other RaveException records edc_sync_failed with EDC_ERROR and does '
      'NOT advance the lockout counter', () async {
    final store = await _open('rei-5');
    final client = _FakeRaveClient(
      sitesThrows: const RaveParseException('bad odm'),
    );
    final ingester = RaveEdcIngester(
      client: client,
      store: store,
      studyOids: const ['STUDY-1'],
      lockoutConfig: cfg,
    );

    await expectLater(
      ingester.syncAll(now: now),
      throwsA(isA<RaveParseException>()),
    );
    final status = await readStatus(store);
    expect(status['last_sync_error_at'], isNotNull);
    expect(status['reason_code'], 'EDC_ERROR');
    final failures = (status['consecutive_auth_failures'] as int?) ?? 0;
    expect(failures, 0);
    expect(status['last_failure_at'], isNull);
    expect(
      classifyLockout(status, now: now, config: cfg).kind,
      LockoutKind.proceed,
    );
  });

  test('locked status -> syncAll skips and does not call the client', () async {
    final store = await _open('rei-4');
    // Seed threshold auth failures to lock the rave_sync aggregate.
    for (var i = 1; i <= cfg.threshold; i++) {
      await store.append(
        entryType: 'rave_auth_failed',
        aggregateType: 'rave_sync',
        aggregateId: 'rave_sync',
        eventType: 'rave_auth_failed',
        data: raveAuthFailedData(
          consecutiveAuthFailures: i,
          reasonCode: 'AUTH',
          failedAt: now.toIso8601String(),
        ),
        initiator: const AutomationInitiator(service: 'edc_sync'),
      );
    }
    final locked = await readStatus(store);
    expect(
      classifyLockout(locked, now: now, config: cfg).kind,
      LockoutKind.locked,
    );

    final client = _FakeRaveClient(failIfCalled: true);
    final ingester = RaveEdcIngester(
      client: client,
      store: store,
      studyOids: const ['STUDY-1'],
      lockoutConfig: cfg,
    );
    final result = await ingester.syncAll(now: now);
    expect(result.skipped, isTrue);
    expect(result.sitesCount, 0);
    expect(result.participantsCount, 0);
    expect(client.getSitesCalls, 0);
    expect(client.getSubjectsCalls, 0);
  });
}
