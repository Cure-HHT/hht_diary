/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00082: Password Hashing Implementation - Server-side Argon2id verification
///
/// Tests for Argon2 password hash verification service.

import 'dart:convert';
import 'dart:typed_data';

import 'package:hht_auth_server/src/services/argon2_verifier.dart';
import 'package:test/test.dart';

void main() {
  group('Argon2Verifier', () {
    late Argon2Verifier verifier;

    setUp(() {
      verifier = Argon2Verifier();
    });

    group('verify', () {
      test('verifies correct password successfully', () {
        // Pre-computed hash for password "TestPassword123!" with known salt
        final password = 'TestPassword123!';
        final salt = 'testsalt12345678'; // 16+ chars

        // Hash the password using the same parameters
        final hash = verifier.hashPassword(password, salt);

        // Verify should succeed
        expect(verifier.verify(password, hash, salt), isTrue);
      });

      test('rejects incorrect password', () {
        final correctPassword = 'TestPassword123!';
        final wrongPassword = 'WrongPassword456!';
        final salt = 'testsalt12345678';

        final hash = verifier.hashPassword(correctPassword, salt);

        expect(verifier.verify(wrongPassword, hash, salt), isFalse);
      });

      test('rejects password with different salt', () {
        final password = 'TestPassword123!';
        final salt1 = 'testsalt12345678';
        final salt2 = 'differentsalt999';

        final hash = verifier.hashPassword(password, salt1);

        // Using different salt should fail verification
        expect(verifier.verify(password, hash, salt2), isFalse);
      });

      test('handles empty password', () {
        final password = '';
        final salt = 'testsalt12345678';

        final hash = verifier.hashPassword(password, salt);

        expect(verifier.verify(password, hash, salt), isTrue);
        expect(verifier.verify('notempty', hash, salt), isFalse);
      });

      test('handles unicode characters', () {
        final password = '密码🔐Test';
        final salt = 'testsalt12345678';

        final hash = verifier.hashPassword(password, salt);

        expect(verifier.verify(password, hash, salt), isTrue);
        expect(verifier.verify('密码🔐Wrong', hash, salt), isFalse);
      });
    });

    group('hashPassword', () {
      test('produces deterministic hash for same inputs', () {
        final password = 'TestPassword123!';
        final salt = 'testsalt12345678';

        final hash1 = verifier.hashPassword(password, salt);
        final hash2 = verifier.hashPassword(password, salt);

        expect(hash1, equals(hash2));
      });

      test('produces different hashes for different passwords', () {
        final password1 = 'TestPassword123!';
        final password2 = 'DifferentPass456!';
        final salt = 'testsalt12345678';

        final hash1 = verifier.hashPassword(password1, salt);
        final hash2 = verifier.hashPassword(password2, salt);

        expect(hash1, isNot(equals(hash2)));
      });

      test('produces different hashes for different salts', () {
        final password = 'TestPassword123!';
        final salt1 = 'testsalt12345678';
        final salt2 = 'differentsalt999';

        final hash1 = verifier.hashPassword(password, salt1);
        final hash2 = verifier.hashPassword(password, salt2);

        expect(hash1, isNot(equals(hash2)));
      });

      test('returns base64-encoded hash', () {
        final password = 'TestPassword123!';
        final salt = 'testsalt12345678';

        final hash = verifier.hashPassword(password, salt);

        // Should be valid base64
        expect(() => base64.decode(hash), returnsNormally);

        // Should be 32 bytes (256 bits) when decoded
        final decoded = base64.decode(hash);
        expect(decoded.length, equals(32));
      });
    });
  });
}
