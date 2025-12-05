/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching interfaces

import 'package:test/test.dart';
import 'package:hht_auth_core/src/models/sponsor_pattern.dart';

void main() {
  group('SponsorPattern', () {
    final testCreatedAt = DateTime.utc(2025, 12, 4, 10, 0, 0);
    final testDecommissionedAt = DateTime.utc(2025, 12, 5, 10, 0, 0);

    group('constructor', () {
      test('creates active pattern with required fields', () {
        final pattern = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
        );

        expect(pattern.patternPrefix, 'HHT-CUR-');
        expect(pattern.sponsorId, 'sponsor-abc');
        expect(pattern.sponsorName, 'Test Sponsor');
        expect(pattern.portalUrl, 'https://sponsor.example.com');
        expect(pattern.firestoreProject, 'project-123');
        expect(pattern.active, true);
        expect(pattern.createdAt, testCreatedAt);
        expect(pattern.decommissionedAt, isNull);
      });

      test('creates decommissioned pattern', () {
        final pattern = SponsorPattern(
          patternPrefix: 'OLD-',
          sponsorId: 'sponsor-old',
          sponsorName: 'Old Sponsor',
          portalUrl: 'https://old.example.com',
          firestoreProject: 'project-old',
          active: false,
          createdAt: testCreatedAt,
          decommissionedAt: testDecommissionedAt,
        );

        expect(pattern.active, false);
        expect(pattern.decommissionedAt, testDecommissionedAt);
      });
    });

    group('JSON serialization', () {
      test('toJson converts to correct structure', () {
        final pattern = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
          decommissionedAt: testDecommissionedAt,
        );

        final json = pattern.toJson();

        expect(json['patternPrefix'], 'HHT-CUR-');
        expect(json['sponsorId'], 'sponsor-abc');
        expect(json['sponsorName'], 'Test Sponsor');
        expect(json['portalUrl'], 'https://sponsor.example.com');
        expect(json['firestoreProject'], 'project-123');
        expect(json['active'], true);
        expect(json['createdAt'], testCreatedAt.toIso8601String());
        expect(json['decommissionedAt'], testDecommissionedAt.toIso8601String());
      });

      test('fromJson creates instance', () {
        final json = {
          'patternPrefix': 'HHT-CUR-',
          'sponsorId': 'sponsor-abc',
          'sponsorName': 'Test Sponsor',
          'portalUrl': 'https://sponsor.example.com',
          'firestoreProject': 'project-123',
          'active': true,
          'createdAt': testCreatedAt.toIso8601String(),
          'decommissionedAt': testDecommissionedAt.toIso8601String(),
        };

        final pattern = SponsorPattern.fromJson(json);

        expect(pattern.patternPrefix, 'HHT-CUR-');
        expect(pattern.sponsorId, 'sponsor-abc');
        expect(pattern.decommissionedAt, testDecommissionedAt);
      });

      test('round-trip serialization preserves data', () {
        final original = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
        );

        final restored = SponsorPattern.fromJson(original.toJson());
        expect(restored, equals(original));
      });
    });

    group('equality', () {
      test('identical patterns are equal', () {
        final pattern1 = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
        );

        final pattern2 = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
        );

        expect(pattern1, equals(pattern2));
        expect(pattern1.hashCode, equals(pattern2.hashCode));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = SponsorPattern(
          patternPrefix: 'HHT-CUR-',
          sponsorId: 'sponsor-abc',
          sponsorName: 'Test Sponsor',
          portalUrl: 'https://sponsor.example.com',
          firestoreProject: 'project-123',
          active: true,
          createdAt: testCreatedAt,
        );

        final copy = original.copyWith(
          active: false,
          decommissionedAt: testDecommissionedAt,
        );

        expect(copy.patternPrefix, original.patternPrefix);
        expect(copy.active, false);
        expect(copy.decommissionedAt, testDecommissionedAt);
      });
    });
  });
}
