// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// JWT token generation and verification

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';

final _random = Random.secure();

/// JWT secret from environment
String get jwtSecret =>
    Platform.environment['JWT_SECRET'] ??
    'mvp-development-secret-change-in-production';

/// JWT payload structure
class JwtPayload {
  final String authCode;
  final String userId;
  final String? username;
  final int iat;
  final int? exp;
  final String? iss;

  JwtPayload({
    required this.authCode,
    required this.userId,
    this.username,
    required this.iat,
    this.exp,
    this.iss,
  });

  factory JwtPayload.fromJson(Map<String, dynamic> json) {
    return JwtPayload(
      authCode: json['authCode'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String?,
      iat: json['iat'] as int,
      exp: json['exp'] as int?,
      iss: json['iss'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'authCode': authCode,
    'userId': userId,
    if (username != null) 'username': username,
    'iat': iat,
    if (exp != null) 'exp': exp,
    if (iss != null) 'iss': iss,
  };
}

/// Create a JWT token
String createJwtToken({
  required String authCode,
  required String userId,
  String? username,
  Duration expiresIn = const Duration(days: 365),
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + expiresIn.inSeconds;

  final header = {'alg': 'HS256', 'typ': 'JWT'};
  final payload = {
    'authCode': authCode,
    'userId': userId,
    if (username != null) 'username': username,
    'iat': now,
    'exp': exp,
    'iss': 'hht-diary-mvp',
  };

  final headerBase64 = _base64UrlEncode(jsonEncode(header));
  final payloadBase64 = _base64UrlEncode(jsonEncode(payload));
  final message = '$headerBase64.$payloadBase64';

  final signature = _sign(message, jwtSecret);

  return '$message.$signature';
}

/// Verify a JWT token and return payload
JwtPayload? verifyJwtToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final message = '${parts[0]}.${parts[1]}';
    final signature = parts[2];

    // Verify signature
    final expectedSignature = _sign(message, jwtSecret);
    if (signature != expectedSignature) return null;

    // Decode payload
    final payloadJson = _base64UrlDecode(parts[1]);
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

    // Check expiration
    final exp = payload['exp'] as int?;
    if (exp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now > exp) return null;
    }

    // Validate required fields
    if (payload['authCode'] == null || payload['userId'] == null) {
      return null;
    }

    return JwtPayload.fromJson(payload);
  } catch (_) {
    return null;
  }
}

/// Verify Authorization header and return payload
JwtPayload? verifyAuthHeader(String? authHeader) {
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  final token = authHeader.substring(7);
  return verifyJwtToken(token);
}

String _base64UrlEncode(String input) {
  final bytes = utf8.encode(input);
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _base64UrlDecode(String input) {
  var padded = input;
  switch (input.length % 4) {
    case 2:
      padded = '$input==';
    case 3:
      padded = '$input=';
  }
  final bytes = base64Url.decode(padded);
  return utf8.decode(bytes);
}

String _sign(String message, String secret) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(message);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

/// Generate a random auth code (64 hex characters)
String generateAuthCode() {
  final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generate a UUID v4
String generateUserId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  // Set version (4) and variant (10xx)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
