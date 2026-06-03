import 'package:portal_service/portal_service.dart';
import 'package:test/test.dart';

void main() {
  const cfg = LockoutConfig(threshold: 3, cooldown: Duration(hours: 24));
  final t0 = DateTime.utc(2026, 5, 31, 12, 0, 0);

  test('clean row -> proceed', () {
    expect(
      classifyLockout(const {}, now: t0, config: cfg).kind,
      LockoutKind.proceed,
    );
  });
  test('counter at threshold -> locked', () {
    final row = {
      'consecutive_auth_failures': 3,
      'last_failure_at': t0.toIso8601String(),
    };
    expect(classifyLockout(row, now: t0, config: cfg).kind, LockoutKind.locked);
  });
  test('recent failure below threshold -> cooldown', () {
    final row = {
      'consecutive_auth_failures': 1,
      'last_failure_at': t0
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
    };
    final d = classifyLockout(row, now: t0, config: cfg);
    expect(d.kind, LockoutKind.cooldown);
    expect(d.cooldownUntil!.isAfter(t0), isTrue);
  });
  test('success after failure supersedes cooldown -> proceed', () {
    final row = {
      'consecutive_auth_failures': 0,
      'last_failure_at': t0
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
      'last_success_at': t0
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    };
    expect(
      classifyLockout(row, now: t0, config: cfg).kind,
      LockoutKind.proceed,
    );
  });
  test('LockoutConfig.fromEnv parses minutes then hours then default', () {
    expect(
      LockoutConfig.fromEnv({'RAVE_AUTH_COOLDOWN_MINUTES': '30'}).cooldown,
      const Duration(minutes: 30),
    );
    expect(
      LockoutConfig.fromEnv({'RAVE_AUTH_COOLDOWN_HOURS': '2'}).cooldown,
      const Duration(hours: 2),
    );
    expect(LockoutConfig.fromEnv({}).cooldown, const Duration(hours: 24));
    expect(
      LockoutConfig.fromEnv({'RAVE_AUTH_FAILURE_THRESHOLD': '5'}).threshold,
      5,
    );
  });
}
