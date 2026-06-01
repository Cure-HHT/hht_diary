import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Parsed identity-bearing session token (no role — role is session state).
class SessionToken {
  const SessionToken(
      {required this.sid, required this.userId, required this.issuedAt});
  final String sid;
  final String userId;
  final DateTime issuedAt;
}

String _b64(Object? json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String _hmac(String payload, String key) =>
    Hmac(sha256, utf8.encode(key)).convert(utf8.encode(payload)).toString();

/// Mints `base64url({sid,uid,iat}).hmacHex`. Identity-bearing: the active role
/// is NOT in the token (it is event-sourced session state).
// Implements: DIARY-DEV-portal-session-token/A+B
String mintSessionToken({
  required String sid,
  required String userId,
  required String signingKey,
  required DateTime now,
}) {
  final payload = _b64({
    'sid': sid,
    'uid': userId,
    'iat': now.toUtc().toIso8601String(),
  });
  return '$payload.${_hmac(payload, signingKey)}';
}

/// Returns the parsed token iff the HMAC verifies; else null.
// Implements: DIARY-DEV-portal-session-token/B
SessionToken? parseSessionToken(String token, {required String signingKey}) {
  final dot = token.lastIndexOf('.');
  if (dot <= 0) return null;
  final payload = token.substring(0, dot);
  final sig = token.substring(dot + 1);
  if (_hmac(payload, signingKey) != sig) return null;
  try {
    final norm = base64Url.normalize(payload);
    final map =
        jsonDecode(utf8.decode(base64Url.decode(norm))) as Map<String, Object?>;
    return SessionToken(
      sid: map['sid']! as String,
      userId: map['uid']! as String,
      issuedAt: DateTime.parse(map['iat']! as String),
    );
  } catch (_) {
    return null;
  }
}
