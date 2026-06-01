// Verifies: DIARY-DEV-rave-edc-ingest/C+D — the rave_sync_status recovery path:
//   a successful sync (edc_sync_succeeded) and an operator unwedge (rave_unwedged)
//   both clear the hard lockout (locked_at) and reopen the gate (classifyLockout
//   == proceed). Unwedge additionally clears the cooldown clock (last_failure_at)
//   so a re-attempt is not held in cooldown by lingering failure timestamps.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  const cfg = LockoutConfig(threshold: 3, cooldown: Duration(hours: 24));
  final t0 = DateTime.utc(2026, 5, 31, 12, 0, 0);

  Future<Map<String, Object?>> readStatus(EventStore store) async {
    final rows = await store.backend.findViewRows('rave_sync_status');
    return rows.isEmpty
        ? <String, Object?>{}
        : Map<String, Object?>.from(rows.single);
  }

  Future<void> seedHardLockout(EventStore store) async {
    for (var i = 1; i <= cfg.threshold; i++) {
      await store.append(
        entryType: 'rave_auth_failed',
        aggregateType: 'rave_sync',
        aggregateId: 'rave_sync',
        eventType: 'rave_auth_failed',
        data: raveAuthFailedData(
          consecutiveAuthFailures: i,
          reasonCode: 'AUTH',
          failedAt: t0.toIso8601String(),
        ),
        initiator: const AutomationInitiator(service: 'edc_sync'),
      );
    }
    await store.append(
      entryType: 'rave_hard_lockout_triggered',
      aggregateType: 'rave_sync',
      aggregateId: 'rave_sync',
      eventType: 'rave_hard_lockout_triggered',
      data: raveHardLockoutData(lockedAt: t0.toIso8601String()),
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );
  }

  test('successful sync clears locked_at and reopens the gate', () async {
    final store = await _open('rrp-success');
    await seedHardLockout(store);

    final locked = await readStatus(store);
    expect(locked['consecutive_auth_failures'], 3);
    expect(locked['locked_at'], isNotNull);
    expect(
      classifyLockout(
        locked,
        now: t0.add(const Duration(minutes: 1)),
        config: cfg,
      ).kind,
      LockoutKind.locked,
    );

    await store.append(
      entryType: 'edc_sync_succeeded',
      aggregateType: 'rave_sync',
      aggregateId: 'rave_sync',
      eventType: 'edc_sync_succeeded',
      data: edcSyncSucceededData(
        sitesCount: 2,
        participantsCount: 4,
        lastSuccessAt: t0.add(const Duration(minutes: 2)).toIso8601String(),
      ),
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    final recovered = await readStatus(store);
    expect(recovered['consecutive_auth_failures'], 0);
    expect(recovered['locked_at'], isNull);
    expect(
      classifyLockout(
        recovered,
        now: t0.add(const Duration(minutes: 3)),
        config: cfg,
      ).kind,
      LockoutKind.proceed,
    );
  });

  test('unwedge clears locked_at + last_failure_at; proceeds within the '
      'original cooldown window', () async {
    final store = await _open('rrp-unwedge');
    await seedHardLockout(store);

    final locked = await readStatus(store);
    expect(locked['locked_at'], isNotNull);

    // Dispatch the real action to capture the exact data shape it emits, then
    // append that event onto the rave_sync aggregate.
    final action = UnwedgeRaveSyncAction();
    final ctx = ActionContext(
      principal: Principal.user(
        userId: 'op-1',
        roles: const {'SystemOperator'},
        activeRole: 'SystemOperator',
      ),
      security: const SecurityDetails(),
      requestStartedAt: t0,
    );
    final exec = await action.execute(
      UnwedgeRaveSyncInput(reason: 'creds rotated'),
      ctx,
    );
    final draft = exec.events.single;
    await store.append(
      entryType: draft.entryType,
      aggregateType: draft.aggregateType,
      aggregateId: draft.aggregateId,
      eventType: draft.eventType,
      data: draft.data,
      initiator: const AutomationInitiator(service: 'edc_sync'),
    );

    final recovered = await readStatus(store);
    expect(recovered['consecutive_auth_failures'], 0);
    expect(recovered['locked_at'], isNull);
    expect(recovered['last_failure_at'], isNull);
    // `now` still inside the original 24h cooldown window of the seeded
    // failures, yet the cleared clock means we proceed (no lingering cooldown).
    expect(
      classifyLockout(
        recovered,
        now: t0.add(const Duration(minutes: 1)),
        config: cfg,
      ).kind,
      LockoutKind.proceed,
    );
  });
}
