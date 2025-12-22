/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00082: Password Hashing Implementation

import 'package:test/test.dart';
import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_client/src/services/argon2_password_hasher.dart';

void main() {
  group('Argon2PasswordHasher', () {
    late Argon2PasswordHasher hasher;

    setUp(() {
      hasher = Argon2PasswordHasher();
    });

    group('generateSalt', () {
      test('should generate a non-empty salt', () {
        final salt = hasher.generateSalt();
        expect(salt, isNotEmpty);
      });

      test('should generate different salts each time', () {
        final salt1 = hasher.generateSalt();
        final salt2 = hasher.generateSalt();
        expect(salt1, isNot(equals(salt2)));
      });

      test('should generate base64-encoded salt', () {
        final salt = hasher.generateSalt();
        // Base64 should decode without errors
        expect(() => base64Decode(salt), returnsNormally);
      });

      test('should generate salt with sufficient entropy (at least 16 bytes)', () {
        final salt = hasher.generateSalt();
        final decoded = base64Decode(salt);
        expect(decoded.length, greaterThanOrEqualTo(16));
      });
    });

    group('hashPassword', () {
      const testPassword = 'SecureP@ssw0rd123';
      late String testSalt;

      setUp(() {
        testSalt = hasher.generateSalt();
      });

      test('should return a non-empty hash', () async {
        final hash = await hasher.hashPassword(testPassword, testSalt);
        expect(hash, isNotEmpty);
      });

      test('should return base64-encoded hash', () async {
        final hash = await hasher.hashPassword(testPassword, testSalt);
        // Base64 should decode without errors
        expect(() => base64Decode(hash), returnsNormally);
      });

      test('should produce same hash for same password and salt', () async {
        final hash1 = await hasher.hashPassword(testPassword, testSalt);
        final hash2 = await hasher.hashPassword(testPassword, testSalt);
        expect(hash1, equals(hash2));
      });

      test('should produce different hash for different passwords', () async {
        final hash1 = await hasher.hashPassword('password1', testSalt);
        final hash2 = await hasher.hashPassword('password2', testSalt);
        expect(hash1, isNot(equals(hash2)));
      });

      test('should produce different hash for different salts', () async {
        final salt2 = hasher.generateSalt();
        final hash1 = await hasher.hashPassword(testPassword, testSalt);
        final hash2 = await hasher.hashPassword(testPassword, salt2);
        expect(hash1, isNot(equals(hash2)));
      });

      test('should use OWASP parameters by default', () async {
        // This test verifies that default params are used
        // We can't directly test internal params, but we verify hash length
        final hash = await hasher.hashPassword(testPassword, testSalt);
        final decoded = base64Decode(hash);
        expect(decoded.length, equals(HashingParams.owasp.hashLength));
      });

      test('should accept custom hashing parameters', () async {
        const customParams = HashingParams(
          memory: 32768,
          iterations: 2,
          parallelism: 2,
          hashLength: 32,
        );
        
        final hash = await hasher.hashPassword(
          testPassword,
          testSalt,
          params: customParams,
        );
        
        expect(hash, isNotEmpty);
      });
    });

    group('verifyPassword', () {
      const testPassword = 'SecureP@ssw0rd123';
      late String testSalt;
      late String testHash;

      setUp(() async {
        testSalt = hasher.generateSalt();
        testHash = await hasher.hashPassword(testPassword, testSalt);
      });

      test('should return true for correct password', () async {
        final isValid = await hasher.verifyPassword(
          testPassword,
          testSalt,
          testHash,
        );
        expect(isValid, isTrue);
      });

      test('should return false for incorrect password', () async {
        final isValid = await hasher.verifyPassword(
          'WrongPassword',
          testSalt,
          testHash,
        );
        expect(isValid, isFalse);
      });

      test('should return false for wrong salt', () async {
        final wrongSalt = hasher.generateSalt();
        final isValid = await hasher.verifyPassword(
          testPassword,
          wrongSalt,
          testHash,
        );
        expect(isValid, isFalse);
      });

      test('should work with custom hashing parameters', () async {
        const customParams = HashingParams(
          memory: 32768,
          iterations: 2,
          parallelism: 2,
          hashLength: 32,
        );
        
        final customHash = await hasher.hashPassword(
          testPassword,
          testSalt,
          params: customParams,
        );
        
        final isValid = await hasher.verifyPassword(
          testPassword,
          testSalt,
          customHash,
          params: customParams,
        );
        
        expect(isValid, isTrue);
      });
    });

    group('security requirements', () {
      test('should handle empty password', () async {
        final salt = hasher.generateSalt();
        final hash = await hasher.hashPassword('', salt);
        expect(hash, isNotEmpty);
      });

      test('should handle very long password', () async {
        final salt = hasher.generateSalt();
        final longPassword = 'a' * 1000;
        final hash = await hasher.hashPassword(longPassword, salt);
        expect(hash, isNotEmpty);
      });

      test('should handle special characters in password', () async {
        final salt = hasher.generateSalt();
        const specialPassword = '!@#\$%^&*()[]{}|\\/?<>~`+=';
        final hash = await hasher.hashPassword(specialPassword, salt);
        expect(hash, isNotEmpty);
      });

      test('should handle unicode characters in password', () async {
        final salt = hasher.generateSalt();
        const unicodePassword = '密碼🔐🛡️';
        final hash = await hasher.hashPassword(unicodePassword, salt);
        expect(hash, isNotEmpty);
      });
    });
  });
}

// Helper for base64 decoding test
import 'dart:convert';
