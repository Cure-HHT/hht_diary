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
/**
 * Argon2id password hashing service.
 *
 * Provides server-side password hashing compatible with the Dart client
 * implementation using PointyCastle.
 */
export declare class Argon2Service {
    private readonly ARGON2_MEMORY;
    private readonly ARGON2_ITERATIONS;
    private readonly ARGON2_PARALLELISM;
    private readonly ARGON2_HASH_LENGTH;
    private readonly SALT_LENGTH;
    /**
     * Gets Argon2id hashing options.
     *
     * Extracted to a method for better maintainability and to ensure
     * all hashing operations use identical parameters.
     *
     * @param saltBuffer - Binary salt buffer
     * @returns Argon2 options object
     */
    private getArgon2Options;
    /**
     * Validates and decodes a base64-encoded salt.
     *
     * @param saltBase64 - Base64-encoded salt
     * @returns Decoded salt buffer
     * @throws Error if salt is invalid length
     */
    private validateAndDecodeSalt;
    /**
     * Generates a cryptographically secure random salt.
     *
     * @returns Base64-encoded 16-byte salt
     */
    generateSalt(): string;
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
    hashPassword(password: string, saltBase64: string): Promise<string>;
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
    verify(password: string, storedHashBase64: string, saltBase64: string): Promise<boolean>;
}
//# sourceMappingURL=argon2.service.d.ts.map