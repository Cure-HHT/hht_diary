// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Unit tests for JWT token generation and verification

import 'package:diary_functions/diary_functions.dart';
import 'package:test/test.dart';

void main() {
  group('JWT Token Tests', () {
    const testUserId = 'test-user-123';
    const testAuthCode = 'abc123def456';
    const testUsername = 'testuser';

    test('createJwtToken generates valid token structure', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        username: testUsername,
      );

      // JWT should have 3 parts separated by dots
      final parts = token.split('.');
      expect(parts.length, equals(3));

      // Each part should be non-empty
      expect(parts[0], isNotEmpty); // header
      expect(parts[1], isNotEmpty); // payload
      expect(parts[2], isNotEmpty); // signature
    });

    test('verifyJwtToken returns payload for valid token', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        username: testUsername,
      );

      final payload = verifyJwtToken(token);

      expect(payload, isNotNull);
      expect(payload!.authCode, equals(testAuthCode));
      expect(payload.userId, equals(testUserId));
      expect(payload.username, equals(testUsername));
    });

    test('verifyJwtToken returns null for invalid token', () {
      final payload = verifyJwtToken('invalid.token.here');
      expect(payload, isNull);
    });

    test('verifyJwtToken returns null for tampered token', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      // Tamper with the payload
      final parts = token.split('.');
      final tamperedToken = '${parts[0]}.tampered${parts[1]}.${parts[2]}';

      final payload = verifyJwtToken(tamperedToken);
      expect(payload, isNull);
    });

    test('verifyJwtToken returns null for expired token', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        expiresIn: const Duration(seconds: -1), // Already expired
      );

      final payload = verifyJwtToken(token);
      expect(payload, isNull);
    });

    test('verifyAuthHeader extracts token from Bearer header', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final payload = verifyAuthHeader('Bearer $token');

      expect(payload, isNotNull);
      expect(payload!.authCode, equals(testAuthCode));
    });

    test('verifyAuthHeader returns null for missing Bearer prefix', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final payload = verifyAuthHeader(token);
      expect(payload, isNull);
    });

    test('verifyAuthHeader returns null for null header', () {
      final payload = verifyAuthHeader(null);
      expect(payload, isNull);
    });

    test('generateAuthCode produces 64-character hex string', () {
      final authCode = generateAuthCode();

      expect(authCode.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(authCode), isTrue);
    });

    test('generateAuthCode produces unique values', () {
      final codes = <String>{};
      for (var i = 0; i < 100; i++) {
        codes.add(generateAuthCode());
      }
      // All 100 codes should be unique
      expect(codes.length, equals(100));
    });

    test('generateUserId produces valid UUID v4 format', () {
      final userId = generateUserId();

      // UUID format: 8-4-4-4-12
      expect(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(userId),
        isTrue,
      );
    });
  });
}
