// Verifies: DIARY-OPS-rave-sync-cooldown/B+D, DIARY-OPS-rave-sync-hard-lockout/A
//
// Unit tests for rave_sync_lockout module. Uses in-memory state stubs to
// exercise pure logic without hitting Postgres.

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

void main() {
  group('lockout config', () {
    test('defaults when env unset', () {
      expect(raveAuthFailureThresholdFromEnv({}), 3);
      expect(raveAuthCooldownFromEnv({}), const Duration(hours: 24));
    });

    test('reads env values', () {
      expect(
        raveAuthFailureThresholdFromEnv({'RAVE_AUTH_FAILURE_THRESHOLD': '5'}),
        5,
      );
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '12'}),
        const Duration(hours: 12),
      );
    });

    test('non-numeric falls back to default', () {
      expect(
        raveAuthFailureThresholdFromEnv({
          'RAVE_AUTH_FAILURE_THRESHOLD': 'oops',
        }),
        3,
      );
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': ''}),
        const Duration(hours: 24),
      );
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': 'oops'}),
        const Duration(hours: 24),
      );
    });

    test('hours accepts fractional values', () {
      // 0.25 hours = 15 minutes.
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '0.25'}),
        const Duration(minutes: 15),
      );
    });

    test('minutes env var overrides hours when set', () {
      expect(
        raveAuthCooldownFromEnv({
          'RAVE_AUTH_COOLDOWN_MINUTES': '5',
          'RAVE_AUTH_COOLDOWN_HOURS': '24',
        }),
        const Duration(minutes: 5),
      );
    });

    test('minutes accepts fractional values (sub-minute granularity)', () {
      // 0.5 minutes = 30 seconds — useful for fast-iteration local tests.
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_MINUTES': '0.5'}),
        const Duration(seconds: 30),
      );
    });

    test('zero is a valid cooldown (no pause)', () {
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '0'}),
        Duration.zero,
      );
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_MINUTES': '0'}),
        Duration.zero,
      );
    });

    test('negative values fall back to default', () {
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '-1'}),
        const Duration(hours: 24),
      );
      expect(
        raveAuthCooldownFromEnv({'RAVE_AUTH_COOLDOWN_MINUTES': '-1'}),
        const Duration(hours: 24),
      );
    });
  });

  group('classifyLockout', () {
    final now = DateTime.utc(2026, 5, 19, 12, 0, 0);

    test('proceed when no failure history', () {
      final state = classifyLockout(
        row: const RaveLockoutRow(consecutiveAuthFailures: 0),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.proceed);
    });

    test('pausedLocked when locked_at set', () {
      final lockedAt = now.subtract(const Duration(hours: 5));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 3,
          lockedAt: lockedAt,
          lastFailureAt: lockedAt,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.pausedLocked);
      expect(state.lockedAt, lockedAt);
    });

    test('pausedCooldown when last_failure_at within window', () {
      final lastFail = now.subtract(const Duration(hours: 5));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 1,
          lastFailureAt: lastFail,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.pausedCooldown);
      expect(state.pausedUntil, lastFail.add(const Duration(hours: 24)));
    });

    test('proceed when last_failure_at outside window', () {
      final lastFail = now.subtract(const Duration(hours: 25));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 1,
          lastFailureAt: lastFail,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.proceed);
    });

    test('locked beats cooldown', () {
      final lastFail = now.subtract(const Duration(hours: 1));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 3,
          lockedAt: lastFail,
          lastFailureAt: lastFail,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.pausedLocked);
    });

    test('proceed when last success is after last failure', () {
      // Recent failure (would be in cooldown) but a later successful sync
      // supersedes it. last_failure_at stays for diagnostic context but no
      // longer gates new attempts.
      final lastFail = now.subtract(const Duration(hours: 5));
      final lastSuccess = now.subtract(const Duration(hours: 1));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 0,
          lastFailureAt: lastFail,
          lastSuccessAt: lastSuccess,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.proceed);
    });

    test('cooldown still active when success precedes failure', () {
      // Old success, then a fresh failure. Cooldown should be active.
      final lastSuccess = now.subtract(const Duration(hours: 10));
      final lastFail = now.subtract(const Duration(hours: 1));
      final state = classifyLockout(
        row: RaveLockoutRow(
          consecutiveAuthFailures: 1,
          lastFailureAt: lastFail,
          lastSuccessAt: lastSuccess,
        ),
        cooldown: const Duration(hours: 24),
        now: now,
      );
      expect(state.result, LockoutCheckResult.pausedCooldown);
    });
  });

  group('notifySlackWith', () {
    test('webhook unset is a no-op', () async {
      var called = false;
      final client = http_testing.MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      await notifySlackWith(client: client, webhookUrl: null, text: 'ping');
      expect(called, isFalse);
    });

    test('posts JSON body to webhook URL', () async {
      Uri? capturedUri;
      String? capturedBody;
      final client = http_testing.MockClient((req) async {
        capturedUri = req.url;
        capturedBody = req.body;
        return http.Response('ok', 200);
      });
      await notifySlackWith(
        client: client,
        webhookUrl: 'https://hooks.example/T/B/X',
        text: 'hi',
      );
      expect(capturedUri.toString(), 'https://hooks.example/T/B/X');
      expect(capturedBody, contains('"text":"hi"'));
    });

    test('non-2xx response is swallowed', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response('nope', 500),
      );
      // Should NOT throw.
      await notifySlackWith(
        client: client,
        webhookUrl: 'https://hooks.example/T/B/X',
        text: 'hi',
      );
    });

    test('client exception is swallowed', () async {
      final client = http_testing.MockClient(
        (_) async => throw http.ClientException('boom'),
      );
      await notifySlackWith(
        client: client,
        webhookUrl: 'https://hooks.example/T/B/X',
        text: 'hi',
      );
    });
  });

  group('alert message builders', () {
    // Verifies: DIARY-OPS-rave-alert-notification/A+D
    test(
      'auth-failure message includes env, counter, threshold, cooldown end',
      () {
        final cooldownEnd = DateTime.utc(2026, 5, 22, 12, 0, 0);
        final msg = buildAuthFailureSlackMessage(
          env: 'qa',
          counter: 2,
          threshold: 3,
          cooldownEnd: cooldownEnd,
        );
        expect(msg, contains('[qa]'));
        expect(msg, contains('2/3'));
        expect(msg, contains(cooldownEnd.toIso8601String()));
        expect(msg, contains('Rave auth failed'));
      },
    );

    // Verifies: DIARY-OPS-rave-alert-notification/B+D
    test('hard-lockout message is distinct and includes env', () {
      final msg = buildHardLockoutSlackMessage(env: 'uat');
      expect(msg, contains('[uat]'));
      expect(msg, contains('HARD LOCKOUT'));
      expect(msg, contains('Unwedge'));
      // Must be distinguishable from the per-failure message.
      expect(
        msg,
        isNot(contains('Rave auth failed')),
        reason:
            'lockout-trip alert must not be confused with per-failure alert',
      );
    });

    // Verifies: DIARY-OPS-rave-alert-notification/D — env tag always present
    test('builders use whatever env tag is passed (no hidden fallback)', () {
      expect(
        buildAuthFailureSlackMessage(
          env: 'dev',
          counter: 1,
          threshold: 3,
          cooldownEnd: DateTime.utc(2026, 5, 22),
        ),
        contains('[dev]'),
      );
      expect(buildHardLockoutSlackMessage(env: 'prod'), contains('[prod]'));
    });
  });
}
