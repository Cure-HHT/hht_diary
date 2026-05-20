// Verifies: CAL-DEV-rave-auth-failure-classification/A+B+C,
//   CAL-OPS-rave-sync-hard-lockout/A, CAL-OPS-rave-sync-cooldown/C
//
// Integration tests for state-mutating helpers. Requires a Postgres
// instance with migration 013 applied (seeds the singleton row id=1).

@Tags(['integration'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    // Mirror the inline DB setup used by sites_sync_test.dart /
    // patients_sync_test.dart — no shared helper exists yet.
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    final config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: useSsl,
    );

    await Database.instance.initialize(config);
  });

  tearDownAll(() async {
    await Database.instance.close();
  });

  setUp(() async {
    // Reset singleton row before each test.
    final db = Database.instance;
    await db.executeWithContext('''
      UPDATE rave_sync_lockout
      SET consecutive_auth_failures = 0,
          locked_at = NULL,
          last_failure_at = NULL,
          last_failure_reason_code = NULL,
          last_success_at = NULL,
          last_unwedged_by_user_id = NULL,
          last_unwedged_at = NULL,
          updated_at = now()
      WHERE id = 1
      ''', context: UserContext.service);
  });

  test('recordAuthFailure increments counter', () async {
    await recordAuthFailure(reasonCode: 'AUTH001');
    final state = await checkLockout();
    expect(state.row.consecutiveAuthFailures, 1);
    expect(state.row.lastFailureReasonCode, 'AUTH001');
    expect(state.row.lastFailureAt, isNotNull);
    expect(state.row.lockedAt, isNull);
  });

  test('recordAuthFailure trips lockout at threshold', () async {
    final threshold = raveAuthFailureThresholdFromEnv({}); // default 3
    for (var i = 0; i < threshold; i++) {
      await recordAuthFailure();
    }
    final state = await checkLockout();
    expect(state.result, LockoutCheckResult.pausedLocked);
    expect(state.row.lockedAt, isNotNull);
    expect(state.row.consecutiveAuthFailures, threshold);
  });

  test('recordSyncSuccess resets counter and last_success_at', () async {
    await recordAuthFailure();
    await recordAuthFailure();
    await recordSyncSuccess();
    final state = await checkLockout();
    expect(state.row.consecutiveAuthFailures, 0);
    expect(state.row.lastSuccessAt, isNotNull);
    expect(state.row.lockedAt, isNull);
  });

  test('recordSyncSuccess does NOT clear locked_at', () async {
    final threshold = raveAuthFailureThresholdFromEnv({});
    for (var i = 0; i < threshold; i++) {
      await recordAuthFailure();
    }
    // Locked. Now if we somehow call recordSyncSuccess (shouldn't happen
    // in normal flow because gate blocks Rave calls), locked_at survives.
    await recordSyncSuccess();
    final state = await checkLockout();
    expect(
      state.row.lockedAt,
      isNotNull,
      reason: 'hard lockout is hard — only Unwedge clears locked_at',
    );
    expect(
      state.row.consecutiveAuthFailures,
      0,
      reason: 'counter still resets',
    );
  });

  test('recordAuthFailure does not re-bump locked_at after threshold', () async {
    // Verifies: CAL-OPS-rave-sync-hard-lockout (locked_at sticky)
    final threshold = raveAuthFailureThresholdFromEnv({});
    for (var i = 0; i < threshold; i++) {
      await recordAuthFailure();
    }
    final firstLockedAt = (await checkLockout()).row.lockedAt!;
    // Wait a tick so a re-bump would be observably later.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Simulate a post-lock failure (would normally be blocked by the gate, but
    // we're testing the SQL invariant directly).
    await recordAuthFailure();
    final secondLockedAt = (await checkLockout()).row.lockedAt!;
    expect(
      secondLockedAt,
      firstLockedAt,
      reason: 'locked_at must be sticky once set — only Unwedge clears it',
    );
  });
}
