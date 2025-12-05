/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00081: User Document Schema

import 'package:test/test.dart';
import 'package:hht_auth_core/src/models/web_user.dart';

void main() {
  group('WebUser', () {
    final testCreatedAt = DateTime.utc(2025, 12, 4, 10, 0, 0);
    final testLastLoginAt = DateTime.utc(2025, 12, 4, 11, 0, 0);
    final testLockedUntil = DateTime.utc(2025, 12, 4, 12, 0, 0);

    group('constructor', () {
      test('creates instance with required fields', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        expect(user.id, 'user-123');
        expect(user.username, 'testuser');
        expect(user.passwordHash, 'hash123');
        expect(user.sponsorId, 'sponsor-abc');
        expect(user.linkingCode, 'HHT-CUR-12345');
        expect(user.appUuid, 'app-uuid-456');
        expect(user.createdAt, testCreatedAt);
        expect(user.lastLoginAt, isNull);
        expect(user.failedAttempts, 0);
        expect(user.lockedUntil, isNull);
      });

      test('creates instance with all fields', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
          failedAttempts: 2,
          lockedUntil: testLockedUntil,
        );

        expect(user.lastLoginAt, testLastLoginAt);
        expect(user.failedAttempts, 2);
        expect(user.lockedUntil, testLockedUntil);
      });
    });

    group('JSON serialization', () {
      test('toJson converts to correct JSON structure', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
          failedAttempts: 2,
          lockedUntil: testLockedUntil,
        );

        final json = user.toJson();

        expect(json['id'], 'user-123');
        expect(json['username'], 'testuser');
        expect(json['passwordHash'], 'hash123');
        expect(json['sponsorId'], 'sponsor-abc');
        expect(json['linkingCode'], 'HHT-CUR-12345');
        expect(json['appUuid'], 'app-uuid-456');
        expect(json['createdAt'], testCreatedAt.toIso8601String());
        expect(json['lastLoginAt'], testLastLoginAt.toIso8601String());
        expect(json['failedAttempts'], 2);
        expect(json['lockedUntil'], testLockedUntil.toIso8601String());
      });

      test('toJson handles null fields', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        final json = user.toJson();

        expect(json['lastLoginAt'], isNull);
        expect(json['lockedUntil'], isNull);
      });

      test('fromJson creates instance from JSON', () {
        final json = {
          'id': 'user-123',
          'username': 'testuser',
          'passwordHash': 'hash123',
          'sponsorId': 'sponsor-abc',
          'linkingCode': 'HHT-CUR-12345',
          'appUuid': 'app-uuid-456',
          'createdAt': testCreatedAt.toIso8601String(),
          'lastLoginAt': testLastLoginAt.toIso8601String(),
          'failedAttempts': 2,
          'lockedUntil': testLockedUntil.toIso8601String(),
        };

        final user = WebUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.username, 'testuser');
        expect(user.passwordHash, 'hash123');
        expect(user.sponsorId, 'sponsor-abc');
        expect(user.linkingCode, 'HHT-CUR-12345');
        expect(user.appUuid, 'app-uuid-456');
        expect(user.createdAt, testCreatedAt);
        expect(user.lastLoginAt, testLastLoginAt);
        expect(user.failedAttempts, 2);
        expect(user.lockedUntil, testLockedUntil);
      });

      test('round-trip serialization preserves data', () {
        final original = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
          failedAttempts: 2,
          lockedUntil: testLockedUntil,
        );

        final json = original.toJson();
        final restored = WebUser.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('computed properties', () {
      test('isLocked returns false when lockedUntil is null', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        expect(user.isLocked, false);
      });

      test('isLocked returns true when lockedUntil is in future', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lockedUntil: DateTime.now().add(const Duration(minutes: 5)),
        );

        expect(user.isLocked, true);
      });

      test('isLocked returns false when lockedUntil is in past', () {
        final user = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lockedUntil: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(user.isLocked, false);
      });
    });

    group('equality', () {
      test('identical users are equal', () {
        final user1 = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        final user2 = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('different users are not equal', () {
        final user1 = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        final user2 = WebUser(
          id: 'user-456', // Different ID
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        expect(user1, isNot(equals(user2)));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        final copy = original.copyWith(
          username: 'newuser',
          failedAttempts: 3,
          lastLoginAt: testLastLoginAt,
        );

        expect(copy.id, original.id);
        expect(copy.username, 'newuser');
        expect(copy.passwordHash, original.passwordHash);
        expect(copy.sponsorId, original.sponsorId);
        expect(copy.linkingCode, original.linkingCode);
        expect(copy.appUuid, original.appUuid);
        expect(copy.createdAt, original.createdAt);
        expect(copy.failedAttempts, 3);
        expect(copy.lastLoginAt, testLastLoginAt);
      });

      test('creates identical copy when no fields specified', () {
        final original = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('can clear optional fields by passing null', () {
        final original = WebUser(
          id: 'user-123',
          username: 'testuser',
          passwordHash: 'hash123',
          sponsorId: 'sponsor-abc',
          linkingCode: 'HHT-CUR-12345',
          appUuid: 'app-uuid-456',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
          lockedUntil: testLockedUntil,
        );

        final copy = original.copyWith(
          lastLoginAt: null,
          lockedUntil: null,
        );

        expect(copy.lastLoginAt, isNull);
        expect(copy.lockedUntil, isNull);
      });
    });
  });
}
