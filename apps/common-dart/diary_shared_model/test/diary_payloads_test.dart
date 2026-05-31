// Verifies: DIARY-DEV-shared-events-catalog/A+D
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('EpistaxisEventPayload', () {
    test('DIARY-DEV-shared-events-catalog/A: round-trips a full payload', () {
      const json = <String, Object?>{
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
        'endTime': '2025-10-15T14:45:00.000-05:00',
        'endTimeZone': 'America/New_York',
        'endTimeUtcOffset': '-05:00',
        'intensity': 'dripping',
      };
      final payload = EpistaxisEventPayload.fromJson(json);
      expect(payload.intensity, NosebleedIntensity.dripping);
      expect(payload.startTimeZone, 'America/New_York');
      expect(payload.toJson(), json);
    });

    test('round-trips a minimal payload (no end fields, no intensity)', () {
      const json = <String, Object?>{
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
      };
      final payload = EpistaxisEventPayload.fromJson(json);
      expect(payload.endTime, isNull);
      expect(payload.intensity, isNull);
      expect(payload.toJson(), json);
    });

    test('an unrecognized intensity wire value parses to null', () {
      final payload = EpistaxisEventPayload.fromJson(const {
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'UTC',
        'startTimeUtcOffset': '+00:00',
        'intensity': 'torrential',
      });
      expect(payload.intensity, isNull);
    });

    test(
      'DIARY-DEV-shared-events-catalog/D: no secret-like keys in the contract',
      () {
        final keys = EpistaxisEventPayload.fromJson(const {
          'startTime': '2025-10-15T14:30:00.000-05:00',
          'startTimeZone': 'UTC',
          'startTimeUtcOffset': '+00:00',
        }).toJson().keys;
        expect(keys.any((k) => k.toLowerCase().contains('token')), isFalse);
        expect(keys.any((k) => k.toLowerCase().contains('password')), isFalse);
      },
    );
  });

  group('DayMarkerPayload', () {
    test('round-trips a date marker', () {
      const json = <String, Object?>{'date': '2025-10-15'};
      expect(DayMarkerPayload.fromJson(json).toJson(), json);
    });
  });
}
