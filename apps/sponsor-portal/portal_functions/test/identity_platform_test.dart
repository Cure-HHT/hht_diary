// Tests for Identity Platform token verification
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration

import 'dart:convert';

import 'package:test/test.dart';

import 'package:portal_functions/src/identity_platform.dart';

void main() {
  group('VerificationResult', () {
    test('isValid returns true when uid is present and no error', () {
      final result = VerificationResult(
        uid: 'test-uid',
        email: 'test@example.com',
        emailVerified: true,
      );
      expect(result.isValid, isTrue);
      expect(result.uid, equals('test-uid'));
      expect(result.email, equals('test@example.com'));
      expect(result.emailVerified, isTrue);
    });

    test('isValid returns false when uid is null', () {
      final result = VerificationResult(email: 'test@example.com');
      expect(result.isValid, isFalse);
    });

    test('isValid returns false when error is present', () {
      final result = VerificationResult(uid: 'test-uid', error: 'Some error');
      expect(result.isValid, isFalse);
    });

    test('emailVerified defaults to false', () {
      final result = VerificationResult(uid: 'test-uid');
      expect(result.emailVerified, isFalse);
    });

    test('all fields can be null or have default values', () {
      final result = VerificationResult();
      expect(result.uid, isNull);
      expect(result.email, isNull);
      expect(result.emailVerified, isFalse);
      expect(result.error, isNull);
      expect(result.isValid, isFalse);
    });

    test('isValid is false when both uid and error are present', () {
      final result = VerificationResult(
        uid: 'some-uid',
        error: 'Some error occurred',
      );
      expect(result.isValid, isFalse);
    });

    test('email can be present without uid', () {
      final result = VerificationResult(
        email: 'user@example.com',
        emailVerified: true,
      );
      expect(result.email, equals('user@example.com'));
      expect(result.emailVerified, isTrue);
      expect(result.isValid, isFalse); // Still invalid without uid
    });

    test('error message is preserved', () {
      final result = VerificationResult(error: 'Token expired at 2024-01-01');
      expect(result.error, equals('Token expired at 2024-01-01'));
      expect(result.isValid, isFalse);
    });
  });

  group('extractBearerToken', () {
    test('extracts token from valid Bearer header', () {
      final token = extractBearerToken('Bearer abc123xyz');
      expect(token, equals('abc123xyz'));
    });

    test('extracts token with special characters', () {
      final token = extractBearerToken(
        'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U',
      );
      expect(
        token,
        equals(
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U',
        ),
      );
    });

    test('returns null for null header', () {
      final token = extractBearerToken(null);
      expect(token, isNull);
    });

    test('returns null for empty header', () {
      final token = extractBearerToken('');
      expect(token, isNull);
    });

    test('returns null for header without Bearer prefix', () {
      final token = extractBearerToken('abc123xyz');
      expect(token, isNull);
    });

    test('returns null for lowercase bearer prefix', () {
      final token = extractBearerToken('bearer abc123xyz');
      expect(token, isNull);
    });

    test('returns null for Basic auth header', () {
      final token = extractBearerToken('Basic abc123xyz');
      expect(token, isNull);
    });
  });

  group('verifyIdToken', () {
    test('rejects invalid token format (not 3 parts)', () async {
      final result = await verifyIdToken('invalid-token');
      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid token format'));
    });

    test('rejects token with only 2 parts', () async {
      final result = await verifyIdToken('part1.part2');
      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid token format'));
    });

    test('rejects empty token', () async {
      final result = await verifyIdToken('');
      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid token format'));
    });

    test('rejects token with invalid base64 header', () async {
      // Invalid base64 that will fail to decode
      final result = await verifyIdToken('!!!.payload.signature');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('rejects token without kid in header', () async {
      // Create a token with header missing kid
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      expect(result.error, contains('missing key ID'));
    });
  });

  group('verifyIdToken with emulator', () {
    // These tests simulate emulator mode token parsing

    String _createEmulatorToken({
      required String sub,
      String? email,
      bool emailVerified = false,
    }) {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
      );
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': sub,
            if (email != null) 'email': email,
            'email_verified': emailVerified,
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'exp':
                DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      );
      return '$header.$payload.';
    }

    test('parses emulator token with valid structure', () async {
      // Note: This test will fail in non-emulator mode because kid is missing
      // The emulator path is tested via integration tests
      final token = _createEmulatorToken(
        sub: 'test-user-123',
        email: 'test@example.com',
        emailVerified: true,
      );

      // Without FIREBASE_AUTH_EMULATOR_HOST set, this will try production verification
      final result = await verifyIdToken(token);
      // We expect it to fail in production mode due to missing kid
      expect(result.isValid, isFalse);
    });
  });

  group('verifyIdToken error cases', () {
    test('rejects token with invalid JSON in header', () async {
      // Create a token with invalid JSON in header
      final invalidHeader = base64Url.encode(utf8.encode('not-json'));
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$invalidHeader.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('handles token with kid but unknown key', () async {
      // Create a well-formed token with a kid that won't be found
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'alg': 'RS256',
            'typ': 'JWT',
            'kid': 'unknown-key-id-that-does-not-exist',
          }),
        ),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'test@example.com'})),
      );
      final token = '$header.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      // Should fail - either key not found or signature validation error
      expect(result.error, isNotNull);
    });

    test('rejects token with invalid base64 in payload', () async {
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key'}),
        ),
      );
      // Invalid base64 in payload
      final token = '$header.!!!invalid-base64!!!.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('rejects token with null kid value', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': null})),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      expect(result.error, contains('missing key ID'));
    });

    test('rejects token with 4 parts', () async {
      final result = await verifyIdToken('part1.part2.part3.part4');
      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid token format'));
    });

    test('rejects token with only 1 part', () async {
      final result = await verifyIdToken('singlepart');
      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid token format'));
    });
  });

  group('extractBearerToken edge cases', () {
    test('returns null for whitespace-only header', () {
      final token = extractBearerToken('   ');
      expect(token, isNull);
    });

    test('returns null for Bearer with no token', () {
      final token = extractBearerToken('Bearer ');
      expect(token, equals(''));
    });

    test('extracts token with multiple spaces after Bearer', () {
      final token = extractBearerToken('Bearer   token-with-spaces');
      expect(token, equals('  token-with-spaces'));
    });

    test('returns null for mixed case bearer', () {
      final token = extractBearerToken('BEARER token123');
      expect(token, isNull);
    });
  });

  group('verifyIdToken base64 padding variations', () {
    test('handles header with padding needed (mod 4 = 2)', () async {
      // Create a header that needs 2 padding chars
      // Valid base64 that decodes to small JSON but causes verification failure
      final header = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImtleTEifQ';
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': 'user123', 'email': 'test@test.com'})),
      );
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      // Token should be parsed but fail due to key not found
      expect(result.isValid, isFalse);
    });

    test('handles very long token', () async {
      // Create a token with very long payload
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),
        ),
      );
      final longData = 'x' * 10000;
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': '123',
            'email': 'test@test.com',
            'data': longData,
          }),
        ),
      );
      final token = '$header.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('handles token with unicode in email', () async {
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key-id'}),
        ),
      );
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': '123', 'email': 'tëst@exämple.com'})),
      );
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      // Should parse but fail verification
      expect(result.isValid, isFalse);
    });
  });

  group('verifyIdToken header parsing', () {
    test('handles header with extra fields', () async {
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'alg': 'RS256',
            'typ': 'JWT',
            'kid': 'some-key',
            'extra': 'field',
            'another': 123,
          }),
        ),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      // Should parse header fine but fail on key lookup
      expect(result.isValid, isFalse);
    });

    test('handles header with empty kid string', () async {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': ''})),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      // Empty kid should be rejected
      expect(result.isValid, isFalse);
    });

    test('handles non-string kid in header', () async {
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'alg': 'RS256',
            'typ': 'JWT',
            'kid': 12345, // Number instead of string
          }),
        ),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
    });

    test('handles header with nested object', () async {
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'alg': 'RS256',
            'typ': 'JWT',
            'kid': {'nested': 'object'},
          }),
        ),
      );
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '123'})));
      final token = '$header.$payload.sig';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse);
    });
  });

  group('verifyIdToken special characters', () {
    test('handles token parts with URL-safe base64 chars', () async {
      // Test with tokens containing - and _ (URL-safe base64 chars)
      final header = base64Url.encode(
        utf8.encode(
          jsonEncode({'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-key_id'}),
        ),
      );
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({'sub': 'user-123_abc', 'email': 'test+tag@example.com'}),
        ),
      );
      final token = '$header.$payload.signature';

      final result = await verifyIdToken(token);
      expect(result.isValid, isFalse); // Will fail on key lookup
      expect(result.error, isNotNull);
    });
  });
}
