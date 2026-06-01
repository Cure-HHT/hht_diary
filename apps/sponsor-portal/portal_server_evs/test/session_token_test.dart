import 'package:portal_server_evs/src/session_token.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-portal-session-token/A+B
  const key = 'super-secret-signing-key';
  final t0 = DateTime.utc(2026, 6, 1, 12);

  test('mint -> parse round-trips sid + uid', () {
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
    final parsed = parseSessionToken(token, signingKey: key);
    expect(parsed, isNotNull);
    expect(parsed!.sid, 'sid-1');
    expect(parsed.userId, 'jane@site.org');
  });

  test('tampered payload fails verification -> null', () {
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
    final tampered =
        '${token.substring(0, token.indexOf('.'))}X.${token.split('.').last}';
    expect(parseSessionToken(tampered, signingKey: key), isNull);
  });

  test('wrong signing key fails verification -> null', () {
    final token = mintSessionToken(
        sid: 'sid-1', userId: 'jane@site.org', signingKey: key, now: t0);
    expect(parseSessionToken(token, signingKey: 'other-key'), isNull);
  });
}
