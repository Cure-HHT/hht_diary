/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00082: Password Hashing Implementation
 *
 * Server-side password hashing using Argon2id.
 *
 * CRITICAL COMPATIBILITY NOTES:
 * This implementation MUST be 100% compatible with the Dart client.
 * The Dart client uses PointyCastle with these EXACT parameters:
 *
 * - Type: Argon2id (type 2)
 * - Memory: 65536 KB (64 MB)
 * - Iterations: 3
 * - Parallelism: 4
 * - Hash length: 32 bytes
 * - Salt: 16 bytes, transmitted as base64
 *
 * SALT HANDLING (CRITICAL):
 * The salt is transmitted as a base64-encoded string. It MUST be decoded
 * from base64 to bytes before use. DO NOT use utf8 encoding!
 *
 * Example:
 * - Client sends: "MTIzNDU2Nzg5MDEyMzQ1Ng==" (base64)
 * - Server decodes: Buffer.from(saltBase64, 'base64') -> 16 bytes
 * - Server uses: those 16 bytes directly in Argon2
 */

import argon2, { type Options } from 'argon2';
import { randomBytes, timingSafeEqual } from 'crypto';

/**
 * Argon2id password hashing service.
 *
 * Provides server-side password hashing compatible with the Dart client
 * implementation using PointyCastle.
 */
export class Argon2Service {
  // OWASP-recommended Argon2id parameters (MUST match Dart client)
  private readonly ARGON2_MEMORY = 65536; // 64 MB in KB
  private readonly ARGON2_ITERATIONS = 3; // Time cost
  private readonly ARGON2_PARALLELISM = 4; // Number of lanes
  private readonly ARGON2_HASH_LENGTH = 32; // 256 bits
  private readonly SALT_LENGTH = 16; // 128 bits

  /**
   * Gets Argon2id hashing options.
   *
   * Extracted to a method for better maintainability and to ensure
   * all hashing operations use identical parameters.
   *
   * @param saltBuffer - Binary salt buffer
   * @returns Argon2 options object
   */
  private getArgon2Options(saltBuffer: Buffer): Options & { raw: true } {
    return {
      type: argon2.argon2id,
      memoryCost: this.ARGON2_MEMORY,
      timeCost: this.ARGON2_ITERATIONS,
      parallelism: this.ARGON2_PARALLELISM,
      hashLength: this.ARGON2_HASH_LENGTH,
      salt: saltBuffer,
      raw: true, // CRITICAL: Return raw buffer, not encoded string
    };
  }

  /**
   * Validates and decodes a base64-encoded salt.
   *
   * @param saltBase64 - Base64-encoded salt
   * @returns Decoded salt buffer
   * @throws Error if salt is invalid length
   */
  private validateAndDecodeSalt(saltBase64: string): Buffer {
    const saltBuffer = Buffer.from(saltBase64, 'base64');

    if (saltBuffer.length !== this.SALT_LENGTH) {
      throw new Error(
        `Invalid salt length: expected ${this.SALT_LENGTH} bytes, got ${saltBuffer.length}`
      );
    }

    return saltBuffer;
  }

  /**
   * Generates a cryptographically secure random salt.
   *
   * @returns Base64-encoded 16-byte salt
   */
  generateSalt(): string {
    const saltBuffer = randomBytes(this.SALT_LENGTH);
    return saltBuffer.toString('base64');
  }

  /**
   * Hashes a password using Argon2id.
   *
   * CRITICAL: The salt is transmitted as base64 and MUST be decoded.
   * DO NOT use the base64 string directly as utf8!
   *
   * @param password - Plain text password to hash
   * @param saltBase64 - Base64-encoded salt (16 bytes when decoded)
   * @returns Base64-encoded hash (32 bytes when decoded)
   */
  async hashPassword(password: string, saltBase64: string): Promise<string> {
    // Validate and decode the base64 salt to bytes
    const saltBuffer = this.validateAndDecodeSalt(saltBase64);

    // Hash with Argon2id using raw output (not encoded hash string)
    const hashBuffer = await argon2.hash(password, this.getArgon2Options(saltBuffer));

    // Return base64-encoded hash
    return hashBuffer.toString('base64');
  }

  /**
   * Verifies a password against a stored hash.
   *
   * Uses constant-time comparison to prevent timing attacks.
   *
   * @param password - Plain text password to verify
   * @param storedHashBase64 - Base64-encoded stored hash
   * @param saltBase64 - Base64-encoded salt
   * @returns True if password matches, false otherwise
   */
  async verify(
    password: string,
    storedHashBase64: string,
    saltBase64: string
  ): Promise<boolean> {
    try {
      // Hash the provided password with the same salt
      const computedHashBase64 = await this.hashPassword(password, saltBase64);

      // Decode both hashes to buffers for constant-time comparison
      const storedHashBuffer = Buffer.from(storedHashBase64, 'base64');
      const computedHashBuffer = Buffer.from(computedHashBase64, 'base64');

      // Constant-time comparison to prevent timing attacks
      // Must be same length for timingSafeEqual
      if (storedHashBuffer.length !== computedHashBuffer.length) {
        return false;
      }

      return timingSafeEqual(storedHashBuffer, computedHashBuffer);
    } catch (error) {
      // If any error occurs (invalid base64, etc.), return false
      // Don't leak error information
      return false;
    }
  }
}
