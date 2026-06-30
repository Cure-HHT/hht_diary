import 'dart:convert';

import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

String _seg(Map<String, Object?> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

/// Builds an unsigned (emulator-style) JWT: header.payload.sig
String _fakeToken(Map<String, Object?> payload) =>
    '${_seg({'alg': 'none', 'typ': 'JWT'})}.${_seg(payload)}.x';

void main() {
  final future = DateTime.now().add(const Duration(hours: 1));
  final past = DateTime.now().subtract(const Duration(hours: 1));
  int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  // Verifies: DIARY-DEV-portal-login-identity-verification/A
  test('valid emulator token -> uid + email, isValid', () async {
    final token = _fakeToken({
      'sub': 'uid-123',
      'email': 'jane@site.org',
      'email_verified': true,
      'exp': secs(future),
    });
    final r = await verifyIdToken(token, useEmulator: true);
    expect(r.isValid, isTrue);
    expect(r.uid, 'uid-123');
    expect(r.email, 'jane@site.org');
  });

  // Verifies: DIARY-DEV-portal-login-identity-verification/B
  test('expired emulator token -> not valid, error set', () async {
    final token = _fakeToken({'sub': 'uid-123', 'exp': secs(past)});
    final r = await verifyIdToken(token, useEmulator: true);
    expect(r.isValid, isFalse);
    expect(r.error, isNotNull);
  });

  // Verifies: DIARY-DEV-portal-login-identity-verification/B
  test('token with no subject -> not valid', () async {
    final token = _fakeToken({'exp': secs(future)}); // no 'sub'
    final r = await verifyIdToken(token, useEmulator: true);
    expect(r.isValid, isFalse);
  });

  test('mfaInfo parsed from firebase claim', () async {
    final token = _fakeToken({
      'sub': 'uid-123',
      'exp': secs(future),
      'firebase': {
        'sign_in_second_factor': 'totp',
        'second_factor_identifier': 'factor-1',
      },
    });
    final r = await verifyIdToken(token, useEmulator: true);
    expect(r.mfaInfo?.isEnrolled, isTrue);
    expect(r.mfaInfo?.method, 'totp');
  });
}
