// Verifies: CAL-OPS-rave-sync-cooldown/B+D, CAL-OPS-rave-sync-hard-lockout/A
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
      expect(raveAuthCooldownHoursFromEnv({}), 24);
    });

    test('reads env values', () {
      expect(
        raveAuthFailureThresholdFromEnv({'RAVE_AUTH_FAILURE_THRESHOLD': '5'}),
        5,
      );
      expect(
        raveAuthCooldownHoursFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '12'}),
        12,
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
        raveAuthCooldownHoursFromEnv({'RAVE_AUTH_COOLDOWN_HOURS': ''}),
        24,
      );
    });
  });

  group('classifyLockout', () {
    final now = DateTime.utc(2026, 5, 19, 12, 0, 0);

    test('proceed when no failure history', () {
      final state = classifyLockout(
        row: const RaveLockoutRow(consecutiveAuthFailures: 0),
        cooldownHours: 24,
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
        cooldownHours: 24,
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
        cooldownHours: 24,
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
        cooldownHours: 24,
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
        cooldownHours: 24,
        now: now,
      );
      expect(state.result, LockoutCheckResult.pausedLocked);
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
}
