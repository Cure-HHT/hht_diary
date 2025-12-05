/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service - Integration tests
 *
 * Full authentication flow integration tests.
 */

import { describe, it, expect, beforeEach, beforeAll } from 'vitest';
import request from 'supertest';
import { Express } from 'express';
import * as jose from 'jose';
import { createApp, AppDependencies } from '../../src/app.js';
import { JwtService } from '../../src/services/jwt.service.js';
import { Argon2Service } from '../../src/services/argon2.service.js';
import { RateLimiterService } from '../../src/services/rate-limiter.service.js';
import { InMemoryUserRepository } from '../../src/repositories/user.repository.js';
import { InMemorySponsorPatternRepository } from '../../src/repositories/sponsor-pattern.repository.js';
import { SponsorPattern } from '../../src/models/sponsor-pattern.model.js';

describe('Auth Flow Integration Tests', () => {
  let app: Express;
  let deps: AppDependencies;
  let argon2Service: Argon2Service;
  let userRepo: InMemoryUserRepository;
  let patternRepo: InMemorySponsorPatternRepository;
  let testKeyPair: { privateKey: jose.KeyLike; publicKey: jose.KeyLike };

  const testPattern: SponsorPattern = {
    patternPrefix: 'TEST-',
    sponsorId: 'sponsor-123',
    sponsorName: 'Test Sponsor',
    portalUrl: 'https://portal.test.com',
    firestoreProject: 'test-project',
    active: true,
    createdAt: new Date().toISOString(),
    decommissionedAt: null,
  };

  beforeAll(async () => {
    argon2Service = new Argon2Service();
    // Generate RSA key pair once for all tests
    testKeyPair = await jose.generateKeyPair('RS256');
  });

  beforeEach(async () => {
    const jwtService = new JwtService(
      testKeyPair.privateKey,
      testKeyPair.publicKey,
      'test-issuer'
    );

    userRepo = new InMemoryUserRepository();
    patternRepo = new InMemorySponsorPatternRepository();
    patternRepo.seed([testPattern]);

    deps = {
      jwtService,
      argon2Service,
      rateLimiter: new RateLimiterService(5, 60000),
      userRepository: userRepo,
      sponsorPatternRepository: patternRepo,
    };

    app = createApp(deps);
  });

  describe('Health Check', () => {
    it('GET /health should return ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ status: 'ok' });
    });
  });

  describe('POST /auth/validate-linking-code', () => {
    it('should validate a valid linking code', async () => {
      const res = await request(app)
        .post('/auth/validate-linking-code')
        .send({ linkingCode: 'TEST-12345' });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        sponsorId: 'sponsor-123',
        sponsorName: 'Test Sponsor',
        portalUrl: 'https://portal.test.com',
      });
    });

    it('should reject an invalid linking code', async () => {
      const res = await request(app)
        .post('/auth/validate-linking-code')
        .send({ linkingCode: 'INVALID-12345' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('message');
    });
  });

  describe('POST /auth/register', () => {
    it('should register a new user', async () => {
      const salt = argon2Service.generateSalt();
      const passwordHash = await argon2Service.hashPassword('TestPassword123!', salt);

      const res = await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          passwordHash,
          salt,
          linkingCode: 'TEST-12345',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('user');
      expect(res.body.user.username).toBe('testuser');
      expect(res.body.user.sponsorId).toBe('sponsor-123');
    });

    it('should reject duplicate username', async () => {
      const salt = argon2Service.generateSalt();
      const passwordHash = await argon2Service.hashPassword('TestPassword123!', salt);

      // First registration
      await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          passwordHash,
          salt,
          linkingCode: 'TEST-12345',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      // Duplicate registration
      const res = await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          passwordHash,
          salt,
          linkingCode: 'TEST-67890',
          appUuid: '550e8400-e29b-41d4-a716-446655440001',
        });

      expect(res.status).toBe(409);
      expect(res.body.message).toContain('already taken');
    });
  });

  describe('POST /auth/login', () => {
    beforeEach(async () => {
      // Create a test user
      const salt = argon2Service.generateSalt();
      const passwordHash = await argon2Service.hashPassword('TestPassword123!', salt);

      await request(app)
        .post('/auth/register')
        .send({
          username: 'loginuser',
          passwordHash,
          salt,
          linkingCode: 'TEST-12345',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });
    });

    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({
          username: 'loginuser',
          password: 'TestPassword123!',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('user');
      expect(res.body.user.username).toBe('loginuser');
    });

    it('should reject invalid password', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({
          username: 'loginuser',
          password: 'WrongPassword!',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      expect(res.status).toBe(401);
      expect(res.body.message).toContain('Invalid');
    });

    it('should reject unknown username', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({
          username: 'unknownuser',
          password: 'TestPassword123!',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      expect(res.status).toBe(401);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should refresh a valid token', async () => {
      // Register and get token
      const salt = argon2Service.generateSalt();
      const passwordHash = await argon2Service.hashPassword('TestPassword123!', salt);

      const registerRes = await request(app)
        .post('/auth/register')
        .send({
          username: 'refreshuser',
          passwordHash,
          salt,
          linkingCode: 'TEST-12345',
          appUuid: '550e8400-e29b-41d4-a716-446655440000',
        });

      const originalToken = registerRes.body.token;

      // Refresh token
      const res = await request(app)
        .post('/auth/refresh')
        .send({ token: originalToken });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      // Verify the returned token is valid JWT format (3 parts separated by dots)
      expect(res.body.token.split('.').length).toBe(3);
      // Verify the refreshed token can be decoded and contains expected claims
      const payload = jose.decodeJwt(res.body.token);
      expect(payload.username).toBe('refreshuser');
      expect(payload.sponsorId).toBe('sponsor-123');
    });

    it('should reject invalid token', async () => {
      const res = await request(app)
        .post('/auth/refresh')
        .send({ token: 'invalid.token.here' });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /auth/sponsor-config/:sponsorId', () => {
    it('should return sponsor config', async () => {
      const res = await request(app).get('/auth/sponsor-config/sponsor-123');

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('sponsorId', 'sponsor-123');
      expect(res.body).toHaveProperty('sponsorName', 'Test Sponsor');
      expect(res.body).toHaveProperty('sessionTimeoutMinutes');
      expect(res.body).toHaveProperty('branding');
    });

    it('should return default config for unknown sponsor', async () => {
      const res = await request(app).get('/auth/sponsor-config/unknown-sponsor');

      expect(res.status).toBe(200);
      expect(res.body.sponsorId).toBe('unknown-sponsor');
      expect(res.body.sponsorName).toBe('Clinical Diary');
    });
  });
});
