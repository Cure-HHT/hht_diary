import 'package:portal_server_evs/src/password_reset_code_store.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-reset-code-lifecycle/A+B+C
  final t0 = DateTime.utc(2026, 6, 1, 12);
  PasswordResetCodeStore newStore() {
    var n = 0;
    return PasswordResetCodeStore(
      maxIssuesPerWindow: 3,
      issueWindow: const Duration(minutes: 15),
      codeGen: () => 'R-${n++}',
    );
  }

  test('issued code validates to its email; consume makes it single-use', () {
    final s = newStore();
    final code = s.issue(email: 'a@x.org', now: t0);
    expect(s.validate(code, now: t0)?.email, 'a@x.org');
    s.consume(code);
    expect(s.validate(code, now: t0), isNull);
  });

  test('code expires after 24h', () {
    final s = newStore();
    final code = s.issue(email: 'a@x.org', now: t0);
    expect(s.validate(code, now: t0.add(const Duration(hours: 23))), isNotNull);
    expect(s.validate(code, now: t0.add(const Duration(hours: 25))), isNull);
  });

  test('issuing a new code invalidates the prior unused code', () {
    final s = newStore();
    final first = s.issue(email: 'a@x.org', now: t0);
    final second = s.issue(email: 'a@x.org', now: t0);
    expect(s.validate(first, now: t0), isNull);
    expect(s.validate(second, now: t0)?.email, 'a@x.org');
  });

  test('issuance is rate-limited per window', () {
    final s = newStore();
    s.issue(email: 'a@x.org', now: t0);
    s.issue(email: 'a@x.org', now: t0);
    s.issue(email: 'a@x.org', now: t0);
    expect(() => s.issue(email: 'a@x.org', now: t0),
        throwsA(isA<PasswordResetRateLimited>()));
    expect(s.issue(email: 'a@x.org', now: t0.add(const Duration(minutes: 16))),
        isNotEmpty);
  });
}
