/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00XXX: JWT service for Web Diary authentication
 *
 * Unit tests for JwtService - TDD approach
 * Tests written FIRST to define expected behavior
 */

import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { JwtService } from '../../../src/services/jwt.service.js';
import * as jose from 'jose';

describe('JwtService', () => {
  let jwtService: JwtService;
  let privateKey: jose.KeyLike;
  let publicKey: jose.KeyLike;

  beforeEach(async () => {
    // Generate RSA key pair for testing
    const { privateKey: privKey, publicKey: pubKey } = await jose.generateKeyPair('RS256');
    privateKey = privKey;
    publicKey = pubKey;

    jwtService = new JwtService(privateKey, publicKey, 'test-issuer');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('generateToken', () => {
    it('should produce valid JWT with all required claims', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const token = await jwtService.generateToken(payload);

      expect(token).toBeDefined();
      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // JWT format: header.payload.signature

      // Verify the token contains all required claims
      const decoded = await jose.jwtVerify(token, publicKey, {
        issuer: 'test-issuer',
      });

      expect(decoded.payload.sub).toBe(payload.sub);
      expect(decoded.payload.username).toBe(payload.username);
      expect(decoded.payload.sponsorId).toBe(payload.sponsorId);
      expect(decoded.payload.sponsorUrl).toBe(payload.sponsorUrl);
      expect(decoded.payload.appUuid).toBe(payload.appUuid);
      expect(decoded.payload.iat).toBeDefined();
      expect(decoded.payload.exp).toBeDefined();
      expect(decoded.payload.iss).toBe('test-issuer');
    });

    it('should use Unix seconds for iat/exp (not milliseconds)', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const beforeGeneration = Math.floor(Date.now() / 1000);
      const token = await jwtService.generateToken(payload);
      const afterGeneration = Math.floor(Date.now() / 1000);

      const decoded = await jose.jwtVerify(token, publicKey);

      // iat should be in seconds (reasonable timestamp)
      expect(decoded.payload.iat).toBeGreaterThanOrEqual(beforeGeneration);
      expect(decoded.payload.iat).toBeLessThanOrEqual(afterGeneration);

      // iat should NOT be in milliseconds (would be 1000x larger)
      const nowMilliseconds = Date.now();
      expect(decoded.payload.iat).toBeLessThan(nowMilliseconds / 100);

      // exp should be 15 minutes (900 seconds) after iat
      expect(decoded.payload.exp).toBe(decoded.payload.iat! + 900);
    });

    it('should use RS256 algorithm', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const token = await jwtService.generateToken(payload);

      // Decode header without verification to check algorithm
      const [headerB64] = token.split('.');
      const header = JSON.parse(Buffer.from(headerB64, 'base64url').toString());

      expect(header.alg).toBe('RS256');
    });

    it('should set expiry to 15 minutes by default', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const token = await jwtService.generateToken(payload);
      const decoded = await jose.jwtVerify(token, publicKey);

      const expiryDuration = decoded.payload.exp! - decoded.payload.iat!;
      expect(expiryDuration).toBe(900); // 15 minutes = 900 seconds
    });
  });

  describe('verifyToken', () => {
    it('should return payload for valid token', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const token = await jwtService.generateToken(payload);
      const result = await jwtService.verifyToken(token);

      expect(result).not.toBeNull();
      expect(result?.sub).toBe(payload.sub);
      expect(result?.username).toBe(payload.username);
      expect(result?.sponsorId).toBe(payload.sponsorId);
      expect(result?.sponsorUrl).toBe(payload.sponsorUrl);
      expect(result?.appUuid).toBe(payload.appUuid);
    });

    it('should return null for expired token', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      // Create token that expires immediately
      const iat = Math.floor(Date.now() / 1000) - 1000; // 1000 seconds ago
      const exp = iat + 1; // Expired 999 seconds ago

      const expiredToken = await new jose.SignJWT({
        ...payload,
      })
        .setProtectedHeader({ alg: 'RS256' })
        .setIssuedAt(iat)
        .setExpirationTime(exp)
        .setIssuer('test-issuer')
        .sign(privateKey);

      const result = await jwtService.verifyToken(expiredToken);

      expect(result).toBeNull();
    });

    it('should return null for invalid signature', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const token = await jwtService.generateToken(payload);

      // Tamper with the token
      const parts = token.split('.');
      parts[2] = parts[2].slice(0, -5) + 'XXXXX'; // Corrupt signature
      const tamperedToken = parts.join('.');

      const result = await jwtService.verifyToken(tamperedToken);

      expect(result).toBeNull();
    });

    it('should return null for wrong issuer', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      // Create token with different issuer
      const wrongIssuerToken = await new jose.SignJWT({
        ...payload,
      })
        .setProtectedHeader({ alg: 'RS256' })
        .setIssuedAt()
        .setExpirationTime('15m')
        .setIssuer('wrong-issuer') // Different issuer
        .sign(privateKey);

      const result = await jwtService.verifyToken(wrongIssuerToken);

      expect(result).toBeNull();
    });

    it('should return null for malformed token', async () => {
      const result = await jwtService.verifyToken('not.a.valid.jwt.token');

      expect(result).toBeNull();
    });

    it('should return null for empty token', async () => {
      const result = await jwtService.verifyToken('');

      expect(result).toBeNull();
    });
  });

  describe('refreshToken', () => {
    it('should return new token with updated iat/exp', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const originalToken = await jwtService.generateToken(payload);

      // Wait a moment to ensure new timestamps
      await new Promise((resolve) => setTimeout(resolve, 1100));

      const refreshedToken = await jwtService.refreshToken(originalToken);

      expect(refreshedToken).not.toBeNull();
      expect(refreshedToken).not.toBe(originalToken);

      const originalDecoded = await jose.jwtVerify(originalToken, publicKey);
      const refreshedDecoded = await jose.jwtVerify(refreshedToken!, publicKey);

      // Same user claims
      expect(refreshedDecoded.payload.sub).toBe(originalDecoded.payload.sub);
      expect(refreshedDecoded.payload.username).toBe(originalDecoded.payload.username);
      expect(refreshedDecoded.payload.sponsorId).toBe(originalDecoded.payload.sponsorId);

      // Updated timestamps
      expect(refreshedDecoded.payload.iat).toBeGreaterThan(originalDecoded.payload.iat!);
      expect(refreshedDecoded.payload.exp).toBeGreaterThan(originalDecoded.payload.exp!);
    });

    it('should preserve all original claims except iat/exp', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      const originalToken = await jwtService.generateToken(payload);
      const refreshedToken = await jwtService.refreshToken(originalToken);

      const refreshedDecoded = await jose.jwtVerify(refreshedToken!, publicKey);

      expect(refreshedDecoded.payload.sub).toBe(payload.sub);
      expect(refreshedDecoded.payload.username).toBe(payload.username);
      expect(refreshedDecoded.payload.sponsorId).toBe(payload.sponsorId);
      expect(refreshedDecoded.payload.sponsorUrl).toBe(payload.sponsorUrl);
      expect(refreshedDecoded.payload.appUuid).toBe(payload.appUuid);
    });

    it('should return null for invalid input token', async () => {
      const result = await jwtService.refreshToken('invalid.token.here');

      expect(result).toBeNull();
    });

    it('should return null for expired token', async () => {
      const payload = {
        sub: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        sponsorId: 'sponsor-123',
        sponsorUrl: 'https://sponsor.example.com',
        appUuid: '987e6543-e21b-98c7-d654-321456789000',
      };

      // Create expired token
      const iat = Math.floor(Date.now() / 1000) - 1000;
      const exp = iat + 1;

      const expiredToken = await new jose.SignJWT({
        ...payload,
      })
        .setProtectedHeader({ alg: 'RS256' })
        .setIssuedAt(iat)
        .setExpirationTime(exp)
        .setIssuer('test-issuer')
        .sign(privateKey);

      const result = await jwtService.refreshToken(expiredToken);

      expect(result).toBeNull();
    });
  });

  describe('extractTokenFromHeader', () => {
    it('should extract token from "Bearer <token>" format', () => {
      const token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
      const header = `Bearer ${token}`;

      const result = jwtService.extractTokenFromHeader(header);

      expect(result).toBe(token);
    });

    it('should return null for invalid header format (no Bearer prefix)', () => {
      const header = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';

      const result = jwtService.extractTokenFromHeader(header);

      expect(result).toBeNull();
    });

    it('should return null for header with only "Bearer"', () => {
      const result = jwtService.extractTokenFromHeader('Bearer');

      expect(result).toBeNull();
    });

    it('should return null for header with "Bearer " and no token', () => {
      const result = jwtService.extractTokenFromHeader('Bearer ');

      expect(result).toBeNull();
    });

    it('should return null for empty header', () => {
      const result = jwtService.extractTokenFromHeader('');

      expect(result).toBeNull();
    });

    it('should handle case-insensitive Bearer prefix', () => {
      const token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
      const header = `bearer ${token}`;

      const result = jwtService.extractTokenFromHeader(header);

      expect(result).toBe(token);
    });

    it('should trim whitespace around token', () => {
      const token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
      const header = `Bearer   ${token}   `;

      const result = jwtService.extractTokenFromHeader(header);

      expect(result).toBe(token);
    });
  });
});
