// CUR-583: Test duration calculation with cross-timezone times
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Clinical Data Platform
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CUR-583: Duration calculation with cross-timezone times', () {
    test('duration should account for timezone differences', () {
      // Scenario: User starts nosebleed at 8:11 PM EST, ends at 8:11 PM CET
      // These are NOT the same moment in time!
      // - 8:11 PM EST (UTC-5) = 2025-12-19T01:11:00Z
      // - 8:11 PM CET (UTC+1) = 2025-12-18T19:11:00Z
      //
      // CET is 6 hours AHEAD of EST, so 8:11 PM CET happens 6 hours BEFORE
      // 8:11 PM EST in absolute terms.
      //
      // However, the user's INTENT when they select:
      // - Start: 8:11 PM in EST timezone
      // - End: 8:11 PM in CET timezone
      // ...is that the event started at one moment and ended at another.
      //
      // If they traveled from EST to CET, they likely mean:
      // - Started at 8:11 PM local time when in EST
      // - Ended at 8:11 PM local time when in CET (which would be 6+ hours later)
      //
      // The bug: Duration shows 0m because both DateTime objects have the
      // same clock time (20:11) regardless of timezone metadata.

      // Create record with start at 8:11 PM EST and end at 8:11 PM CET
      // Using ISO 8601 strings with timezone offsets
      const startTimeString = '2025-12-18T20:11:00.000-05:00'; // 8:11 PM EST
      const endTimeString = '2025-12-18T20:11:00.000+01:00'; // 8:11 PM CET

      // Parse the times - DateTime.parse preserves the moment in time
      final startTime = DateTime.parse(startTimeString);
      final endTime = DateTime.parse(endTimeString);

      // Debug: Print the actual UTC times
      debugPrint('Start time UTC: ${startTime.toUtc()}');
      debugPrint('End time UTC: ${endTime.toUtc()}');
      debugPrint(
        'Difference in minutes: ${endTime.difference(startTime).inMinutes}',
      );

      final record = NosebleedRecord(
        id: 'test-1',
        startTime: startTime,
        endTime: endTime,
        intensity: NosebleedIntensity.dripping,
        startTimeTimezone: 'America/New_York',
        endTimeTimezone: 'Europe/Paris',
      );

      // The end time (8:11 PM CET) is actually 6 hours BEFORE start time (8:11 PM EST)
      // So duration should be negative or null (invalid)
      // Currently it might show 0 because it's comparing clock times only
      debugPrint('Duration minutes: ${record.durationMinutes}');

      // This test documents the CURRENT behavior - duration is calculated correctly
      // based on absolute time difference, but the result might not match user expectation
      //
      // 8:11 PM CET is 6 hours BEFORE 8:11 PM EST, so:
      // - difference = -360 minutes
      // - Since end is before start, durationMinutes should be null
      expect(
        record.durationMinutes,
        isNull,
        reason:
            'End time (8:11 PM CET) is before start time (8:11 PM EST) in absolute terms',
      );
    });

    test('duration shows 0m when it should show 1m minimum', () {
      // Bug: When duration is calculated as 0 minutes, the UI shows "0m"
      // but the spec says it should show "1m" minimum

      // Create a record with identical start and end times
      final sameTime = DateTime(2025, 12, 18, 20, 11);

      final record = NosebleedRecord(
        id: 'test-2',
        startTime: sameTime,
        endTime: sameTime,
        intensity: NosebleedIntensity.dripping,
      );

      // durationMinutes returns 0 for same start/end time
      expect(
        record.durationMinutes,
        equals(0),
        reason: 'Duration should be 0 when start and end are identical',
      );

      // Note: The UI widget (EventListItem) handles this by showing "1m" when minutes == 0
      // This test just verifies the model behavior
    });

    test('duration with same clock time but different dates', () {
      // User scenario: Event spans multiple days but ends at same clock time
      // Start: 8:11 PM Dec 18
      // End: 8:11 PM Dec 19 (same clock time, next day)
      // Expected duration: 24 hours = 1440 minutes

      final startTime = DateTime(2025, 12, 18, 20, 11);
      final endTime = DateTime(2025, 12, 19, 20, 11);

      final record = NosebleedRecord(
        id: 'test-3',
        startTime: startTime,
        endTime: endTime,
        intensity: NosebleedIntensity.dripping,
      );

      expect(
        record.durationMinutes,
        equals(1440),
        reason: '24 hours = 1440 minutes',
      );
    });

    test('real timezone scenario: 6 hour forward travel', () {
      // User travels from EST to CET (forward 6 hours)
      // Starts nosebleed at 8:11 PM EST (local time when in EST)
      // 6 hours later, they're in CET where it's 8:11 AM + 6 = 2:11 AM next day CET
      // Wait, that doesn't work for same clock time...

      // Let's say: User in EST, nosebleed at 8:11 PM EST
      // Then 6 hours pass, now it's 2:11 AM EST = 8:11 AM CET
      // Nosebleed ends at 8:11 AM CET (which is same absolute time as 2:11 AM EST)

      // So if they want to record "8:11 PM EST start, 8:11 AM CET end":
      // Start: 2025-12-18T20:11:00-05:00 (8:11 PM EST) = 2025-12-19T01:11:00Z
      // End: 2025-12-19T08:11:00+01:00 (8:11 AM CET) = 2025-12-19T07:11:00Z
      // Duration: 6 hours = 360 minutes

      final startTime = DateTime.parse('2025-12-18T20:11:00.000-05:00');
      final endTime = DateTime.parse('2025-12-19T08:11:00.000+01:00');

      final record = NosebleedRecord(
        id: 'test-4',
        startTime: startTime,
        endTime: endTime,
        intensity: NosebleedIntensity.dripping,
        startTimeTimezone: 'America/New_York',
        endTimeTimezone: 'Europe/Paris',
      );

      debugPrint('Start UTC: ${startTime.toUtc()}');
      debugPrint('End UTC: ${endTime.toUtc()}');
      debugPrint('Duration: ${record.durationMinutes} minutes');

      expect(
        record.durationMinutes,
        equals(360),
        reason: '6 hours = 360 minutes for forward travel scenario',
      );
    });

    test('BUG: same clock time different timezone shows wrong duration', () {
      // THIS TEST DEMONSTRATES THE BUG
      //
      // When user selects:
      // - Start: 8:11 PM (in EST timezone)
      // - End: 8:11 PM (in CET timezone, changed via timezone picker)
      //
      // The app stores the same DateTime VALUE for both (8:11 PM in device local),
      // just with different timezone METADATA strings.
      //
      // Result: duration calculates as 0 minutes because DateTime objects are equal
      // Expected: Should account for timezone difference (6 hour offset)

      // Simulate what the app actually stores when user picks same clock time
      // but different timezone - the DateTime stays at device local time
      final deviceLocalTime = DateTime(2025, 12, 18, 20, 11); // 8:11 PM local

      final record = NosebleedRecord(
        id: 'test-5',
        startTime: deviceLocalTime,
        endTime: deviceLocalTime, // SAME DateTime, but different TZ metadata
        intensity: NosebleedIntensity.dripping,
        startTimeTimezone: 'America/New_York', // EST
        endTimeTimezone: 'Europe/Paris', // CET
      );

      // BUG: This returns 0 because DateTime objects are identical
      // The timezone metadata (startTimeTimezone, endTimeTimezone) is ignored
      // in the duration calculation
      final duration = record.durationMinutes;
      debugPrint(
        'Duration with same DateTime but different TZ metadata: $duration',
      );

      // Current (buggy) behavior: duration is 0
      // Expected behavior: duration should account for 6 hour timezone difference
      //
      // If user is in EST and sets end time to 8:11 PM CET:
      // - 8:11 PM CET = 2:11 PM EST (same day, 6 hours earlier)
      // - So end is BEFORE start, duration should be null (invalid)
      //
      // OR if the intent is "8:11 PM in the future when I'm in CET timezone":
      // - That would be 8:11 PM CET = 2:11 PM EST (next occurrence)
      // - Need to add a day if end would be before start

      // This test will FAIL because it expects the bug to be fixed
      // Currently returns 0, but should be null (end before start)
      // or should adjust the DateTime based on timezone difference
      expect(
        duration,
        isNot(equals(0)),
        reason:
            'Duration should not be 0 when timezones differ - '
            'either null (invalid) or calculated with TZ adjustment',
      );
    });
  });
}
