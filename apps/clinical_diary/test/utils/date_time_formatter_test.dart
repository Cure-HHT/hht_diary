// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateTimeFormatter', () {
    group('format', () {
      test('formats local DateTime to ISO 8601 string', () {
        final dateTime = DateTime(2024, 10, 15, 14, 30, 0, 0);
        final result = DateTimeFormatter.format(dateTime);

        // Should be ISO 8601 format
        expect(result, contains('2024-10-15'));
        expect(result, contains('14:30:00'));
        expect(result, contains('.000')); // milliseconds
        expect(result, contains('T')); // ISO 8601 separator
      });

      test('formats UTC DateTime', () {
        final dateTime = DateTime.utc(2024, 10, 15, 14, 30, 0, 0);
        final result = DateTimeFormatter.format(dateTime);

        expect(result, contains('2024-10-15'));
        expect(result, contains('14:30:00'));
      });

      test('preserves milliseconds', () {
        final dateTime = DateTime(2024, 10, 15, 14, 30, 45, 123);
        final result = DateTimeFormatter.format(dateTime);

        expect(result, contains('.123'));
      });

      test('formats midnight correctly', () {
        final dateTime = DateTime(2024, 1, 1, 0, 0, 0, 0);
        final result = DateTimeFormatter.format(dateTime);

        expect(result, contains('2024-01-01'));
        expect(result, contains('00:00:00'));
      });

      test('formats end of day correctly', () {
        final dateTime = DateTime(2024, 12, 31, 23, 59, 59, 999);
        final result = DateTimeFormatter.format(dateTime);

        expect(result, contains('2024-12-31'));
        expect(result, contains('23:59:59.999'));
      });
    });

    group('parse', () {
      test('parses ISO 8601 string with positive offset', () {
        const dateString = '2024-10-15T14:30:00.000+05:30';
        final result = DateTimeFormatter.parse(dateString);

        // Should parse to the same moment in time (converted to local)
        expect(result.year, 2024);
        expect(result.month, 10);
        expect(result.day, 15);
      });

      test('parses ISO 8601 string with negative offset', () {
        const dateString = '2024-10-15T14:30:00.000-05:00';
        final result = DateTimeFormatter.parse(dateString);

        expect(result.year, 2024);
        expect(result.month, 10);
      });

      test('parses ISO 8601 string with Z (UTC) suffix', () {
        const dateString = '2024-10-15T14:30:00.000Z';
        final result = DateTimeFormatter.parse(dateString);

        // Should be converted to local time
        expect(result.isUtc, false);
      });

      test('parses ISO 8601 string without offset (assumes local)', () {
        const dateString = '2024-10-15T14:30:00.000';
        final result = DateTimeFormatter.parse(dateString);

        expect(result.hour, 14);
        expect(result.minute, 30);
      });

      test('parses and preserves milliseconds', () {
        const dateString = '2024-10-15T14:30:45.123Z';
        final result = DateTimeFormatter.parse(dateString);

        expect(result.millisecond, 123);
      });

      test('throws FormatException for invalid string', () {
        expect(
          () => DateTimeFormatter.parse('not-a-date'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for empty string', () {
        expect(
          () => DateTimeFormatter.parse(''),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('tryParse', () {
      test('returns DateTime for valid string', () {
        const dateString = '2024-10-15T14:30:00.000-05:00';
        final result = DateTimeFormatter.tryParse(dateString);

        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 10);
        expect(result.day, 15);
      });

      test('returns null for null input', () {
        final result = DateTimeFormatter.tryParse(null);
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = DateTimeFormatter.tryParse('');
        expect(result, isNull);
      });

      test('returns null for invalid string', () {
        final result = DateTimeFormatter.tryParse('not-a-date');
        expect(result, isNull);
      });

      test('returns null for partial date string', () {
        final result = DateTimeFormatter.tryParse('2024-10');
        expect(result, isNull);
      });
    });

    group('extractTimezoneOffset', () {
      test('extracts negative offset with colon', () {
        const dateString = '2024-10-15T14:30:00.000-05:00';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, '-05:00');
      });

      test('extracts positive offset with colon', () {
        const dateString = '2024-10-15T14:30:00.000+05:30';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, '+05:30');
      });

      test('extracts Z for UTC', () {
        const dateString = '2024-10-15T14:30:00.000Z';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, 'Z');
      });

      test('extracts +00:00 offset', () {
        const dateString = '2024-10-15T14:30:00.000+00:00';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, '+00:00');
      });

      test('extracts offset without colon', () {
        const dateString = '2024-10-15T14:30:00.000-0500';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, '-0500');
      });

      test('returns null for string without offset', () {
        const dateString = '2024-10-15T14:30:00.000';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, isNull);
      });

      test('returns null for date-only string', () {
        const dateString = '2024-10-15';
        final result = DateTimeFormatter.extractTimezoneOffset(dateString);

        expect(result, isNull);
      });
    });

    group('getTimezoneAbbreviation', () {
      test('returns String for local DateTime', () {
        final dateTime = DateTime(2024, 7, 15, 12, 0); // Summer date
        final result = DateTimeFormatter.getTimezoneAbbreviation(dateTime);

        // Returns String - may be empty in test environment without timezone data
        expect(result, isA<String>());
      });

      test('returns String for UTC DateTime', () {
        final dateTime = DateTime.utc(2024, 7, 15, 12, 0);
        final result = DateTimeFormatter.getTimezoneAbbreviation(dateTime);

        expect(result, isA<String>());
      });

      test('returns String for winter date', () {
        final dateTime = DateTime(2024, 1, 15, 12, 0); // Winter date
        final result = DateTimeFormatter.getTimezoneAbbreviation(dateTime);

        expect(result, isA<String>());
      });
    });

    group('getTimezoneName', () {
      test('returns String for local DateTime', () {
        final dateTime = DateTime(2024, 7, 15, 12, 0);
        final result = DateTimeFormatter.getTimezoneName(dateTime);

        // Returns String - may be empty in test environment without timezone data
        expect(result, isA<String>());
      });

      test('returns String for UTC DateTime', () {
        final dateTime = DateTime.utc(2024, 7, 15, 12, 0);
        final result = DateTimeFormatter.getTimezoneName(dateTime);

        expect(result, isA<String>());
      });
    });

    group('roundtrip', () {
      test('format then parse preserves moment in time', () {
        final original = DateTime(2024, 10, 15, 14, 30, 45, 123);
        final formatted = DateTimeFormatter.format(original);
        final parsed = DateTimeFormatter.parse(formatted);

        // Should represent the same moment in time
        expect(parsed.millisecondsSinceEpoch, original.millisecondsSinceEpoch);
      });

      test('format then parse preserves date components', () {
        final original = DateTime(2024, 10, 15, 14, 30, 45, 123);
        final formatted = DateTimeFormatter.format(original);
        final parsed = DateTimeFormatter.parse(formatted);

        expect(parsed.year, original.year);
        expect(parsed.month, original.month);
        expect(parsed.day, original.day);
        expect(parsed.hour, original.hour);
        expect(parsed.minute, original.minute);
        expect(parsed.second, original.second);
        expect(parsed.millisecond, original.millisecond);
      });

      test('format then parse works for midnight', () {
        final original = DateTime(2024, 1, 1, 0, 0, 0, 0);
        final formatted = DateTimeFormatter.format(original);
        final parsed = DateTimeFormatter.parse(formatted);

        expect(parsed.millisecondsSinceEpoch, original.millisecondsSinceEpoch);
      });

      test('format then parse works for end of year', () {
        final original = DateTime(2024, 12, 31, 23, 59, 59, 999);
        final formatted = DateTimeFormatter.format(original);
        final parsed = DateTimeFormatter.parse(formatted);

        expect(parsed.millisecondsSinceEpoch, original.millisecondsSinceEpoch);
      });
    });
  });
}
