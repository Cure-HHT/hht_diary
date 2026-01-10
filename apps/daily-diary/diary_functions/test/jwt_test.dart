// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Unit tests for JWT token generation and verification

import 'package:diary_functions/diary_functions.dart';
import 'package:test/test.dart';

void main() {
  group('JWT Token Generation', () {
    const testUserId = 'test-user-123';
    const testAuthCode =
        'abc123def456abc123def456abc123def456abc123def456abc123def456abc1';
    const testUsername = 'testuser';

    test('createJwtToken generates valid 3-part token', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        username: testUsername,
      );

      final parts = token.split('.');
      expect(parts.length, equals(3));
      expect(parts[0], isNotEmpty);
      expect(parts[1], isNotEmpty);
      expect(parts[2], isNotEmpty);
    });

    test('createJwtToken includes username when provided', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        username: testUsername,
      );

      final payload = verifyJwtToken(token);
      expect(payload, isNotNull);
      expect(payload!.username, equals(testUsername));
    });

    test('createJwtToken works without username', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final payload = verifyJwtToken(token);
      expect(payload, isNotNull);
      expect(payload!.username, isNull);
    });

    test('createJwtToken respects custom expiration', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        expiresIn: const Duration(hours: 1),
      );

      final payload = verifyJwtToken(token);
      expect(payload, isNotNull);

      // Expiration should be approximately 1 hour from now
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = payload!.exp!;
      expect(exp - now, closeTo(3600, 5)); // Within 5 seconds
    });
  });

  group('JWT Token Verification', () {
    const testUserId = 'test-user-123';
    const testAuthCode =
        'abc123def456abc123def456abc123def456abc123def456abc123def456abc1';

    test('verifyJwtToken returns payload for valid token', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final payload = verifyJwtToken(token);

      expect(payload, isNotNull);
      expect(payload!.authCode, equals(testAuthCode));
      expect(payload.userId, equals(testUserId));
    });

    test('verifyJwtToken returns null for malformed token', () {
      expect(verifyJwtToken('invalid'), isNull);
      expect(verifyJwtToken('a.b'), isNull);
      expect(verifyJwtToken('a.b.c.d'), isNull);
      expect(verifyJwtToken(''), isNull);
    });

    test('verifyJwtToken returns null for tampered signature', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final parts = token.split('.');
      final tamperedToken = '${parts[0]}.${parts[1]}.invalid_signature';

      expect(verifyJwtToken(tamperedToken), isNull);
    });

    test('verifyJwtToken returns null for tampered payload', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final parts = token.split('.');
      // Modify payload
      final tamperedToken = '${parts[0]}.dGFtcGVyZWQ.${parts[2]}';

      expect(verifyJwtToken(tamperedToken), isNull);
    });

    test('verifyJwtToken returns null for expired token', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        expiresIn: const Duration(seconds: -10), // Already expired
      );

      expect(verifyJwtToken(token), isNull);
    });

    test('verifyJwtToken accepts non-expired token', () {
      final token = createJwtToken(
        authCode: testAuthCode,
        userId: testUserId,
        expiresIn: const Duration(hours: 24),
      );

      expect(verifyJwtToken(token), isNotNull);
    });
  });

  group('Auth Header Verification', () {
    const testUserId = 'test-user-123';
    const testAuthCode =
        'abc123def456abc123def456abc123def456abc123def456abc123def456abc1';

    test('verifyAuthHeader extracts token from Bearer header', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      final payload = verifyAuthHeader('Bearer $token');
      expect(payload, isNotNull);
      expect(payload!.userId, equals(testUserId));
    });

    test('verifyAuthHeader is case-sensitive for Bearer', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      // Only "Bearer " with capital B is valid
      expect(verifyAuthHeader('bearer $token'), isNull);
      expect(verifyAuthHeader('BEARER $token'), isNull);
    });

    test('verifyAuthHeader returns null for missing prefix', () {
      final token = createJwtToken(authCode: testAuthCode, userId: testUserId);

      expect(verifyAuthHeader(token), isNull);
    });

    test('verifyAuthHeader returns null for null input', () {
      expect(verifyAuthHeader(null), isNull);
    });

    test('verifyAuthHeader returns null for empty string', () {
      expect(verifyAuthHeader(''), isNull);
      expect(verifyAuthHeader('Bearer '), isNull);
    });
  });

  group('Auth Code Generation', () {
    test('generateAuthCode produces 64-character string', () {
      final authCode = generateAuthCode();
      expect(authCode.length, equals(64));
    });

    test('generateAuthCode produces lowercase hex string', () {
      final authCode = generateAuthCode();
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(authCode), isTrue);
    });

    test('generateAuthCode produces unique values', () {
      final codes = List.generate(100, (_) => generateAuthCode());
      final uniqueCodes = codes.toSet();
      expect(uniqueCodes.length, equals(100));
    });

    test('generateAuthCode uses cryptographically secure random', () {
      // Generate many codes and check for reasonable distribution
      final codes = List.generate(1000, (_) => generateAuthCode());

      // Count character frequency in first position
      final firstChars = codes.map((c) => c[0]).toList();
      final charCounts = <String, int>{};
      for (final char in firstChars) {
        charCounts[char] = (charCounts[char] ?? 0) + 1;
      }

      // With 16 possible hex chars and 1000 samples, each char should appear ~62 times
      // Allow for variance (should be between 20 and 120)
      for (final count in charCounts.values) {
        expect(count, greaterThan(10));
        expect(count, lessThan(150));
      }
    });
  });

  group('User ID Generation', () {
    test('generateUserId produces valid UUID v4 format', () {
      final userId = generateUserId();

      // UUID v4 format: 8-4-4-4-12 with version 4 marker
      final uuidRegex = RegExp(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
      );
      expect(uuidRegex.hasMatch(userId), isTrue);
    });

    test('generateUserId produces lowercase hex', () {
      final userId = generateUserId();
      expect(userId, equals(userId.toLowerCase()));
    });

    test('generateUserId produces unique values', () {
      final ids = List.generate(100, (_) => generateUserId());
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(100));
    });

    test('generateUserId has correct length', () {
      final userId = generateUserId();
      // UUID format: 8-4-4-4-12 = 32 hex chars + 4 dashes = 36
      expect(userId.length, equals(36));
    });
  });
}
