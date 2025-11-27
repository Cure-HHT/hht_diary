// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import * as jwt from "jsonwebtoken";
import * as crypto from "crypto";

// Valid enrollment code pattern: CUREHHT followed by a digit (0-9)
export const ENROLLMENT_CODE_PATTERN = /^CUREHHT[0-9]$/i;

/**
 * Validate an enrollment code format.
 * @param {string | undefined | null} code - The enrollment code to validate
 * @return {boolean} true if valid, false otherwise
 */
export function validateEnrollmentCode(
  code: string | undefined | null
): boolean {
  if (!code || typeof code !== "string") {
    return false;
  }
  return ENROLLMENT_CODE_PATTERN.test(code.toUpperCase());
}

/**
 * Normalize an enrollment code to uppercase.
 * @param {string} code - The enrollment code to normalize
 * @return {string} The normalized code
 */
export function normalizeEnrollmentCode(code: string): string {
  return code.toUpperCase().trim();
}

/**
 * Generate a random authCode for user authentication.
 * @return {string} A 64-character hex string
 */
export function generateAuthCode(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Generate a unique userId using UUID v4.
 * @return {string} A UUID string
 */
export function generateUserId(): string {
  return crypto.randomUUID();
}

/**
 * JWT payload structure
 */
export interface JwtPayload {
  authCode: string;
  userId: string;
  iat?: number;
  exp?: number;
  iss?: string;
}

/**
 * Verify JWT from Authorization header and return user data.
 * @param {string | undefined} authHeader - The Authorization header value
 * @param {string} secret - The JWT secret
 * @return {JwtPayload | null} Decoded token with authCode and userId or null
 */
export function verifyAuthHeader(
  authHeader: string | undefined,
  secret: string
): JwtPayload | null {
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }
  const token = authHeader.substring(7);
  return verifyJwtToken(token, secret);
}

/**
 * Verify a JWT token.
 * @param {string} token - The JWT token
 * @param {string} secret - The JWT secret
 * @return {JwtPayload | null} Decoded payload or null if invalid
 */
export function verifyJwtToken(
  token: string,
  secret: string
): JwtPayload | null {
  try {
    const decoded = jwt.verify(token, secret) as JwtPayload;
    if (!decoded.authCode || !decoded.userId) {
      return null;
    }
    return decoded;
  } catch {
    return null;
  }
}

/**
 * Create a JWT token.
 * @param {object} payload - The payload to sign
 * @param {string} payload.authCode - The auth code
 * @param {string} payload.userId - The user ID
 * @param {string} secret - The JWT secret
 * @param {string | number} expiresIn - Expiration time (default: 365d)
 * @return {string} The signed JWT token
 */
export function createJwtToken(
  payload: { authCode: string; userId: string },
  secret: string,
  expiresIn: string | number = "365d"
): string {
  return jwt.sign(
    {
      authCode: payload.authCode,
      userId: payload.userId,
      iat: Math.floor(Date.now() / 1000),
    },
    secret,
    {
      expiresIn: expiresIn as jwt.SignOptions["expiresIn"],
      issuer: "hht-diary-mvp",
    }
  );
}
