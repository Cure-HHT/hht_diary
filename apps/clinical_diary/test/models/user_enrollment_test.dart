// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserEnrollment', () {
    final testEnrolledAt = DateTime(2024, 1, 15, 10, 30);

    group('constructor', () {
      test('creates enrollment with required fields', () {
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'jwt-token-abc',
          enrolledAt: testEnrolledAt,
        );

        expect(enrollment.userId, 'user-123');
        expect(enrollment.jwtToken, 'jwt-token-abc');
        expect(enrollment.enrolledAt, testEnrolledAt);
      });

      test('accepts empty strings for userId and jwtToken', () {
        final enrollment = UserEnrollment(
          userId: '',
          jwtToken: '',
          enrolledAt: testEnrolledAt,
        );

        expect(enrollment.userId, '');
        expect(enrollment.jwtToken, '');
      });

      test('accepts very long tokens', () {
        final longToken = 'a' * 10000;
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: longToken,
          enrolledAt: testEnrolledAt,
        );

        expect(enrollment.jwtToken, longToken);
        expect(enrollment.jwtToken.length, 10000);
      });
    });

    group('fromJson', () {
      test('parses valid JSON', () {
        final json = {
          'userId': 'user-456',
          'jwtToken': 'jwt-token-xyz',
          'enrolledAt': '2024-01-15T10:30:00.000',
        };

        final enrollment = UserEnrollment.fromJson(json);

        expect(enrollment.userId, 'user-456');
        expect(enrollment.jwtToken, 'jwt-token-xyz');
        expect(enrollment.enrolledAt.year, 2024);
        expect(enrollment.enrolledAt.month, 1);
        expect(enrollment.enrolledAt.day, 15);
        expect(enrollment.enrolledAt.hour, 10);
        expect(enrollment.enrolledAt.minute, 30);
      });

      test('parses ISO 8601 date with timezone', () {
        final json = {
          'userId': 'user-123',
          'jwtToken': 'jwt-token',
          'enrolledAt': '2024-06-20T14:30:00.000Z',
        };

        final enrollment = UserEnrollment.fromJson(json);

        expect(enrollment.enrolledAt.year, 2024);
        expect(enrollment.enrolledAt.month, 6);
        expect(enrollment.enrolledAt.day, 20);
      });

      test('throws on missing userId', () {
        final json = {
          'jwtToken': 'jwt-token',
          'enrolledAt': '2024-01-15T10:30:00.000',
        };

        expect(
          () => UserEnrollment.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on missing jwtToken', () {
        final json = {
          'userId': 'user-123',
          'enrolledAt': '2024-01-15T10:30:00.000',
        };

        expect(
          () => UserEnrollment.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on missing enrolledAt', () {
        final json = {
          'userId': 'user-123',
          'jwtToken': 'jwt-token',
        };

        expect(
          () => UserEnrollment.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws on invalid date format', () {
        final json = {
          'userId': 'user-123',
          'jwtToken': 'jwt-token',
          'enrolledAt': 'not-a-date',
        };

        expect(
          () => UserEnrollment.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on null values', () {
        final json = <String, dynamic>{
          'userId': null,
          'jwtToken': 'jwt-token',
          'enrolledAt': '2024-01-15T10:30:00.000',
        };

        expect(
          () => UserEnrollment.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final enrollment = UserEnrollment(
          userId: 'user-789',
          jwtToken: 'jwt-token-123',
          enrolledAt: testEnrolledAt,
        );

        final json = enrollment.toJson();

        expect(json['userId'], 'user-789');
        expect(json['jwtToken'], 'jwt-token-123');
        expect(json['enrolledAt'], testEnrolledAt.toIso8601String());
      });

      test('produces valid ISO 8601 date string', () {
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'jwt-token',
          enrolledAt: DateTime(2024, 12, 31, 23, 59, 59),
        );

        final json = enrollment.toJson();

        expect(json['enrolledAt'], contains('2024-12-31'));
        expect(json['enrolledAt'], contains('23:59:59'));
      });

      test('handles microsecond precision', () {
        final preciseDate = DateTime(2024, 1, 15, 10, 30, 45, 123, 456);
        final enrollment = UserEnrollment(
          userId: 'user-123',
          jwtToken: 'jwt-token',
          enrolledAt: preciseDate,
        );

        final json = enrollment.toJson();
        final parsed = DateTime.parse(json['enrolledAt'] as String);

        expect(parsed.year, 2024);
        expect(parsed.month, 1);
        expect(parsed.day, 15);
        expect(parsed.hour, 10);
        expect(parsed.minute, 30);
        expect(parsed.second, 45);
      });
    });

    group('roundtrip', () {
      test('toJson then fromJson preserves all data', () {
        final original = UserEnrollment(
          userId: 'roundtrip-user',
          jwtToken: 'roundtrip-token-abc123',
          enrolledAt: testEnrolledAt,
        );

        final json = original.toJson();
        final restored = UserEnrollment.fromJson(json);

        expect(restored.userId, original.userId);
        expect(restored.jwtToken, original.jwtToken);
        expect(restored.enrolledAt, original.enrolledAt);
      });

      test('multiple roundtrips preserve data', () {
        var enrollment = UserEnrollment(
          userId: 'multi-trip',
          jwtToken: 'multi-token',
          enrolledAt: testEnrolledAt,
        );

        // Three roundtrips
        for (var i = 0; i < 3; i++) {
          final json = enrollment.toJson();
          enrollment = UserEnrollment.fromJson(json);
        }

        expect(enrollment.userId, 'multi-trip');
        expect(enrollment.jwtToken, 'multi-token');
        expect(enrollment.enrolledAt, testEnrolledAt);
      });

      test('special characters in token are preserved', () {
        const specialToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
            'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.'
            'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final original = UserEnrollment(
          userId: 'jwt-user',
          jwtToken: specialToken,
          enrolledAt: testEnrolledAt,
        );

        final json = original.toJson();
        final restored = UserEnrollment.fromJson(json);

        expect(restored.jwtToken, specialToken);
      });
    });
  });
}
