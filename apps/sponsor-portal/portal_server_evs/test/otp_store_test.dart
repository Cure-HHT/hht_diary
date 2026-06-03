import 'package:portal_server_evs/src/otp_store.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-login-second-factor/A+B
  final t0 = DateTime.utc(2026, 6, 1, 12);
  OtpStore newStore() {
    var n = 0;
    return OtpStore(
      ttl: const Duration(minutes: 10),
      maxAttempts: 5,
      maxIssuesPerWindow: 3,
      issueWindow: const Duration(minutes: 15),
      codeGen: () => '00000${n++}', // 000000, 000001, ...
    );
  }

  test('issued code verifies once, then is single-use', () {
    final s = newStore();
    final code = s.issue(userId: 'a@x.org', now: t0);
    expect(s.verify(userId: 'a@x.org', code: code, now: t0), OtpResult.ok);
    expect(s.verify(userId: 'a@x.org', code: code, now: t0), OtpResult.invalid);
  });

  test('expired code is rejected', () {
    final s = newStore();
    final code = s.issue(userId: 'a@x.org', now: t0);
    expect(
      s.verify(
          userId: 'a@x.org',
          code: code,
          now: t0.add(const Duration(minutes: 11))),
      OtpResult.expired,
    );
  });

  test('wrong code counts attempts; cap forces re-request', () {
    final s = newStore();
    s.issue(userId: 'a@x.org', now: t0);
    for (var i = 0; i < 5; i++) {
      expect(s.verify(userId: 'a@x.org', code: 'nope', now: t0),
          OtpResult.invalid);
    }
    // 6th attempt: locked out -> code invalidated, must re-request.
    expect(s.verify(userId: 'a@x.org', code: 'nope', now: t0),
        OtpResult.tooManyAttempts);
  });

  test('issuing a new code invalidates the prior code for that user', () {
    final s = newStore();
    final first = s.issue(userId: 'a@x.org', now: t0);
    final second = s.issue(userId: 'a@x.org', now: t0);
    expect(
        s.verify(userId: 'a@x.org', code: first, now: t0), OtpResult.invalid);
    expect(s.verify(userId: 'a@x.org', code: second, now: t0), OtpResult.ok);
  });

  test('issuance is rate-limited per window', () {
    final s = newStore();
    s.issue(userId: 'a@x.org', now: t0);
    s.issue(userId: 'a@x.org', now: t0);
    s.issue(userId: 'a@x.org', now: t0);
    expect(() => s.issue(userId: 'a@x.org', now: t0),
        throwsA(isA<OtpRateLimited>()));
    // after the window, issuance is allowed again
    expect(s.issue(userId: 'a@x.org', now: t0.add(const Duration(minutes: 16))),
        isNotEmpty);
  });
}
