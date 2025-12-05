/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - Integration tests
///   REQ-d00079: Linking Code Pattern Matching
///   REQ-d00081: User Document Schema
///   REQ-d00082: Password Hashing
///
/// Integration tests demonstrating complete authentication workflows.

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_server/hht_auth_server.dart';
import 'package:hht_auth_server/testing.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Authentication Integration Tests', () {
    late JwtService jwtService;
    late RateLimiter rateLimiter;
    late Argon2Verifier passwordVerifier;
    late FakeUserRepository userRepo;
    late FakeSponsorPatternRepository patternRepo;

    final testPrivateKey = '''-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDBXn24lJlgwQ+X
j9UuIKYB1/GutJZxaAT8SewId0fzKL3JlCk0STc9JVMyKxtVEEO9GsbB9q8Zdb/q
h4BPfYCn0pDSqszuXBgB6Xl7pe3IFPdAuAb2LoB3phMynS8dB4C7cpJD8XdXO18v
nBm1KbJqSFK+74naBBlZJB/oGOsoheDkOB3LSn8JA7hvWGhX5ogZIUAv5WGwTPTn
/HO4aRFzYsPmR490bVgWYzy2JhkAetHpTsST5Ak2AfiXfqBAzbXmAUZiTyjCNh4j
zOn5kLKIxoQcy+DSnxsSgQG3qfVroqlLwCMnf1MKBai1OMG6TCUUp6U1lXljCT6d
qH5x46XHAgMBAAECggEAVgS0NYN5FVbcmkXkBcCFSIWo39g6olks+pPhuURij9Mc
VgsgJz+4oG01rLgLURRKpdk++HLForREOs6rL/E65azgOq67Of9iuJsFLRF7jMly
0enrQuEdydvpZ1cP6cB4LiqB0VKdjYL+TV4J+5KAaRIiKQjC0GaJZiORQ/ytw1i/
a37nyhWm+tqVf23e+tKoOuDhT2AubRyrhwbHO14SEHHxI0FkyMWM3hNeXp0loesW
sVLj1EmKvUVyxzZnhYhx9XOJXPPfZLEIm8Tqq8Na/y2aohQd9dbydvXqEseqZkOr
hkTC3NexYUrsa8qj2HBEIZ6fEdQK5rx/IzrSwIc/aQKBgQDE5GyMmLFnDB1HCgLM
+MsjTzpFLUQv+rtraXrOR2kqLHH68LxrCGgnw8fNbDvDNhTxd/hYdgMqQT7ZMOMk
6LvB5lIKLJOmGLr7gcfw98ubuahtONbC1egYg7D+ZC46mBgRKkyt1zdHuSjWUhVb
Puwd8AL6/cn4GovqeczBNOxnDwKBgQD7a03Ge0MfKFk428rtfZ/h8OuO5kDre/Iv
Y7ZsPpALv9I8G8R0yiIbrVy6tJaOitae6ztXDb1nX0r+BtxnIoXyfUR+YmieO/EU
mjeZxjP4YdlUozmxXqEiMm6WGKFXkvgKGMgThHrwAtpbWmMq4kVpaLvtxX2Devo5
NNiDJwWVyQKBgQCj0vRG393sQfYyX7AI4JIVZRy05n8v9M3xB6j47g4g2y5Tf+8m
l64iOBKNaBspyFwQtqPa5wanJ/alPLoiwctIAN4OPRz1POqHzmqQo320qvvrNTns
j5M4ooqogK6+bkLINYvrsYD7mqLSASZn76kDF+tC79wXJe95P7MQp3p0HQKBgQDn
Vwn+mwbdEZRfdCaaNmC6VqN5HrcXtznWjyqZGUwT85IwCuDPEfsmenN7vJVYXbo0
CoDUjmj8SDvJ2GhPYf3cbZVrsYNQLhmbene0wCKr5uVCMtrwMQGVZNBKvikfWrVv
HPRkuR8h344qRtY+7GswHdXmaDUgmTTLFKwwqeRCuQKBgQCc7FtYymmuiJEpEENb
5G4mUuPhGIGhxg5nGQjkmnNhDIFRFxVRC7tIycammI5P0jaTnXPsSxr2LyKaUemn
ET9MB1BhMxUaM9uwiTo2vlw2Pvs6uGDPxHlA63beHmRqRZJgcfWuzGzzDZosVFzy
vsrKNIYC9kCNxrY51tiESersxQ==
-----END PRIVATE KEY-----''';

    final testPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwV59uJSZYMEPl4/VLiCm
AdfxrrSWcWgE/EnsCHdH8yi9yZQpNEk3PSVTMisbVRBDvRrGwfavGXW/6oeAT32A
p9KQ0qrM7lwYAel5e6XtyBT3QLgG9i6Ad6YTMp0vHQeAu3KSQ/F3VztfL5wZtSmy
akhSvu+J2gQZWSQf6BjrKIXg5Dgdy0p/CQO4b1hoV+aIGSFAL+VhsEz05/xzuGkR
c2LD5kePdG1YFmM8tiYZAHrR6U7Ek+QJNgH4l36gQM215gFGYk8owjYeI8zp+ZCy
iMaEHMvg0p8bEoEBt6n1a6KpS8AjJ39TCgWotTjBukwlFKelNZV5Ywk+nah+ceOl
xwIDAQAB
-----END PUBLIC KEY-----''';

    setUp(() {
      jwtService = JwtService(
        privateKey: testPrivateKey,
        publicKey: testPublicKey,
        issuer: 'hht-auth-test',
      );

      rateLimiter = RateLimiter(
        maxAttempts: 5,
        windowDuration: Duration(minutes: 1),
      );

      passwordVerifier = Argon2Verifier();
      userRepo = FakeUserRepository();
      patternRepo = FakeSponsorPatternRepository();
    });

    tearDown(() {
      userRepo.clear();
      patternRepo.clear();
    });

    group('Complete Registration Flow', () {
      test('successful user registration', () async {
        // Setup: Add sponsor pattern
        final pattern = SponsorPattern(
          patternPrefix: 'HHT-TEST-',
          sponsorId: 'test-sponsor',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://portal.test.com',
          firestoreProject: 'test-project',
          active: true,
          createdAt: DateTime.now(),
        );
        await patternRepo.createPattern(pattern);

        // Validate linking code
        final linkingCode = 'HHT-TEST-12345';
        final matchedPattern = await patternRepo.findByLinkingCode(linkingCode);

        expect(matchedPattern, isNotNull);
        expect(matchedPattern!.sponsorId, equals('test-sponsor'));

        // Check rate limit (registration)
        final rateLimitKey = 'register:192.168.1.1';
        expect(rateLimiter.checkLimit(rateLimitKey), isTrue);

        // Hash password (simulating client-side)
        final password = 'SecurePassword123!';
        final salt = 'randomsalt123456';
        final passwordHash = passwordVerifier.hashPassword(password, salt);

        // Create user
        final user = WebUser(
          id: Uuid().v4(),
          username: 'testuser',
          passwordHash: passwordHash,
          sponsorId: matchedPattern.sponsorId,
          linkingCode: linkingCode,
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        await userRepo.createUser(user);

        // Generate JWT
        final authToken = AuthToken(
          sub: user.id,
          username: user.username,
          sponsorId: user.sponsorId,
          sponsorUrl: matchedPattern.portalUrl,
          appUuid: user.appUuid,
          iat: DateTime.now(),
          exp: DateTime.now().add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);

        // Verify token
        final decoded = jwtService.verifyToken(jwt);
        expect(decoded, isNotNull);
        expect(decoded!.username, equals('testuser'));
        expect(decoded.sponsorId, equals('test-sponsor'));
      });

      test('prevents duplicate username for same sponsor', () async {
        final pattern = SponsorPattern(
          patternPrefix: 'HHT-TEST-',
          sponsorId: 'test-sponsor',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://portal.test.com',
          firestoreProject: 'test-project',
          active: true,
          createdAt: DateTime.now(),
        );
        await patternRepo.createPattern(pattern);

        final user1 = WebUser(
          id: Uuid().v4(),
          username: 'duplicate',
          passwordHash: 'hash1',
          sponsorId: 'test-sponsor',
          linkingCode: 'HHT-TEST-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        await userRepo.createUser(user1);

        // Try to create duplicate
        final user2 = WebUser(
          id: Uuid().v4(),
          username: 'duplicate',
          passwordHash: 'hash2',
          sponsorId: 'test-sponsor',
          linkingCode: 'HHT-TEST-002',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        expect(
          () => userRepo.createUser(user2),
          throwsA(isA<AuthException>()),
        );
      });

      test('allows same username for different sponsors', () async {
        final user1 = WebUser(
          id: Uuid().v4(),
          username: 'sameusername',
          passwordHash: 'hash1',
          sponsorId: 'sponsor-a',
          linkingCode: 'HHT-A-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        final user2 = WebUser(
          id: Uuid().v4(),
          username: 'sameusername',
          passwordHash: 'hash2',
          sponsorId: 'sponsor-b',
          linkingCode: 'HHT-B-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        await userRepo.createUser(user1);
        await userRepo.createUser(user2); // Should not throw

        final retrieved1 = await userRepo.getUserByUsername('sameusername', 'sponsor-a');
        final retrieved2 = await userRepo.getUserByUsername('sameusername', 'sponsor-b');

        expect(retrieved1, isNotNull);
        expect(retrieved2, isNotNull);
        expect(retrieved1!.id, isNot(equals(retrieved2!.id)));
      });
    });

    group('Complete Login Flow', () {
      test('successful login with valid credentials', () async {
        // Setup: Create user
        final password = 'SecurePassword123!';
        final salt = 'randomsalt123456';
        final passwordHash = passwordVerifier.hashPassword(password, salt);

        final user = WebUser(
          id: Uuid().v4(),
          username: 'loginuser',
          passwordHash: passwordHash,
          sponsorId: 'test-sponsor',
          linkingCode: 'HHT-TEST-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
        );

        await userRepo.createUser(user);

        // Login attempt: Check rate limit
        final rateLimitKey = 'login:192.168.1.1:loginuser';
        expect(rateLimiter.checkLimit(rateLimitKey), isTrue);

        // Retrieve user
        final storedUser = await userRepo.getUserByUsername('loginuser', 'test-sponsor');
        expect(storedUser, isNotNull);

        // Verify password
        final passwordValid = passwordVerifier.verify(
          password,
          storedUser!.passwordHash,
          salt,
        );
        expect(passwordValid, isTrue);

        // Reset failed attempts on successful login
        final updatedUser = await userRepo.resetFailedAttempts(storedUser.id);
        expect(updatedUser.failedAttempts, equals(0));
        expect(updatedUser.lastLoginAt, isNotNull);

        // Generate JWT
        final authToken = AuthToken(
          sub: updatedUser.id,
          username: updatedUser.username,
          sponsorId: updatedUser.sponsorId,
          sponsorUrl: 'https://portal.test.com',
          appUuid: updatedUser.appUuid,
          iat: DateTime.now(),
          exp: DateTime.now().add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);
        expect(jwt, isNotEmpty);
      });

      test('failed login increments failed attempts', () async {
        final user = WebUser(
          id: Uuid().v4(),
          username: 'failuser',
          passwordHash: 'correcthash',
          sponsorId: 'test-sponsor',
          linkingCode: 'HHT-TEST-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
          failedAttempts: 0,
        );

        await userRepo.createUser(user);

        // Failed login attempt
        final updatedUser = await userRepo.incrementFailedAttempts(user.id);
        expect(updatedUser.failedAttempts, equals(1));

        // Multiple failed attempts
        await userRepo.incrementFailedAttempts(user.id);
        await userRepo.incrementFailedAttempts(user.id);
        final finalUser = await userRepo.incrementFailedAttempts(user.id);

        expect(finalUser.failedAttempts, equals(4));
      });

      test('locks account after 5 failed attempts', () async {
        final user = WebUser(
          id: Uuid().v4(),
          username: 'lockuser',
          passwordHash: 'correcthash',
          sponsorId: 'test-sponsor',
          linkingCode: 'HHT-TEST-001',
          appUuid: Uuid().v4(),
          createdAt: DateTime.now(),
          failedAttempts: 4,
        );

        await userRepo.createUser(user);

        // 5th failed attempt triggers lockout
        await userRepo.incrementFailedAttempts(user.id);

        final lockoutTime = DateTime.now().add(Duration(minutes: 15));
        final lockedUser = await userRepo.lockAccount(user.id, lockoutTime);

        expect(lockedUser.lockedUntil, isNotNull);
        expect(lockedUser.isLocked, isTrue);
      });

      test('enforces rate limiting on login attempts', () {
        final rateLimitKey = 'login:192.168.1.1:testuser';

        // First 5 attempts should succeed
        for (var i = 0; i < 5; i++) {
          expect(rateLimiter.checkLimit(rateLimitKey), isTrue);
        }

        // 6th attempt should be blocked
        expect(rateLimiter.checkLimit(rateLimitKey), isFalse);
      });
    });

    group('Token Refresh Flow', () {
      test('refreshes valid token successfully', () async {
        final originalToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'test-sponsor',
          sponsorUrl: 'https://portal.test.com',
          appUuid: Uuid().v4(),
          iat: DateTime.now().subtract(Duration(minutes: 10)),
          exp: DateTime.now().add(Duration(minutes: 5)),
        );

        final jwt = jwtService.generateToken(originalToken);
        final refreshedJwt = jwtService.refreshToken(jwt);

        expect(refreshedJwt, isNotNull);
        expect(refreshedJwt, isNot(equals(jwt)));

        final decoded = jwtService.verifyToken(refreshedJwt!);
        expect(decoded, isNotNull);
        expect(decoded!.username, equals('testuser'));
        expect(decoded.exp.isAfter(originalToken.exp), isTrue);
      });

      test('rejects refresh of expired token', () {
        final expiredToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'test-sponsor',
          sponsorUrl: 'https://portal.test.com',
          appUuid: Uuid().v4(),
          iat: DateTime.now().subtract(Duration(minutes: 20)),
          exp: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final jwt = jwtService.generateToken(expiredToken);
        final refreshed = jwtService.refreshToken(jwt);

        expect(refreshed, isNull);
      });
    });

    group('Sponsor Pattern Matching', () {
      test('matches longest prefix first', () async {
        await patternRepo.createPattern(SponsorPattern(
          patternPrefix: 'HHT-',
          sponsorId: 'general',
          sponsorName: 'General',
          portalUrl: 'https://general.test.com',
          firestoreProject: 'general-project',
          active: true,
          createdAt: DateTime.now(),
        ));

        await patternRepo.createPattern(SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'cure-hht',
          sponsorName: 'Cure HHT',
          portalUrl: 'https://cure.test.com',
          firestoreProject: 'cure-project',
          active: true,
          createdAt: DateTime.now(),
        ));

        // Should match more specific pattern
        final pattern = await patternRepo.findByLinkingCode('HHT-CUR-12345');
        expect(pattern, isNotNull);
        expect(pattern!.sponsorId, equals('cure-hht'));

        // Should match general pattern
        final pattern2 = await patternRepo.findByLinkingCode('HHT-OTHER-12345');
        expect(pattern2, isNotNull);
        expect(pattern2!.sponsorId, equals('general'));
      });

      test('ignores inactive patterns', () async {
        await patternRepo.createPattern(SponsorPattern(
          patternPrefix: 'HHT-INACTIVE-',
          sponsorId: 'inactive-sponsor',
          sponsorName: 'Inactive',
          portalUrl: 'https://inactive.test.com',
          firestoreProject: 'inactive-project',
          active: false,
          createdAt: DateTime.now(),
          decommissionedAt: DateTime.now(),
        ));

        final pattern = await patternRepo.findByLinkingCode('HHT-INACTIVE-12345');
        expect(pattern, isNull);
      });
    });
  });
}
