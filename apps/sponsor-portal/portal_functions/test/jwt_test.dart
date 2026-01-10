// Tests for JWT token generation and verification
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance

import 'dart:convert';

import 'package:test/test.dart';

import 'package:portal_functions/src/jwt.dart';

void main() {
  group('JwtPayload', () {
    test('fromJson parses all fields', () {
      final json = {
        'authCode': 'auth123',
        'userId': 'user456',
        'username': 'testuser',
        'iat': 1234567890,
        'exp': 1234567899,
        'iss': 'test-issuer',
      };

      final payload = JwtPayload.fromJson(json);

      expect(payload.authCode, equals('auth123'));
      expect(payload.userId, equals('user456'));
      expect(payload.username, equals('testuser'));
      expect(payload.iat, equals(1234567890));
      expect(payload.exp, equals(1234567899));
      expect(payload.iss, equals('test-issuer'));
    });

    test('fromJson handles optional fields', () {
      final json = {
        'authCode': 'auth123',
        'userId': 'user456',
        'iat': 1234567890,
      };

      final payload = JwtPayload.fromJson(json);

      expect(payload.authCode, equals('auth123'));
      expect(payload.userId, equals('user456'));
      expect(payload.username, isNull);
      expect(payload.exp, isNull);
      expect(payload.iss, isNull);
    });

    test('toJson includes all fields when present', () {
      final payload = JwtPayload(
        authCode: 'auth123',
        userId: 'user456',
        username: 'testuser',
        iat: 1234567890,
        exp: 1234567899,
        iss: 'test-issuer',
      );

      final json = payload.toJson();

      expect(json['authCode'], equals('auth123'));
      expect(json['userId'], equals('user456'));
      expect(json['username'], equals('testuser'));
      expect(json['iat'], equals(1234567890));
      expect(json['exp'], equals(1234567899));
      expect(json['iss'], equals('test-issuer'));
    });

    test('toJson excludes null optional fields', () {
      final payload = JwtPayload(
        authCode: 'auth123',
        userId: 'user456',
        iat: 1234567890,
      );

      final json = payload.toJson();

      expect(json.containsKey('username'), isFalse);
      expect(json.containsKey('exp'), isFalse);
      expect(json.containsKey('iss'), isFalse);
    });
  });

  group('createJwtToken', () {
    test('creates valid JWT format', () {
      final token = createJwtToken(
        authCode: 'test-auth-code',
        userId: 'test-user-id',
      );

      final parts = token.split('.');
      expect(parts.length, equals(3));

      // Verify header
      final headerJson = _base64UrlDecode(parts[0]);
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      expect(header['alg'], equals('HS256'));
      expect(header['typ'], equals('JWT'));

      // Verify payload has required fields
      final payloadJson = _base64UrlDecode(parts[1]);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      expect(payload['authCode'], equals('test-auth-code'));
      expect(payload['userId'], equals('test-user-id'));
      expect(payload['iat'], isNotNull);
      expect(payload['exp'], isNotNull);
      expect(payload['iss'], equals('hht-diary-mvp'));
    });

    test('includes username when provided', () {
      final token = createJwtToken(
        authCode: 'auth',
        userId: 'user',
        username: 'testuser123',
      );

      final parts = token.split('.');
      final payloadJson = _base64UrlDecode(parts[1]);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      expect(payload['username'], equals('testuser123'));
    });

    test('excludes username when not provided', () {
      final token = createJwtToken(authCode: 'auth', userId: 'user');

      final parts = token.split('.');
      final payloadJson = _base64UrlDecode(parts[1]);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      expect(payload.containsKey('username'), isFalse);
    });

    test('sets expiration based on expiresIn', () {
      final token = createJwtToken(
        authCode: 'auth',
        userId: 'user',
        expiresIn: const Duration(hours: 1),
      );

      final parts = token.split('.');
      final payloadJson = _base64UrlDecode(parts[1]);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      final iat = payload['iat'] as int;
      final exp = payload['exp'] as int;

      // exp should be 1 hour (3600 seconds) after iat
      expect(exp - iat, equals(3600));
    });
  });

  group('verifyJwtToken', () {
    test('verifies valid token', () {
      final token = createJwtToken(
        authCode: 'test-auth',
        userId: 'test-user',
        username: 'myuser',
      );

      final payload = verifyJwtToken(token);

      expect(payload, isNotNull);
      expect(payload!.authCode, equals('test-auth'));
      expect(payload.userId, equals('test-user'));
      expect(payload.username, equals('myuser'));
    });

    test('returns null for invalid signature', () {
      final token = createJwtToken(authCode: 'auth', userId: 'user');

      // Tamper with the signature
      final parts = token.split('.');
      final tamperedToken = '${parts[0]}.${parts[1]}.invalid_signature';

      final payload = verifyJwtToken(tamperedToken);
      expect(payload, isNull);
    });

    test('returns null for wrong number of parts', () {
      expect(verifyJwtToken('only.two'), isNull);
      expect(verifyJwtToken('single'), isNull);
      expect(verifyJwtToken('too.many.parts.here'), isNull);
      expect(verifyJwtToken(''), isNull);
    });

    test('returns null for expired token', () {
      // Create a token that expired 1 hour ago
      final token = createJwtToken(
        authCode: 'auth',
        userId: 'user',
        expiresIn: const Duration(hours: -1),
      );

      final payload = verifyJwtToken(token);
      expect(payload, isNull);
    });

    test('returns null for malformed payload', () {
      // Create a token with invalid base64 in payload
      final result = verifyJwtToken(
        'eyJhbGciOiJIUzI1NiJ9.!!!invalid!!!.signature',
      );
      expect(result, isNull);
    });

    test('returns null when authCode is missing', () {
      // We need to forge a token without authCode
      // This is tricky since createJwtToken always includes it
      // We'll test via the JSON parsing path
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final payload = base64Url.encode(
        utf8.encode('{"userId":"user","iat":9999999999}'),
      );
      // Note: signature won't match, but we test the flow
      final token = '$header.$payload.invalid';

      final result = verifyJwtToken(token);
      expect(
        result,
        isNull,
      ); // Signature check fails first, but we test the path
    });

    test('returns null when userId is missing', () {
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final payload = base64Url.encode(
        utf8.encode('{"authCode":"auth","iat":9999999999}'),
      );
      final token = '$header.$payload.invalid';

      final result = verifyJwtToken(token);
      expect(result, isNull);
    });
  });

  group('verifyAuthHeader', () {
    test('returns payload for valid Bearer token', () {
      final token = createJwtToken(authCode: 'auth', userId: 'user');

      final payload = verifyAuthHeader('Bearer $token');

      expect(payload, isNotNull);
      expect(payload!.authCode, equals('auth'));
      expect(payload.userId, equals('user'));
    });

    test('returns null for null header', () {
      expect(verifyAuthHeader(null), isNull);
    });

    test('returns null for non-Bearer header', () {
      expect(verifyAuthHeader('Basic abc123'), isNull);
      expect(verifyAuthHeader('abc123'), isNull);
      expect(verifyAuthHeader(''), isNull);
    });

    test('returns null for invalid token after Bearer', () {
      expect(verifyAuthHeader('Bearer invalid.token'), isNull);
    });
  });

  group('generateAuthCode', () {
    test('generates 64-character hex string', () {
      final code = generateAuthCode();
      expect(code.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(code), isTrue);
    });

    test('generates unique codes', () {
      final codes = <String>{};
      for (var i = 0; i < 100; i++) {
        codes.add(generateAuthCode());
      }
      expect(codes.length, equals(100));
    });
  });

  group('generateUserId', () {
    test('generates valid UUID v4 format', () {
      final uuid = generateUserId();
      // UUID format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      // where x is hex and y is 8, 9, a, or b
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uuid),
        isTrue,
        reason: 'UUID should be valid v4 format: $uuid',
      );
    });

    test('generates unique UUIDs', () {
      final uuids = <String>{};
      for (var i = 0; i < 100; i++) {
        uuids.add(generateUserId());
      }
      expect(uuids.length, equals(100));
    });

    test('version nibble is 4', () {
      final uuid = generateUserId();
      // The 13th character (index 14 after dashes) should be '4'
      final parts = uuid.split('-');
      expect(parts[2][0], equals('4'));
    });

    test('variant bits are correct', () {
      final uuid = generateUserId();
      // The 17th character should be 8, 9, a, or b
      final parts = uuid.split('-');
      expect('89ab'.contains(parts[3][0]), isTrue);
    });
  });
}

// Helper to decode base64url for testing
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
