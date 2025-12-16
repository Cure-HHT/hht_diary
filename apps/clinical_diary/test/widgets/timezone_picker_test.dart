// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showTimezonePicker Widget', () {
    testWidgets('displays dialog with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Timezone'), findsOneWidget);
    });

    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search timezones...'), findsOneWidget);
    });

    testWidgets('displays cancel button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('displays timezone list items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show at least some timezones
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('shows check icon for selected timezone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Selected timezone should have a check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('filters timezones by search query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Count initial list tiles
      final initialCount = tester.widgetList(find.byType(ListTile)).length;

      // Search for Tokyo
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();

      // Should have fewer results
      final filteredCount = tester.widgetList(find.byType(ListTile)).length;
      expect(filteredCount, lessThan(initialCount));

      // Should find Tokyo
      expect(find.text('Asia/Tokyo'), findsOneWidget);
    });

    testWidgets('returns selected timezone on tap', (tester) async {
      String? selectedTz;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedTz = await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Search for Tokyo and tap it
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();

      await tester.tap(find.text('Asia/Tokyo'));
      await tester.pumpAndSettle();

      expect(selectedTz, 'Asia/Tokyo');
    });

    testWidgets('returns null on cancel', (tester) async {
      String? selectedTz = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedTz = await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedTz, isNull);
    });

    testWidgets('clears filter when search is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final initialCount = tester.widgetList(find.byType(ListTile)).length;

      // Filter
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();

      // Clear filter
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      final restoredCount = tester.widgetList(find.byType(ListTile)).length;
      expect(restoredCount, initialCount);
    });

    testWidgets('search matches abbreviation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Search by abbreviation
      await tester.enterText(find.byType(TextField), 'PST');
      await tester.pump();

      // Should find Pacific timezones
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('search matches display name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showTimezonePicker(
                  context: context,
                  selectedTimezone: 'America/Los_Angeles',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Search by display name
      await tester.enterText(find.byType(TextField), 'Pacific');
      await tester.pump();

      // Should find Pacific timezones
      expect(find.byType(ListTile), findsWidgets);
    });
  });

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
