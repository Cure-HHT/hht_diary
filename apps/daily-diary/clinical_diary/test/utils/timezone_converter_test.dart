// CUR-583: Unit tests for timezone conversion utilities
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimezoneConverter', () {
    // Use fixed device offset for deterministic tests
    // Simulating device in EST (UTC-5 = -300 minutes)
    const deviceOffsetEST = -300;

    group('getTimezoneOffsetMinutes', () {
      test('returns correct offset for known timezones', () {
        expect(
          TimezoneConverter.getTimezoneOffsetMinutes('America/New_York'),
          equals(-300), // EST = UTC-5
        );
        expect(
          TimezoneConverter.getTimezoneOffsetMinutes('Europe/Paris'),
          equals(60), // CET = UTC+1
        );
        expect(
          TimezoneConverter.getTimezoneOffsetMinutes('Asia/Tokyo'),
          equals(540), // JST = UTC+9
        );
        expect(
          TimezoneConverter.getTimezoneOffsetMinutes('Etc/UTC'),
          equals(0),
        );
      });

      test('returns null for unknown timezone', () {
        expect(
          TimezoneConverter.getTimezoneOffsetMinutes('Unknown/Timezone'),
          isNull,
        );
      });

      test('returns null for null timezone', () {
        expect(TimezoneConverter.getTimezoneOffsetMinutes(null), isNull);
      });
    });

    group('toStoredDateTime', () {
      test('same timezone as device returns unchanged DateTime', () {
        final displayed = DateTime(2025, 12, 18, 20, 11); // 8:11 PM

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          'America/New_York', // EST, same as device
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // No adjustment needed when timezone matches device
        expect(stored, equals(displayed));
      });

      test('CET timezone on EST device adjusts correctly', () {
        // User sees 8:11 PM CET on Dec 18
        final displayed = DateTime(2025, 12, 18, 20, 11);

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          'Europe/Paris', // CET = UTC+1
          deviceOffsetMinutes: deviceOffsetEST, // Device is EST = UTC-5
        );

        // Adjustment: -300 - 60 = -360 minutes = -6 hours
        // 8:11 PM - 6 hours = 2:11 PM
        expect(stored, equals(DateTime(2025, 12, 18, 14, 11)));
      });

      test('handles date change when adjustment crosses midnight', () {
        // User sees 2:00 AM CET on Dec 18
        final displayed = DateTime(2025, 12, 18, 2, 0);

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          'Europe/Paris', // CET
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // 2:00 AM - 6 hours = 8:00 PM previous day
        expect(stored, equals(DateTime(2025, 12, 17, 20, 0)));
      });

      test('null timezone returns unchanged DateTime', () {
        final displayed = DateTime(2025, 12, 18, 20, 11);

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          null,
          deviceOffsetMinutes: deviceOffsetEST,
        );

        expect(stored, equals(displayed));
      });

      test('unknown timezone returns unchanged DateTime', () {
        final displayed = DateTime(2025, 12, 18, 20, 11);

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          'Unknown/Timezone',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        expect(stored, equals(displayed));
      });

      test('Tokyo timezone on EST device adjusts correctly', () {
        // User sees 8:11 PM JST on Dec 18
        final displayed = DateTime(2025, 12, 18, 20, 11);

        final stored = TimezoneConverter.toStoredDateTime(
          displayed,
          'Asia/Tokyo', // JST = UTC+9
          deviceOffsetMinutes: deviceOffsetEST, // Device is EST = UTC-5
        );

        // Adjustment: -300 - 540 = -840 minutes = -14 hours
        // 8:11 PM - 14 hours = 6:11 AM same day
        expect(stored, equals(DateTime(2025, 12, 18, 6, 11)));
      });
    });

    group('toDisplayedDateTime', () {
      test('same timezone as device returns unchanged DateTime', () {
        final stored = DateTime(2025, 12, 18, 20, 11);

        final displayed = TimezoneConverter.toDisplayedDateTime(
          stored,
          'America/New_York',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        expect(displayed, equals(stored));
      });

      test('correctly reverses CET to EST conversion', () {
        // Stored: 2:11 PM (which represents 8:11 PM CET)
        final stored = DateTime(2025, 12, 18, 14, 11);

        final displayed = TimezoneConverter.toDisplayedDateTime(
          stored,
          'Europe/Paris',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Should show 8:11 PM
        expect(displayed, equals(DateTime(2025, 12, 18, 20, 11)));
      });

      test('handles date change when reversing adjustment', () {
        // Stored: 8:00 PM Dec 17 (which represents 2:00 AM CET Dec 18)
        final stored = DateTime(2025, 12, 17, 20, 0);

        final displayed = TimezoneConverter.toDisplayedDateTime(
          stored,
          'Europe/Paris',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Should show 2:00 AM Dec 18
        expect(displayed, equals(DateTime(2025, 12, 18, 2, 0)));
      });

      test('roundtrip: toStored then toDisplayed returns original', () {
        final original = DateTime(2025, 12, 18, 20, 11);
        const timezone = 'Europe/Paris';

        final stored = TimezoneConverter.toStoredDateTime(
          original,
          timezone,
          deviceOffsetMinutes: deviceOffsetEST,
        );

        final displayed = TimezoneConverter.toDisplayedDateTime(
          stored,
          timezone,
          deviceOffsetMinutes: deviceOffsetEST,
        );

        expect(displayed, equals(original));
      });
    });

    group('recalculateForTimezoneChange', () {
      test('changing from EST to CET adjusts DateTime correctly', () {
        // Start: 8:11 PM displayed as EST, stored as 8:11 PM (no adjustment)
        final storedEST = DateTime(2025, 12, 18, 20, 11);

        final storedCET = TimezoneConverter.recalculateForTimezoneChange(
          storedEST,
          'America/New_York', // old: EST
          'Europe/Paris', // new: CET
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Same displayed time (8:11 PM) but now in CET
        // Should be stored as 2:11 PM
        expect(storedCET, equals(DateTime(2025, 12, 18, 14, 11)));

        // Verify: displayed time should still be 8:11 PM
        final displayedCET = TimezoneConverter.toDisplayedDateTime(
          storedCET,
          'Europe/Paris',
          deviceOffsetMinutes: deviceOffsetEST,
        );
        expect(displayedCET, equals(DateTime(2025, 12, 18, 20, 11)));
      });

      test('changing from CET to EST adjusts DateTime correctly', () {
        // Start: 8:11 PM displayed as CET, stored as 2:11 PM
        final storedCET = DateTime(2025, 12, 18, 14, 11);

        final storedEST = TimezoneConverter.recalculateForTimezoneChange(
          storedCET,
          'Europe/Paris', // old: CET
          'America/New_York', // new: EST
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Same displayed time (8:11 PM) but now in EST
        // Should be stored as 8:11 PM (same as device)
        expect(storedEST, equals(DateTime(2025, 12, 18, 20, 11)));
      });

      test('changing from null timezone stores correctly', () {
        // Start: no timezone set, stored as device local
        final storedLocal = DateTime(2025, 12, 18, 20, 11);

        final storedCET = TimezoneConverter.recalculateForTimezoneChange(
          storedLocal,
          null, // old: no timezone
          'Europe/Paris', // new: CET
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // 8:11 PM now in CET should be stored as 2:11 PM
        expect(storedCET, equals(DateTime(2025, 12, 18, 14, 11)));
      });

      test('handles date boundary when changing timezone', () {
        // Start: 2:00 AM displayed as EST, stored as 2:00 AM
        final storedEST = DateTime(2025, 12, 18, 2, 0);

        final storedCET = TimezoneConverter.recalculateForTimezoneChange(
          storedEST,
          'America/New_York', // old: EST
          'Europe/Paris', // new: CET
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // 2:00 AM CET = 8:00 PM previous day in device local
        expect(storedCET, equals(DateTime(2025, 12, 17, 20, 0)));
      });
    });

    group('CUR-583 bug scenario', () {
      test('same clock time different timezones have different stored values', () {
        // This is the original bug: 8:11 PM EST and 8:11 PM CET showed 0m duration
        // because both were stored as the same DateTime value.

        final clockTime = DateTime(2025, 12, 18, 20, 11); // 8:11 PM

        // Store 8:11 PM EST
        final storedEST = TimezoneConverter.toStoredDateTime(
          clockTime,
          'America/New_York',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Store 8:11 PM CET
        final storedCET = TimezoneConverter.toStoredDateTime(
          clockTime,
          'Europe/Paris',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // They should be DIFFERENT (6 hours apart)
        expect(storedEST, isNot(equals(storedCET)));

        // EST is stored as 8:11 PM (device local)
        expect(storedEST, equals(DateTime(2025, 12, 18, 20, 11)));

        // CET is stored as 2:11 PM (6 hours earlier)
        expect(storedCET, equals(DateTime(2025, 12, 18, 14, 11)));

        // Duration between them: 8:11 PM - 2:11 PM = 6 hours = 360 minutes
        // But since CET (2:11 PM) is before EST (8:11 PM), if CET is end time,
        // duration would be negative (invalid)
        final durationMinutes = storedEST.difference(storedCET).inMinutes;
        expect(durationMinutes, equals(360));
      });

      test('travel scenario: EST start to CET end shows correct duration', () {
        // User starts nosebleed at 8:11 PM EST
        // Travels to Europe, ends at 8:11 AM CET next morning (6+ hours later)

        final startClock = DateTime(2025, 12, 18, 20, 11); // 8:11 PM
        final endClock = DateTime(2025, 12, 19, 8, 11); // 8:11 AM next day

        final storedStart = TimezoneConverter.toStoredDateTime(
          startClock,
          'America/New_York',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        final storedEnd = TimezoneConverter.toStoredDateTime(
          endClock,
          'Europe/Paris',
          deviceOffsetMinutes: deviceOffsetEST,
        );

        // Start: Dec 18, 8:11 PM EST = Dec 18, 8:11 PM device
        // End: Dec 19, 8:11 AM CET = Dec 19, 2:11 AM device

        // Duration should be positive (end is after start)
        final durationMinutes = storedEnd.difference(storedStart).inMinutes;
        expect(durationMinutes, greaterThan(0));

        // 8:11 PM to 2:11 AM next day = 6 hours = 360 minutes
        expect(durationMinutes, equals(360));
      });
    });
  });
}
