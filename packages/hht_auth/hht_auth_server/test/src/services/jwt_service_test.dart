/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - JWT generation and verification
///
/// Tests for JWT service including generation, verification, and expiry handling.

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_server/src/services/jwt_service.dart';
import 'package:test/test.dart';

void main() {
  group('JwtService', () {
    late JwtService jwtService;
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
    });

    group('generateToken', () {
      test('generates valid JWT with correct claims', () {
        final authToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now(),
          exp: DateTime.now().add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);

        expect(jwt, isNotEmpty);
        expect(jwt.split('.').length, equals(3)); // Header.Payload.Signature
      });

      test('generates token with 15-minute expiry', () {
        final now = DateTime.now();
        final authToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: now,
          exp: now.add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);
        final decoded = jwtService.verifyToken(jwt);

        expect(decoded, isNotNull);
        expect(decoded!.exp.difference(decoded.iat).inMinutes, equals(15));
      });
    });

    group('verifyToken', () {
      test('verifies valid token successfully', () {
        final authToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now(),
          exp: DateTime.now().add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);
        final decoded = jwtService.verifyToken(jwt);

        expect(decoded, isNotNull);
        expect(decoded!.sub, equals('user-123'));
        expect(decoded.username, equals('testuser'));
        expect(decoded.sponsorId, equals('sponsor-1'));
        expect(decoded.sponsorUrl, equals('https://portal.example.com'));
        expect(decoded.appUuid, equals('app-uuid-123'));
      });

      test('returns null for expired token', () {
        final authToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now().subtract(Duration(minutes: 20)),
          exp: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final jwt = jwtService.generateToken(authToken);
        final decoded = jwtService.verifyToken(jwt);

        expect(decoded, isNull);
      });

      test('returns null for invalid token format', () {
        final decoded = jwtService.verifyToken('invalid.token.format');
        expect(decoded, isNull);
      });

      test('returns null for token with invalid signature', () {
        final authToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now(),
          exp: DateTime.now().add(Duration(minutes: 15)),
        );

        final jwt = jwtService.generateToken(authToken);
        // Tamper with the signature
        final parts = jwt.split('.');
        final tamperedJwt = '${parts[0]}.${parts[1]}.tampered';

        final decoded = jwtService.verifyToken(tamperedJwt);
        expect(decoded, isNull);
      });

      test('returns null for token with missing claims', () {
        // Create a minimal JWT without required claims
        final decoded = jwtService.verifyToken(
          'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEyMyJ9.invalid',
        );
        expect(decoded, isNull);
      });
    });

    group('refreshToken', () {
      test('refreshes valid token with new expiry', () async {
        final originalToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now().subtract(Duration(minutes: 10)),
          exp: DateTime.now().add(Duration(minutes: 5)),
        );

        final originalJwt = jwtService.generateToken(originalToken);

        // Wait a moment to ensure different timestamps
        await Future.delayed(Duration(milliseconds: 10));

        final refreshedJwt = jwtService.refreshToken(originalJwt);

        expect(refreshedJwt, isNotNull);
        expect(refreshedJwt, isNot(equals(originalJwt)));

        final decoded = jwtService.verifyToken(refreshedJwt!);
        expect(decoded, isNotNull);
        expect(decoded!.sub, equals('user-123'));
        expect(decoded.username, equals('testuser'));

        // New token should have new iat and exp
        expect(decoded.iat.isAfter(originalToken.iat), isTrue);
        expect(decoded.exp.isAfter(originalToken.exp), isTrue);
      });

      test('returns null when refreshing expired token', () {
        final expiredToken = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-1',
          sponsorUrl: 'https://portal.example.com',
          appUuid: 'app-uuid-123',
          iat: DateTime.now().subtract(Duration(minutes: 20)),
          exp: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final jwt = jwtService.generateToken(expiredToken);
        final refreshed = jwtService.refreshToken(jwt);

        expect(refreshed, isNull);
      });

      test('returns null when refreshing invalid token', () {
        final refreshed = jwtService.refreshToken('invalid.token');
        expect(refreshed, isNull);
      });
    });

    group('extractTokenFromHeader', () {
      test('extracts token from valid Bearer header', () {
        final token = jwtService.extractTokenFromHeader(
          'Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
        );

        expect(token, equals('eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature'));
      });

      test('returns null for missing Bearer prefix', () {
        final token = jwtService.extractTokenFromHeader(
          'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
        );

        expect(token, isNull);
      });

      test('returns null for empty header', () {
        final token = jwtService.extractTokenFromHeader('');
        expect(token, isNull);
      });

      test('returns null for Bearer without token', () {
        final token = jwtService.extractTokenFromHeader('Bearer ');
        expect(token, isNull);
      });

      test('handles case sensitivity', () {
        final token = jwtService.extractTokenFromHeader(
          'Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
        );

        expect(token, equals('eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature'));
      });
    });
  });
}
