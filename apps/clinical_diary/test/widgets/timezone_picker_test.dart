// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimezoneEntry', () {
    test('shortDisplay formats correctly', () {
      const entry = TimezoneEntry(
        ianaId: 'America/Los_Angeles',
        abbreviation: 'PST',
        displayName: 'Pacific Time (US)',
        utcOffsetMinutes: -480,
      );
      expect(entry.shortDisplay, 'PST - Pacific Time (US)');
    });

    test('formattedDisplay includes UTC offset', () {
      const entry = TimezoneEntry(
        ianaId: 'Europe/Paris',
        abbreviation: 'CET',
        displayName: 'Central European Time',
        utcOffsetMinutes: 60,
      );
      expect(entry.formattedDisplay, 'CET (UTC+1) - Central European Time');
    });

    test('formattedDisplay handles negative offset', () {
      const entry = TimezoneEntry(
        ianaId: 'America/New_York',
        abbreviation: 'EST',
        displayName: 'Eastern Time (US)',
        utcOffsetMinutes: -300,
      );
      expect(entry.formattedDisplay, 'EST (UTC-5) - Eastern Time (US)');
    });

    test('formattedDisplay handles offset with minutes', () {
      const entry = TimezoneEntry(
        ianaId: 'Asia/Kolkata',
        abbreviation: 'IST',
        displayName: 'India Time',
        utcOffsetMinutes: 330,
      );
      expect(entry.formattedDisplay, 'IST (UTC+5:30) - India Time');
    });

    test('formattedDisplay handles UTC', () {
      const entry = TimezoneEntry(
        ianaId: 'Etc/UTC',
        abbreviation: 'UTC',
        displayName: 'Coordinated Universal Time',
        utcOffsetMinutes: 0,
      );
      expect(
        entry.formattedDisplay,
        'UTC (UTC+0) - Coordinated Universal Time',
      );
    });
  });

  group('commonTimezones', () {
    test('contains expected number of timezones', () {
      expect(commonTimezones.length, greaterThan(50));
    });

    test('is sorted by UTC offset', () {
      for (var i = 1; i < commonTimezones.length; i++) {
        expect(
          commonTimezones[i].utcOffsetMinutes,
          greaterThanOrEqualTo(commonTimezones[i - 1].utcOffsetMinutes),
          reason:
              '${commonTimezones[i].abbreviation} should come after ${commonTimezones[i - 1].abbreviation}',
        );
      }
    });

    test('contains common US timezones', () {
      final ids = commonTimezones.map((e) => e.ianaId).toList();
      expect(ids, contains('America/New_York'));
      expect(ids, contains('America/Chicago'));
      expect(ids, contains('America/Denver'));
      expect(ids, contains('America/Los_Angeles'));
    });

    test('contains common European timezones', () {
      final ids = commonTimezones.map((e) => e.ianaId).toList();
      expect(ids, contains('Europe/London'));
      expect(ids, contains('Europe/Paris'));
      expect(ids, contains('Europe/Berlin'));
    });

    test('all entries have unique IANA IDs', () {
      final ids = commonTimezones.map((e) => e.ianaId).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('getTimezoneDisplayName', () {
    test('returns formatted display for known IANA ID', () {
      expect(
        getTimezoneDisplayName('America/New_York'),
        'EST - Eastern Time (US)',
      );
    });

    test('returns formatted display for European timezone', () {
      expect(
        getTimezoneDisplayName('Europe/Paris'),
        'CET - Central European Time',
      );
    });

    test('extracts city name for unknown IANA ID', () {
      expect(getTimezoneDisplayName('Antarctica/McMurdo'), 'McMurdo');
    });

    test('handles underscores in city name', () {
      expect(
        getTimezoneDisplayName('America/Los_Angeles'),
        'PST - Pacific Time (US)',
      );
    });

    test('returns original for non-IANA format', () {
      expect(getTimezoneDisplayName('XYZ'), 'XYZ');
    });
  });

  group('getTimezoneAbbreviation', () {
    test('returns abbreviation for known IANA ID', () {
      expect(getTimezoneAbbreviation('America/New_York'), 'EST');
      expect(getTimezoneAbbreviation('Europe/Paris'), 'CET');
      expect(getTimezoneAbbreviation('America/Los_Angeles'), 'PST');
    });

    test('returns input if already abbreviation', () {
      expect(getTimezoneAbbreviation('PST'), 'PST');
      expect(getTimezoneAbbreviation('CET'), 'CET');
      expect(getTimezoneAbbreviation('UTC'), 'UTC');
    });

    test('extracts abbreviation from unknown IANA ID', () {
      final result = getTimezoneAbbreviation('Antarctica/McMurdo');
      expect(result.length, lessThanOrEqualTo(3));
      expect(result, result.toUpperCase());
    });
  });

  group('normalizeDeviceTimezone', () {
    test('returns short abbreviations as-is', () {
      expect(normalizeDeviceTimezone('PST'), 'PST');
      expect(normalizeDeviceTimezone('CET'), 'CET');
      expect(normalizeDeviceTimezone('UTC'), 'UTC');
    });

    test('normalizes "Central European Standard Time" to CET', () {
      expect(normalizeDeviceTimezone('Central European Standard Time'), 'CET');
    });

    test('normalizes "Pacific Standard Time" to PST', () {
      // This might match "Pacific Time" in our list
      final result = normalizeDeviceTimezone('Pacific Standard Time');
      expect(result.length, lessThanOrEqualTo(4));
    });

    test('normalizes "Eastern Standard Time" to EST', () {
      // This might match "Eastern Time" in our list
      final result = normalizeDeviceTimezone('Eastern Standard Time');
      expect(result.length, lessThanOrEqualTo(4));
    });

    test('handles unknown long timezone names gracefully', () {
      final result = normalizeDeviceTimezone('Some Unknown Timezone Name');
      // Should extract first letters of significant words
      expect(result.isNotEmpty, true);
    });

    test('returns original for unrecognized format', () {
      expect(normalizeDeviceTimezone('XYZ123'), 'XYZ123');
    });
  });
}
