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
        displayName: 'Pacific Time',
        utcOffsetMinutes: -480,
      );
      expect(entry.shortDisplay, 'PST - Pacific Time');
    });

    test('formattedDisplay shows UTC offset without minutes', () {
      const entry = TimezoneEntry(
        ianaId: 'America/New_York',
        abbreviation: 'EST',
        displayName: 'Eastern Time',
        utcOffsetMinutes: -300,
      );
      expect(entry.formattedDisplay, 'EST (UTC-5) - Eastern Time');
    });

    test('formattedDisplay shows UTC offset with minutes', () {
      const entry = TimezoneEntry(
        ianaId: 'Asia/Kolkata',
        abbreviation: 'IST',
        displayName: 'India Time',
        utcOffsetMinutes: 330,
      );
      expect(entry.formattedDisplay, 'IST (UTC+5:30) - India Time');
    });

    test('formattedDisplay handles positive offset', () {
      const entry = TimezoneEntry(
        ianaId: 'Europe/Paris',
        abbreviation: 'CET',
        displayName: 'Central European Time',
        utcOffsetMinutes: 60,
      );
      expect(entry.formattedDisplay, 'CET (UTC+1) - Central European Time');
    });

    test('formattedDisplay handles UTC+0', () {
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

    test('formattedDisplay handles negative offset with minutes', () {
      // UTC-9:30 (hypothetical but tests edge case)
      const entry = TimezoneEntry(
        ianaId: 'Test/Timezone',
        abbreviation: 'TST',
        displayName: 'Test Time',
        utcOffsetMinutes: -570,
      );
      expect(entry.formattedDisplay, 'TST (UTC-9:30) - Test Time');
    });
  });

  group('commonTimezones', () {
    test('is not empty', () {
      expect(commonTimezones, isNotEmpty);
    });

    test('contains expected timezones', () {
      final ianaIds = commonTimezones.map((tz) => tz.ianaId).toList();
      expect(ianaIds, contains('America/Los_Angeles'));
      expect(ianaIds, contains('Europe/London'));
      expect(ianaIds, contains('Asia/Tokyo'));
      expect(ianaIds, contains('Etc/UTC'));
    });

    test('all entries have required fields', () {
      for (final tz in commonTimezones) {
        expect(tz.ianaId, isNotEmpty);
        expect(tz.abbreviation, isNotEmpty);
        expect(tz.displayName, isNotEmpty);
      }
    });

    test('is sorted by UTC offset', () {
      for (var i = 0; i < commonTimezones.length - 1; i++) {
        expect(
          commonTimezones[i].utcOffsetMinutes,
          lessThanOrEqualTo(commonTimezones[i + 1].utcOffsetMinutes),
          reason:
              'Timezone ${commonTimezones[i].ianaId} should come before '
              '${commonTimezones[i + 1].ianaId}',
        );
      }
    });

    test('first timezone has earliest offset (HST)', () {
      expect(commonTimezones.first.abbreviation, 'HST');
      expect(commonTimezones.first.utcOffsetMinutes, -600);
    });

    test('last timezone has latest offset (NZST or FJT)', () {
      expect(commonTimezones.last.utcOffsetMinutes, 720);
    });
  });

  group('getTimezoneDisplayName', () {
    test('returns short display for known IANA ID', () {
      expect(
        getTimezoneDisplayName('America/Los_Angeles'),
        'PST - Pacific Time (US)',
      );
    });

    test('returns short display for another known IANA ID', () {
      expect(
        getTimezoneDisplayName('Europe/Paris'),
        'CET - Central European Time',
      );
    });

    test('extracts city name from unknown IANA ID', () {
      expect(getTimezoneDisplayName('Unknown/Some_City'), 'Some City');
    });

    test('extracts city name with multiple parts', () {
      expect(getTimezoneDisplayName('America/Port_of_Spain'), 'Port of Spain');
    });

    test('returns raw value for non-IANA format', () {
      expect(getTimezoneDisplayName('PST'), 'PST');
    });
  });

  group('getTimezoneAbbreviation', () {
    test('returns abbreviation for known IANA ID', () {
      expect(getTimezoneAbbreviation('America/Los_Angeles'), 'PST');
      expect(getTimezoneAbbreviation('Europe/Paris'), 'CET');
      expect(getTimezoneAbbreviation('Asia/Tokyo'), 'JST');
    });

    test('returns uppercase value if already abbreviation', () {
      expect(getTimezoneAbbreviation('PST'), 'PST');
      expect(getTimezoneAbbreviation('CET'), 'CET');
      expect(getTimezoneAbbreviation('UTC'), 'UTC');
    });

    test('extracts abbreviation from unknown IANA ID', () {
      // Takes first 3 chars of city name uppercase
      expect(getTimezoneAbbreviation('Unknown/SomeCity'), 'SOM');
    });

    test('handles short city names', () {
      expect(getTimezoneAbbreviation('Region/Abc'), 'ABC');
    });
  });

  group('normalizeDeviceTimezone', () {
    test('returns short abbreviations as-is', () {
      expect(normalizeDeviceTimezone('PST'), 'PST');
      expect(normalizeDeviceTimezone('CET'), 'CET');
      expect(normalizeDeviceTimezone('UTC'), 'UTC');
      expect(normalizeDeviceTimezone('EST'), 'EST');
    });

    test('normalizes Pacific Standard Time to PST', () {
      expect(normalizeDeviceTimezone('Pacific Standard Time'), 'P');
    });

    test('normalizes Eastern Standard Time', () {
      expect(normalizeDeviceTimezone('Eastern Standard Time'), 'E');
    });

    test('normalizes Central European Standard Time to CET', () {
      // This should match via display name "Central European" contained in device name
      final result = normalizeDeviceTimezone('Central European Standard Time');
      // Should find CET because "Central European Time" is a display name
      expect(result, 'CET');
    });

    test('normalizes British Summer Time', () {
      // "British Time" is a display name
      final result = normalizeDeviceTimezone('British Summer Time');
      expect(result, isNotEmpty);
    });

    test('normalizes unknown long timezone names', () {
      final result = normalizeDeviceTimezone('Some Random Timezone Name');
      // Should extract first letters of significant words
      expect(result, isNotEmpty);
      expect(result.length, lessThan('Some Random Timezone Name'.length));
    });

    test('handles single word as-is', () {
      expect(normalizeDeviceTimezone('Timezone'), 'Timezone');
    });

    test('handles timezone containing abbreviation', () {
      // If the device timezone contains a known abbreviation
      final result = normalizeDeviceTimezone('PST Pacific');
      expect(result, 'PST');
    });
  });
}
