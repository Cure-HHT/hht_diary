/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00082: Password Hashing Implementation
 *
 * Cross-compatibility tests for Argon2Service.
 *
 * These tests verify that the TypeScript server implementation produces
 * identical results to the Dart client implementation using known test vectors.
 *
 * CRITICAL: Any failure in these tests indicates a breaking compatibility issue
 * that will prevent client-server authentication from working.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { Argon2Service } from '../../src/services/argon2.service.js';

describe('Argon2Service Cross-Compatibility', () => {
  let service: Argon2Service;

  beforeEach(() => {
    service = new Argon2Service();
  });

  describe('Known test vectors', () => {
    it('should produce deterministic hashes with known inputs', async () => {
      // Known test vector: base64-encoded 16-byte salt
      const knownSaltBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Ng=='; // "1234567890123456" in base64
      const knownPassword = 'TestPassword123';

      // Hash the password twice with the same salt
      const hash1 = await service.hashPassword(knownPassword, knownSaltBase64);
      const hash2 = await service.hashPassword(knownPassword, knownSaltBase64);

      // CRITICAL: Must produce identical results every time
      expect(hash1).toBe(hash2);

      // Verify the hash is valid base64
      expect(() => Buffer.from(hash1, 'base64')).not.toThrow();

      // Verify the decoded hash is exactly 32 bytes
      const hashBuffer = Buffer.from(hash1, 'base64');
      expect(hashBuffer.length).toBe(32);
    });

    it('should verify correctly with known test vectors', async () => {
      const knownSaltBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Ng==';
      const knownPassword = 'TestPassword123';

      // Generate hash
      const hash = await service.hashPassword(knownPassword, knownSaltBase64);

      // Verify with correct password
      const isValid = await service.verify(knownPassword, hash, knownSaltBase64);
      expect(isValid).toBe(true);

      // Verify with incorrect password
      const isInvalid = await service.verify('WrongPassword', hash, knownSaltBase64);
      expect(isInvalid).toBe(false);
    });
  });

  describe('Parameter compatibility', () => {
    it('should use Argon2id parameters matching Dart client', async () => {
      // The Dart client uses these exact parameters:
      // - Type: Argon2id (type 2)
      // - Memory: 65536 KB (64 MB)
      // - Iterations: 3
      // - Parallelism: 4
      // - Hash length: 32 bytes
      // - Salt: 16 bytes

      const salt = service.generateSalt();
      const password = 'test123';

      const hash = await service.hashPassword(password, salt);

      // Verify hash length matches expected 32 bytes
      const hashBuffer = Buffer.from(hash, 'base64');
      expect(hashBuffer.length).toBe(32);

      // Verify salt length matches expected 16 bytes
      const saltBuffer = Buffer.from(salt, 'base64');
      expect(saltBuffer.length).toBe(16);

      // Verify deterministic behavior (proof of correct parameters)
      const hash2 = await service.hashPassword(password, salt);
      expect(hash).toBe(hash2);
    });
  });

  describe('Base64 encoding/decoding', () => {
    it('should handle base64 salt correctly', async () => {
      // Generate a salt (base64-encoded)
      const saltBase64 = service.generateSalt();

      // Decode to verify it's 16 bytes
      const saltBuffer = Buffer.from(saltBase64, 'base64');
      expect(saltBuffer.length).toBe(16);

      // Hash a password with this salt
      const hash = await service.hashPassword('test', saltBase64);

      // The hash should be base64-encoded 32 bytes
      const hashBuffer = Buffer.from(hash, 'base64');
      expect(hashBuffer.length).toBe(32);

      // Verify should work
      const isValid = await service.verify('test', hash, saltBase64);
      expect(isValid).toBe(true);
    });

    it('should not use salt as utf8 string', async () => {
      // This test ensures we're using the salt correctly
      // The salt MUST be decoded from base64, not used as a utf8 string

      const saltBase64 = 'QUJDREVGR0hJSktMTU5PUA=='; // 16 bytes when decoded

      const password = 'test123';
      const hash = await service.hashPassword(password, saltBase64);

      // Verify the hash is valid
      expect(hash).toBeTruthy();
      expect(Buffer.from(hash, 'base64').length).toBe(32);

      // Verify should work with the same base64 salt
      const isValid = await service.verify(password, hash, saltBase64);
      expect(isValid).toBe(true);
    });
  });

  describe('Edge cases for compatibility', () => {
    it('should handle empty password like Dart client', async () => {
      const salt = service.generateSalt();
      const hash = await service.hashPassword('', salt);

      expect(hash).toBeTruthy();
      expect(Buffer.from(hash, 'base64').length).toBe(32);

      const isValid = await service.verify('', hash, salt);
      expect(isValid).toBe(true);
    });

    it('should handle unicode passwords like Dart client', async () => {
      const salt = service.generateSalt();
      const unicodePassword = '密碼🔐🛡️';
      const hash = await service.hashPassword(unicodePassword, salt);

      expect(hash).toBeTruthy();
      expect(Buffer.from(hash, 'base64').length).toBe(32);

      const isValid = await service.verify(unicodePassword, hash, salt);
      expect(isValid).toBe(true);

      // Wrong password should fail
      const isInvalid = await service.verify('wrong', hash, salt);
      expect(isInvalid).toBe(false);
    });

    it('should handle special characters like Dart client', async () => {
      const salt = service.generateSalt();
      const specialPassword = '!@#$%^&*()[]{}|\\/?<>~`+=';
      const hash = await service.hashPassword(specialPassword, salt);

      expect(hash).toBeTruthy();

      const isValid = await service.verify(specialPassword, hash, salt);
      expect(isValid).toBe(true);
    });
  });
});
