// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NosebleedIntensity', () {
    test('displayName returns correct string for each intensity', () {
      expect(NosebleedIntensity.spotting.displayName, 'Spotting');
      expect(NosebleedIntensity.dripping.displayName, 'Dripping');
      expect(
        NosebleedIntensity.drippingQuickly.displayName,
        'Dripping quickly',
      );
      expect(NosebleedIntensity.steadyStream.displayName, 'Steady stream');
      expect(NosebleedIntensity.pouring.displayName, 'Pouring');
      expect(NosebleedIntensity.gushing.displayName, 'Gushing');
    });

    group('fromString', () {
      test('parses display names correctly', () {
        expect(
          NosebleedIntensity.fromString('Spotting'),
          NosebleedIntensity.spotting,
        );
        expect(
          NosebleedIntensity.fromString('Dripping quickly'),
          NosebleedIntensity.drippingQuickly,
        );
      });

      test('parses enum names correctly', () {
        expect(
          NosebleedIntensity.fromString('spotting'),
          NosebleedIntensity.spotting,
        );
        expect(
          NosebleedIntensity.fromString('drippingQuickly'),
          NosebleedIntensity.drippingQuickly,
        );
      });

      test('returns null for invalid values', () {
        expect(NosebleedIntensity.fromString('invalid'), isNull);
        expect(NosebleedIntensity.fromString(''), isNull);
      });

      test('returns null for null input', () {
        expect(NosebleedIntensity.fromString(null), isNull);
      });
    });
  });

  group('NosebleedRecord', () {
    final testStartTime = DateTime(2024, 1, 15, 10, 30);
    final testEndTime = DateTime(2024, 1, 15, 10, 45);

    group('constructor', () {
      test('creates record with required fields', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );

        expect(record.id, 'test-123');
        expect(record.startTime, testStartTime);
        expect(record.isNoNosebleedsEvent, false);
        expect(record.isUnknownEvent, false);
        expect(record.isIncomplete, false);
      });

      test('creates record with all fields', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime,
          intensity: NosebleedIntensity.dripping,
          notes: 'Test notes',
          isNoNosebleedsEvent: false,
          isUnknownEvent: false,
          isIncomplete: false,
          deviceUuid: 'device-uuid',
        );

        expect(record.startTime, testStartTime);
        expect(record.endTime, testEndTime);
        expect(record.intensity, NosebleedIntensity.dripping);
        expect(record.notes, 'Test notes');
        expect(record.deviceUuid, 'device-uuid');
      });

      test('sets createdAt to now if not provided', () {
        final before = DateTime.now();
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );
        final after = DateTime.now();

        expect(
          record.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          true,
        );
        expect(
          record.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          true,
        );
      });
    });

    group('fromJson', () {
      test('parses minimal JSON', () {
        final json = {'id': 'test-123', 'startTime': '2024-01-15T00:00:00.000'};

        final record = NosebleedRecord.fromJson(json);

        expect(record.id, 'test-123');
        expect(record.startTime.year, 2024);
        expect(record.startTime.month, 1);
        expect(record.startTime.day, 15);
      });

      test('parses complete JSON', () {
        final json = {
          'id': 'test-123',
          'startTime': '2024-01-15T10:30:00.000',
          'endTime': '2024-01-15T10:45:00.000',
          'intensity': 'dripping',
          'notes': 'Test notes',
          'isNoNosebleedsEvent': false,
          'isUnknownEvent': false,
          'isIncomplete': true,
          'deviceUuid': 'device-uuid',
          'createdAt': '2024-01-15T10:00:00.000',
          'syncedAt': '2024-01-15T11:00:00.000',
        };

        final record = NosebleedRecord.fromJson(json);

        expect(record.startTime, isNotNull);
        expect(record.endTime, isNotNull);
        expect(record.intensity, NosebleedIntensity.dripping);
        expect(record.notes, 'Test notes');
        expect(record.isIncomplete, true);
        expect(record.deviceUuid, 'device-uuid');
        expect(record.syncedAt, isNotNull);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'test-123',
          'startTime': '2024-01-15T10:30:00.000',
          'endTime': null,
          'intensity': null,
          'notes': null,
        };

        final record = NosebleedRecord.fromJson(json);

        expect(record.startTime, isNotNull);
        expect(record.endTime, isNull);
        expect(record.intensity, isNull);
        expect(record.notes, isNull);
      });

      test('defaults boolean fields to false', () {
        final json = {'id': 'test-123', 'startTime': '2024-01-15T00:00:00.000'};

        final record = NosebleedRecord.fromJson(json);

        expect(record.isNoNosebleedsEvent, false);
        expect(record.isUnknownEvent, false);
        expect(record.isIncomplete, false);
      });
    });

    group('toJson', () {
      test('serializes all fields with ISO 8601 timezone offset', () {
        final createdAt = DateTime(2024, 1, 15, 10, 0);
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime,
          intensity: NosebleedIntensity.dripping,
          notes: 'Test notes',
          deviceUuid: 'device-uuid',
          createdAt: createdAt,
        );

        final json = record.toJson();

        expect(json['id'], 'test-123');
        // Timestamps now include timezone offset (e.g., "2024-01-15T10:30:00.000-05:00")
        expect(json['startTime'], isA<String>());
        expect(json['startTime'], contains('2024-01-15'));
        expect(json['endTime'], isA<String>());
        expect(json['endTime'], contains('2024-01-15'));
        expect(json['intensity'], 'dripping');
        expect(json['notes'], 'Test notes');
        expect(json['deviceUuid'], 'device-uuid');
        expect(json['createdAt'], isA<String>());
      });

      test('handles null optional fields', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );

        final json = record.toJson();

        expect(json['startTime'], isA<String>());
        expect(json['endTime'], isNull);
        expect(json['intensity'], isNull);
        expect(json['notes'], isNull);
        expect(json['syncedAt'], isNull);
      });

      test('roundtrips correctly', () {
        // Use local times - DateTimeFormatter preserves local time with offset
        final startTime = DateTime(2024, 1, 15, 10, 30);
        final endTime = DateTime(2024, 1, 15, 10, 45);
        final original = NosebleedRecord(
          id: 'test-123',
          startTime: startTime,
          endTime: endTime,
          intensity: NosebleedIntensity.steadyStream,
          notes: 'Test notes',
          deviceUuid: 'device-uuid',
        );

        final json = original.toJson();
        final restored = NosebleedRecord.fromJson(json);

        expect(restored.id, original.id);
        // Compare the moment in time since timezone representation may differ
        expect(
          restored.startTime.millisecondsSinceEpoch,
          original.startTime.millisecondsSinceEpoch,
        );
        expect(
          restored.endTime!.millisecondsSinceEpoch,
          original.endTime!.millisecondsSinceEpoch,
        );
        expect(restored.intensity, original.intensity);
        expect(restored.notes, original.notes);
        expect(restored.deviceUuid, original.deviceUuid);
      });
    });

    group('computed properties', () {
      test('isRealEvent returns true for normal events', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );

        expect(record.isRealNosebleedEvent, true);
      });

      test('isRealEvent returns false for no-nosebleed events', () {
        final record = NosebleedRecord(
          id: 'test-123',
          isNoNosebleedsEvent: true,
          startTime: testStartTime,
        );

        expect(record.isRealNosebleedEvent, false);
      });

      test('isRealEvent returns false for unknown events', () {
        final record = NosebleedRecord(
          id: 'test-123',
          isUnknownEvent: true,
          startTime: testStartTime,
        );

        expect(record.isRealNosebleedEvent, false);
      });

      test('isComplete returns true for no-nosebleed events', () {
        final record = NosebleedRecord(
          id: 'test-123',
          isNoNosebleedsEvent: true,
          startTime: testStartTime,
        );

        expect(record.isComplete, true);
      });

      test('isComplete returns true for unknown events', () {
        final record = NosebleedRecord(
          id: 'test-123',
          isUnknownEvent: true,
          startTime: testStartTime,
        );

        expect(record.isComplete, true);
      });

      test('isComplete returns true when all required fields are set', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime,
          intensity: NosebleedIntensity.dripping,
        );

        expect(record.isComplete, true);
      });

      test('isComplete returns false when only startTime is set', () {
        // A record with only startTime (no endTime, no intensity) is incomplete
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );

        expect(record.isComplete, false);
      });

      test('isComplete returns false when endTime is missing', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          intensity: NosebleedIntensity.dripping,
        );

        expect(record.isComplete, false);
      });

      test('isComplete returns false when intensity is missing', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime,
        );

        expect(record.isComplete, false);
      });

      test('durationMinutes calculates correctly', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime, // 15 minutes after startTime
        );

        expect(record.durationMinutes, 15);
      });

      test('durationMinutes returns null when times are missing', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
        );

        expect(record.durationMinutes, isNull);
      });

      test('durationMinutes handles zero duration', () {
        final record = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testStartTime,
        );

        expect(record.durationMinutes, 0);
      });
    });

    group('copyWith', () {
      test('copies all fields when no changes', () {
        final original = NosebleedRecord(
          id: 'test-123',
          startTime: testStartTime,
          endTime: testEndTime,
          intensity: NosebleedIntensity.dripping,
          notes: 'Test notes',
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.startTime, original.startTime);
        expect(copy.endTime, original.endTime);
        expect(copy.intensity, original.intensity);
        expect(copy.notes, original.notes);
      });

      test('updates specified fields only', () {
        final original = NosebleedRecord(
          id: 'test-123',
          intensity: NosebleedIntensity.spotting,
          startTime: testStartTime,
        );

        final copy = original.copyWith(
          intensity: NosebleedIntensity.gushing,
          notes: 'Updated notes',
        );

        expect(copy.id, original.id);
        expect(copy.startTime, original.startTime);
        expect(copy.intensity, NosebleedIntensity.gushing);
        expect(copy.notes, 'Updated notes');
      });
    });
  });
}
