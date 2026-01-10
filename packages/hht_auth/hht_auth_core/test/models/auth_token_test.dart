/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:test/test.dart';
import 'package:hht_auth_core/src/models/auth_token.dart';

void main() {
  group('AuthToken', () {
    final testDateTime = DateTime.utc(2025, 12, 4, 10, 0, 0);
    final testExpiry = testDateTime.add(const Duration(minutes: 15));

    group('constructor', () {
      test('creates instance with all required fields', () {
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        expect(token.sub, 'user-123');
        expect(token.username, 'testuser');
        expect(token.sponsorId, 'sponsor-abc');
        expect(token.sponsorUrl, 'https://sponsor.example.com');
        expect(token.appUuid, 'app-uuid-456');
        expect(token.iat, testDateTime);
        expect(token.exp, testExpiry);
      });
    });

    group('JSON serialization', () {
      test('toJson converts to correct JSON structure', () {
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final json = token.toJson();

        expect(json['sub'], 'user-123');
        expect(json['username'], 'testuser');
        expect(json['sponsorId'], 'sponsor-abc');
        expect(json['sponsorUrl'], 'https://sponsor.example.com');
        expect(json['appUuid'], 'app-uuid-456');
        expect(json['iat'], testDateTime.toIso8601String());
        expect(json['exp'], testExpiry.toIso8601String());
      });

      test('fromJson creates instance from JSON', () {
        final json = {
          'sub': 'user-123',
          'username': 'testuser',
          'sponsorId': 'sponsor-abc',
          'sponsorUrl': 'https://sponsor.example.com',
          'appUuid': 'app-uuid-456',
          'iat': testDateTime.toIso8601String(),
          'exp': testExpiry.toIso8601String(),
        };

        final token = AuthToken.fromJson(json);

        expect(token.sub, 'user-123');
        expect(token.username, 'testuser');
        expect(token.sponsorId, 'sponsor-abc');
        expect(token.sponsorUrl, 'https://sponsor.example.com');
        expect(token.appUuid, 'app-uuid-456');
        expect(token.iat, testDateTime);
        expect(token.exp, testExpiry);
      });

      test('round-trip serialization preserves data', () {
        final original = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final json = original.toJson();
        final restored = AuthToken.fromJson(json);

        expect(restored.sub, original.sub);
        expect(restored.username, original.username);
        expect(restored.sponsorId, original.sponsorId);
        expect(restored.sponsorUrl, original.sponsorUrl);
        expect(restored.appUuid, original.appUuid);
        expect(restored.iat, original.iat);
        expect(restored.exp, original.exp);
      });
    });

    group('computed properties', () {
      test('isExpired returns false for future expiry', () {
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: DateTime.now(),
          exp: DateTime.now().add(const Duration(minutes: 5)),
        );

        expect(token.isExpired, false);
      });

      test('isExpired returns true for past expiry', () {
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: DateTime.now().subtract(const Duration(minutes: 20)),
          exp: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(token.isExpired, true);
      });

      test('remainingTime returns correct duration', () {
        final now = DateTime.now();
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: now,
          exp: now.add(const Duration(minutes: 10)),
        );

        final remaining = token.remainingTime;
        // Allow some margin for test execution time
        expect(remaining.inMinutes, greaterThanOrEqualTo(9));
        expect(remaining.inMinutes, lessThanOrEqualTo(10));
      });

      test('remainingTime returns zero for expired token', () {
        final token = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: DateTime.now().subtract(const Duration(minutes: 20)),
          exp: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(token.remainingTime, Duration.zero);
      });
    });

    group('equality', () {
      test('identical tokens are equal', () {
        final token1 = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final token2 = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        expect(token1, equals(token2));
        expect(token1.hashCode, equals(token2.hashCode));
      });

      test('different tokens are not equal', () {
        final token1 = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final token2 = AuthToken(
          sub: 'user-456', // Different sub
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        expect(token1, isNot(equals(token2)));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final copy = original.copyWith(
          username: 'newuser',
          exp: testExpiry.add(const Duration(minutes: 5)),
        );

        expect(copy.sub, original.sub);
        expect(copy.username, 'newuser');
        expect(copy.sponsorId, original.sponsorId);
        expect(copy.sponsorUrl, original.sponsorUrl);
        expect(copy.appUuid, original.appUuid);
        expect(copy.iat, original.iat);
        expect(copy.exp, testExpiry.add(const Duration(minutes: 5)));
      });

      test('creates identical copy when no fields specified', () {
        final original = AuthToken(
          sub: 'user-123',
          username: 'testuser',
          sponsorId: 'sponsor-abc',
          sponsorUrl: 'https://sponsor.example.com',
          appUuid: 'app-uuid-456',
          iat: testDateTime,
          exp: testExpiry,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });
  });
}
