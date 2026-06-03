// Implements: DIARY-DEV-patient-ingest/B — stateless HS256 patient-token
//   verification (copied from diary_functions/jwt.dart; no dependency on the
//   legacy raw-Postgres package). createPatientJwt mints tokens for tests and
//   for the deferred issuance endpoint.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

String get _jwtSecret =>
    Platform.environment['JWT_SECRET'] ??
    'mvp-development-secret-change-in-production';

class PatientJwtPayload {
  PatientJwtPayload({required this.authCode, required this.userId, this.exp});
  final String authCode;
  final String userId;
  final int? exp;
}

String createPatientJwt({
  required String authCode,
  required String userId,
  Duration expiresIn = const Duration(days: 365),
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  final payload = {
    'authCode': authCode,
    'userId': userId,
    'iat': now,
    'exp': now + expiresIn.inSeconds,
    'iss': 'hht-diary-mvp',
  };
  final msg = '${_b64(jsonEncode(header))}.${_b64(jsonEncode(payload))}';
  return '$msg.${_sign(msg, _jwtSecret)}';
}

PatientJwtPayload? verifyPatientAuthHeader(String? authHeader) {
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  return _verify(authHeader.substring(7));
}

PatientJwtPayload? _verify(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final msg = '${parts[0]}.${parts[1]}';
    if (parts[2] != _sign(msg, _jwtSecret)) return null;
    final p = jsonDecode(_unb64(parts[1])) as Map<String, dynamic>;
    final exp = p['exp'] as int?;
    if (exp != null && DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
      return null;
    }
    if (p['authCode'] == null || p['userId'] == null) return null;
    return PatientJwtPayload(
      authCode: p['authCode'] as String,
      userId: p['userId'] as String,
      exp: exp,
    );
  } catch (_) {
    return null;
  }
}

String _b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

String _unb64(String s) {
  final pad = switch (s.length % 4) { 2 => '$s==', 3 => '$s=', _ => s };
  return utf8.decode(base64Url.decode(pad));
}

String _sign(String msg, String secret) => base64Url
    .encode(Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).bytes)
    .replaceAll('=', '');
