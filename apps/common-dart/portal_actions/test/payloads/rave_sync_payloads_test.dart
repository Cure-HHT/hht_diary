import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('SiteSyncedFromEdcPayload round-trips', () {
    const p = SiteSyncedFromEdcPayload(
      siteId: 'DEV-001',
      siteName: 'Site One',
      siteNumber: '001',
      isActive: true,
      studyOid: 'STUDY-1',
      edcSyncedAt: '2026-05-31T00:00:00.000Z',
    );
    final json = p.toJson();
    expect(json['site_id'], 'DEV-001');
    expect(json['site_name'], 'Site One');
    expect(json['site_number'], '001');
    expect(json['is_active'], true);
    expect(json['study_oid'], 'STUDY-1');
    expect(json['edc_synced_at'], '2026-05-31T00:00:00.000Z');
  });

  test('edcSyncSucceededData carries reset counter', () {
    final d = edcSyncSucceededData(
      sitesCount: 3,
      participantsCount: 5,
      lastSuccessAt: '2026-05-31T00:00:00.000Z',
    );
    expect(d['consecutive_auth_failures'], 0);
    expect(d['sites_count'], 3);
    expect(d['participants_count'], 5);
    expect(d['last_success_at'], '2026-05-31T00:00:00.000Z');
  });

  test('raveAuthFailedData carries incremented counter', () {
    final d = raveAuthFailedData(
      consecutiveAuthFailures: 2,
      reasonCode: 'AUTH',
      failedAt: '2026-05-31T00:00:00.000Z',
    );
    expect(d['consecutive_auth_failures'], 2);
    expect(d['reason_code'], 'AUTH');
    expect(d['last_failure_at'], '2026-05-31T00:00:00.000Z');
  });

  test('raveHardLockoutData carries locked_at', () {
    final d = raveHardLockoutData(lockedAt: '2026-05-31T00:00:00.000Z');
    expect(d['locked_at'], '2026-05-31T00:00:00.000Z');
  });
}
