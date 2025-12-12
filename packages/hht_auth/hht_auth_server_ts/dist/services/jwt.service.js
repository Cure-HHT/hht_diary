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
 * JwtService - Handles JWT token lifecycle
 *
 * Responsibilities:
 * - Generate signed JWT tokens with RS256 algorithm
 * - Verify token signature and expiry
 * - Refresh tokens with updated timestamps
 * - Extract tokens from Authorization headers
 */
export class JwtService {
    privateKey;
    publicKey;
    issuer;
    DEFAULT_EXPIRY_SECONDS = 900; // 15 minutes
    ALGORITHM = 'RS256'; // RSA with SHA-256
    BEARER_PREFIX = 'Bearer ';
    constructor(privateKey, publicKey, issuer) {
        this.privateKey = privateKey;
        this.publicKey = publicKey;
        this.issuer = issuer;
    }
    /**
     * Create JwtService from PEM-encoded key strings
     *
     * @param config - Configuration with PEM strings and issuer
     * @returns JwtService instance
     */
    static async fromConfig(config) {
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
    async generateToken(payload) {
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
    async verifyToken(token) {
        if (!token || token.trim() === '') {
            return null;
        }
        try {
            const { payload } = await jose.jwtVerify(token, this.publicKey, {
                issuer: this.issuer,
            });
            // jose.JWTPayload is a superset that includes standard claims
            // We safely extract our custom claims
            return payload;
        }
        catch (error) {
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
    async refreshToken(token) {
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
    extractTokenFromHeader(header) {
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
//# sourceMappingURL=jwt.service.js.map