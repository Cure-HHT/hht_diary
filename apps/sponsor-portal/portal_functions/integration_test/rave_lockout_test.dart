// Verifies: CAL-DEV-rave-auth-failure-classification/A+B+C,
//   CAL-OPS-rave-sync-hard-lockout/A, CAL-OPS-rave-sync-cooldown/C
//
// Integration tests for state-mutating helpers. Requires a Postgres
// instance with migration 013 applied (seeds the singleton row id=1).

@Tags(['integration'])
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show OTel;
import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    // OTel must be initialized before any logWithTrace call (which fires
    // inside recordAuthFailure on every auth-fail path). Without this,
    // OTel.tracerProvider throws an APITracerProvider cast error.
    // Mirrors sites_sync_test.dart's OTel setup.
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-integration-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );

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
    await OTel.shutdown();
    await OTel.reset();
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

  test('syncSitesIfNeeded skips Rave call when locked', () async {
    // Verifies: CAL-OPS-rave-sync-hard-lockout/B
    // Trip lockout.
    final threshold = raveAuthFailureThresholdFromEnv({});
    for (var i = 0; i < threshold; i++) {
      await recordAuthFailure();
    }
    // Now call sync — it must NOT call Rave (we'd see auth fails increment
    // the counter if it did). We assert by counter staying constant.
    final result = await syncSitesIfNeeded();
    expect(result, isNotNull);
    expect(result!.paused, isTrue);
    expect(result.pausedReason, 'locked');
    final state = await checkLockout();
    expect(
      state.row.consecutiveAuthFailures,
      threshold,
      reason: 'gate must not increment counter',
    );
  });

  group('endpoints (CUR-1361)', () {
    // Verifies: CAL-OPS-rave-unwedge-authz/A+B,
    //   CAL-GUI-dev-admin-rave-sync-card/A
    //
    // Uses [requirePortalAuthOverride] to bypass Identity Platform token
    // verification — the unit under test is the handler's authz + business
    // logic, not token minting. Override lives in portal_auth.dart and is
    // honored by requirePortalAuth (production callsite).
    const testDevAdminId = '99991361-0000-0000-0000-000000000001';
    const testDevAdminEmail = 'devadmin@rave-lockout-test.example.com';
    const testNonAdminId = '99991361-0000-0000-0000-000000000002';
    const testNonAdminEmail = 'investigator@rave-lockout-test.example.com';

    Request makeRequest(String method, String path, [Object? body]) {
      return Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {'content-type': 'application/json'},
      );
    }

    Future<Map<String, dynamic>> readJson(Response response) async {
      final chunks = await response.read().toList();
      return jsonDecode(utf8.decode(chunks.expand((c) => c).toList()))
          as Map<String, dynamic>;
    }

    setUpAll(() async {
      // The unwedge handler casts user.id to ::uuid and writes
      // last_unwedged_by_user_id (FK -> portal_users.id), so the dev-admin
      // row must exist. Non-admin row is created for symmetry (handlers do
      // not write its id, but a real-looking fixture is cheaper than
      // explaining the asymmetry).
      final db = Database.instance;
      await db.execute(
        '''
        INSERT INTO portal_users (id, email, name, status)
        VALUES (@id::uuid, @email, 'Test Dev Admin (rave-lockout)', 'active')
        ON CONFLICT (LOWER(email)) DO NOTHING
        ''',
        parameters: {'id': testDevAdminId, 'email': testDevAdminEmail},
      );
      await db.execute(
        '''
        INSERT INTO portal_users (id, email, name, status)
        VALUES (@id::uuid, @email, 'Test Investigator (rave-lockout)', 'active')
        ON CONFLICT (LOWER(email)) DO NOTHING
        ''',
        parameters: {'id': testNonAdminId, 'email': testNonAdminEmail},
      );
    });

    tearDownAll(() async {
      // Best-effort cleanup. Test rows are namespaced under
      // 99991361-* and *@rave-lockout-test.example.com so collisions
      // with other suites are not possible.
      final db = Database.instance;
      // Clear FK first so portal_users DELETE doesn't fail.
      await db.executeWithContext(
        '''
        UPDATE rave_sync_lockout
        SET last_unwedged_by_user_id = NULL
        WHERE id = 1 AND last_unwedged_by_user_id = @id::uuid
        ''',
        parameters: {'id': testDevAdminId},
        context: UserContext.service,
      );
      await db.execute(
        'DELETE FROM portal_users WHERE email LIKE @pattern',
        parameters: {'pattern': '%@rave-lockout-test.example.com'},
      );
    });

    tearDown(() {
      requirePortalAuthOverride = null;
    });

    PortalUser devAdmin() => PortalUser(
      id: testDevAdminId,
      email: testDevAdminEmail,
      name: 'Test Dev Admin (rave-lockout)',
      roles: const ['Developer Admin'],
      activeRole: 'Developer Admin',
      status: 'active',
    );

    PortalUser nonAdmin() => PortalUser(
      id: testNonAdminId,
      email: testNonAdminEmail,
      name: 'Test Investigator (rave-lockout)',
      roles: const ['Investigator'],
      activeRole: 'Investigator',
      status: 'active',
    );

    test('GET /rave/lockout returns 403 for non-dev-admin', () async {
      requirePortalAuthOverride = (_) async => nonAdmin();
      final response = await getRaveLockoutStateHandler(
        makeRequest('GET', '/api/v1/portal/dev-admin/rave/lockout'),
      );
      expect(response.statusCode, 403);
    });

    test('GET /rave/lockout returns 401 for unauthenticated request', () async {
      requirePortalAuthOverride = (_) async => null;
      final response = await getRaveLockoutStateHandler(
        makeRequest('GET', '/api/v1/portal/dev-admin/rave/lockout'),
      );
      expect(response.statusCode, 401);
    });

    test('GET /rave/lockout returns full state for dev-admin', () async {
      requirePortalAuthOverride = (_) async => devAdmin();
      await recordAuthFailure(reasonCode: 'TEST');

      final response = await getRaveLockoutStateHandler(
        makeRequest('GET', '/api/v1/portal/dev-admin/rave/lockout'),
      );
      expect(response.statusCode, 200);
      final body = await readJson(response);
      expect(body['state'], 'cooldown');
      expect(body['consecutive_auth_failures'], 1);
      expect(body['threshold'], 3);
      expect(body['cooldown_hours'], 24);
      expect(body['last_failure_reason_code'], 'TEST');
      expect(body['last_failure_at'], isNotNull);
      expect(body['locked_at'], isNull);
      expect(body['paused_until'], isNotNull);
    });

    test('POST /rave/unwedge returns 403 for non-dev-admin', () async {
      requirePortalAuthOverride = (_) async => nonAdmin();
      final response = await unwedgeRaveHandler(
        makeRequest('POST', '/api/v1/portal/dev-admin/rave/unwedge'),
      );
      expect(response.statusCode, 403);
    });

    test('POST /rave/unwedge clears counter + writes UNWEDGE row', () async {
      requirePortalAuthOverride = (_) async => devAdmin();
      final threshold = raveAuthFailureThresholdFromEnv({});
      for (var i = 0; i < threshold; i++) {
        await recordAuthFailure();
      }
      // Pre-condition: locked.
      expect((await checkLockout()).row.lockedAt, isNotNull);

      final response = await unwedgeRaveHandler(
        makeRequest('POST', '/api/v1/portal/dev-admin/rave/unwedge'),
      );
      expect(response.statusCode, 200);
      final body = await readJson(response);
      expect(body['unwedged_at'], isNotNull);
      expect(body['probe'], isA<Map>());
      expect(body['state_after'], isA<Map>());
      // The probe likely fails (Rave not configured in integration env);
      // either way the clear path must have run.
      expect(body['state_after']['locked'], isFalse);

      // DB invariants: locked_at cleared, last_unwedged_by_user_id set.
      final db = Database.instance;
      final lockoutRow = await db.executeWithContext('''
        SELECT locked_at, last_unwedged_by_user_id::text, last_unwedged_at
        FROM rave_sync_lockout WHERE id = 1
        ''', context: UserContext.service);
      expect(lockoutRow.first[0], isNull, reason: 'locked_at must be cleared');
      expect(lockoutRow.first[1], testDevAdminId);
      expect(lockoutRow.first[2], isNotNull);

      // UNWEDGE row written to edc_sync_log with triggered_by metadata.
      final logRow = await db.executeWithContext('''
        SELECT operation, metadata
        FROM edc_sync_log
        WHERE operation = 'UNWEDGE'
        ORDER BY sync_id DESC
        LIMIT 1
        ''', context: UserContext.service);
      expect(logRow, isNotEmpty);
      expect(logRow.first[0], 'UNWEDGE');
      // metadata is jsonb (Map) returned from postgres driver.
      final metadata = logRow.first[1];
      final metadataMap = metadata is String
          ? jsonDecode(metadata) as Map<String, dynamic>
          : metadata as Map<String, dynamic>;
      expect(metadataMap['triggered_by'], 'unwedge');
      expect(metadataMap['unwedged_by_user_id'], testDevAdminId);
    });
  });

  test('lockout-recovery happy path', () async {
    // Verifies: CAL-OPS-rave-sync-cooldown/C, CAL-OPS-rave-sync-hard-lockout/A+B
    //
    // End-to-end capstone: walks the full lockout lifecycle in one test —
    // clean → cooldown → gate-skip → locked → success-resets-counter (but
    // not locked_at) → unwedge-clears-locked_at → proceed.
    //
    // Skips last_unwedged_by_user_id in the simulated unwedge UPDATE: the
    // FK to portal_users requires a fixture row that lives only inside the
    // 'endpoints' group's setUpAll. What matters here is the behavior — that
    // clearing locked_at lets checkLockout return proceed again.

    // 1. Start clean — counter 0, no cooldown, not locked.
    var state = await checkLockout();
    expect(state.result, LockoutCheckResult.proceed);

    // 2. Trip cooldown with one auth failure.
    await recordAuthFailure(reasonCode: 'AUTH001');
    state = await checkLockout();
    expect(state.result, LockoutCheckResult.pausedCooldown);

    // 3. syncSitesIfNeeded must skip the Rave call.
    final pausedResult = await syncSitesIfNeeded();
    expect(pausedResult, isNotNull);
    expect(pausedResult!.paused, isTrue);
    expect(pausedResult.pausedReason, 'cooldown');

    // 4. Two more failures → hard lockout.
    await recordAuthFailure();
    await recordAuthFailure();
    state = await checkLockout();
    expect(state.result, LockoutCheckResult.pausedLocked);

    // 5. Successful sync (simulated by calling recordSyncSuccess directly)
    //    resets counter but does NOT clear locked_at.
    await recordSyncSuccess();
    state = await checkLockout();
    expect(state.row.consecutiveAuthFailures, 0);
    expect(state.row.lockedAt, isNotNull);

    // 6. Unwedge clears locked_at.
    final db = Database.instance;
    await db.executeWithContext('''
      UPDATE rave_sync_lockout
      SET locked_at = NULL,
          last_unwedged_at = now()
      WHERE id = 1
      ''', context: UserContext.service);
    state = await checkLockout();
    expect(state.result, LockoutCheckResult.proceed);
  });

  group('buildRaveSyncBlock (CUR-1361)', () {
    // setUp is already resetting the lockout row per outer test setUp.

    test('returns state=ok when clean', () async {
      final block = await buildRaveSyncBlock();
      expect(block['state'], 'ok');
      expect(block.containsKey('since'), isFalse);
      expect(block.containsKey('paused_until'), isFalse);
    });

    test('returns state=cooldown with paused_until when in cooldown', () async {
      await recordAuthFailure();
      final block = await buildRaveSyncBlock();
      expect(block['state'], 'cooldown');
      expect(block['paused_until'], isA<String>());
      expect(block.containsKey('since'), isFalse);
    });

    test('returns state=locked with since when locked', () async {
      final threshold = raveAuthFailureThresholdFromEnv({});
      for (var i = 0; i < threshold; i++) {
        await recordAuthFailure();
      }
      final block = await buildRaveSyncBlock();
      expect(block['state'], 'locked');
      expect(block['since'], isA<String>());
    });
  });
}
