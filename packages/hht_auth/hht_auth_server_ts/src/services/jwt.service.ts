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
  sub: string; // User ID (UUID v4)
  username: string;
  sponsorId: string;
  sponsorUrl: string; // Sponsor Portal base URL
  appUuid: string; // App instance UUID
  iat?: number; // Unix timestamp in SECONDS
  exp?: number; // Unix timestamp in SECONDS
  iss?: string; // Issuer
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
export class JwtService {
  private readonly DEFAULT_EXPIRY_SECONDS = 900; // 15 minutes
  private readonly ALGORITHM = 'RS256' as const; // RSA with SHA-256
  private readonly BEARER_PREFIX = 'Bearer ';

  constructor(
    private readonly privateKey: jose.KeyLike,
    private readonly publicKey: jose.KeyLike,
    private readonly issuer: string
  ) {}

  /**
   * Create JwtService from PEM-encoded key strings
   *
   * @param config - Configuration with PEM strings and issuer
   * @returns JwtService instance
   */
  static async fromConfig(config: JwtConfig): Promise<JwtService> {
    const privateKey = await jose.importPKCS8(config.privateKey, 'RS256');
    const publicKey = await jose.importSPKI(config.publicKey, 'RS256');
    return new JwtService(privateKey, publicKey, config.issuer);
  }

  /**
   * Generate a signed JWT token
   *
   * @param payload - User claims (sub, username, sponsorId, sponsorUrl, appUuid)
   * @returns Signed JWT token string
   *
   * CRITICAL: Uses Unix SECONDS for iat/exp (not milliseconds)
   */
  async generateToken(payload: TokenPayloadInput): Promise<string> {
    const now = Math.floor(Date.now() / 1000); // Unix seconds, NOT milliseconds
    const exp = now + this.DEFAULT_EXPIRY_SECONDS;

    return await new jose.SignJWT({
      sub: payload.sub,
      username: payload.username,
      sponsorId: payload.sponsorId,
      sponsorUrl: payload.sponsorUrl,
      appUuid: payload.appUuid,
    })
      .setProtectedHeader({ alg: this.ALGORITHM })
      .setIssuedAt(now)
      .setExpirationTime(exp)
      .setIssuer(this.issuer)
      .sign(this.privateKey);
  }

  /**
   * Verify and decode a JWT token
   *
   * @param token - JWT token string to verify
   * @returns Decoded payload if valid, null if invalid/expired/tampered
   *
   * Returns null for ANY verification failure to prevent security issues
   */
  async verifyToken(token: string): Promise<JwtPayload | null> {
    if (!token || token.trim() === '') {
      return null;
    }

    try {
      const { payload } = await jose.jwtVerify(token, this.publicKey, {
        issuer: this.issuer,
      });

      // jose.JWTPayload is a superset that includes standard claims
      // We safely extract our custom claims
      return payload as unknown as JwtPayload;
    } catch (error) {
      // Any verification failure returns null:
      // - Expired token (jose.errors.JWTExpired)
      // - Invalid signature (jose.errors.JWSSignatureVerificationFailed)
      // - Wrong issuer (jose.errors.JWTClaimValidationFailed)
      // - Malformed token
      return null;
    }
  }

  /**
   * Refresh a token with updated timestamps
   *
   * @param token - Existing valid JWT token
   * @returns New token with same claims but fresh iat/exp, or null if input invalid
   *
   * Use case: Extend session without requiring re-authentication
   */
  async refreshToken(token: string): Promise<string | null> {
    // Verify the existing token first
    const payload = await this.verifyToken(token);

    if (!payload) {
      return null;
    }

    // Generate new token with same claims (except iat/exp)
    const newToken = await this.generateToken({
      sub: payload.sub,
      username: payload.username,
      sponsorId: payload.sponsorId,
      sponsorUrl: payload.sponsorUrl,
      appUuid: payload.appUuid,
    });

    return newToken;
  }

  /**
   * Extract JWT token from Authorization header
   *
   * @param header - Authorization header value (e.g., "Bearer eyJhbGc...")
   * @returns Token string if valid format, null otherwise
   *
   * Supports case-insensitive "Bearer" prefix and trims whitespace
   */
  extractTokenFromHeader(header: string): string | null {
    if (!header || header.trim() === '') {
      return null;
    }

    const trimmedHeader = header.trim();

    // Case-insensitive check for "Bearer " prefix
    if (!trimmedHeader.toLowerCase().startsWith(this.BEARER_PREFIX.toLowerCase())) {
      return null;
    }

    const token = trimmedHeader.slice(this.BEARER_PREFIX.length).trim();

    return token || null;
  }
}
