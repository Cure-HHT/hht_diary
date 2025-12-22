/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00XXX: JWT service for Web Diary authentication
 *
 * JwtService - JWT token generation and verification for authentication
 *
 * CRITICAL: This implementation MUST maintain 100% compatibility with the Dart client.
 * Any changes to token structure or claims MUST be coordinated with client updates.
 *
 * Key design decisions:
 * - Algorithm: RS256 (RSA with SHA-256) for asymmetric signing
 * - Timestamps: Unix seconds (NOT milliseconds) for iat/exp
 * - Default expiry: 15 minutes (900 seconds)
 * - Library: jose (recommended by Node.js community for JWT operations)
 */
import * as jose from 'jose';
/**
 * Configuration for creating JwtService from PEM strings
 */
export interface JwtConfig {
    privateKey: string;
    publicKey: string;
    issuer: string;
}
/**
 * JWT Payload structure - MUST match Dart client exactly
 */
export interface JwtPayload {
    sub: string;
    username: string;
    sponsorId: string;
    sponsorUrl: string;
    appUuid: string;
    iat?: number;
    exp?: number;
    iss?: string;
}
/**
 * Input payload for token generation (without iat/exp/iss)
 */
export interface TokenPayloadInput {
    sub: string;
    username: string;
    sponsorId: string;
    sponsorUrl: string;
    appUuid: string;
}
/**
 * JwtService - Handles JWT token lifecycle
 *
 * Responsibilities:
 * - Generate signed JWT tokens with RS256 algorithm
 * - Verify token signature and expiry
 * - Refresh tokens with updated timestamps
 * - Extract tokens from Authorization headers
 */
export declare class JwtService {
    private readonly privateKey;
    private readonly publicKey;
    private readonly issuer;
    private readonly DEFAULT_EXPIRY_SECONDS;
    private readonly ALGORITHM;
    private readonly BEARER_PREFIX;
    constructor(privateKey: jose.KeyLike, publicKey: jose.KeyLike, issuer: string);
    /**
     * Create JwtService from PEM-encoded key strings
     *
     * @param config - Configuration with PEM strings and issuer
     * @returns JwtService instance
     */
    static fromConfig(config: JwtConfig): Promise<JwtService>;
    /**
     * Generate a signed JWT token
     *
     * @param payload - User claims (sub, username, sponsorId, sponsorUrl, appUuid)
     * @returns Signed JWT token string
     *
     * CRITICAL: Uses Unix SECONDS for iat/exp (not milliseconds)
     */
    generateToken(payload: TokenPayloadInput): Promise<string>;
    /**
     * Verify and decode a JWT token
     *
     * @param token - JWT token string to verify
     * @returns Decoded payload if valid, null if invalid/expired/tampered
     *
     * Returns null for ANY verification failure to prevent security issues
     */
    verifyToken(token: string): Promise<JwtPayload | null>;
    /**
     * Refresh a token with updated timestamps
     *
     * @param token - Existing valid JWT token
     * @returns New token with same claims but fresh iat/exp, or null if input invalid
     *
     * Use case: Extend session without requiring re-authentication
     */
    refreshToken(token: string): Promise<string | null>;
    /**
     * Extract JWT token from Authorization header
     *
     * @param header - Authorization header value (e.g., "Bearer eyJhbGc...")
     * @returns Token string if valid format, null otherwise
     *
     * Supports case-insensitive "Bearer" prefix and trims whitespace
     */
    extractTokenFromHeader(header: string): string | null;
}
//# sourceMappingURL=jwt.service.d.ts.map