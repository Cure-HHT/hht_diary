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

    // CUR-543: Expanded timezone search tests
    group('timezone search filtering', () {
      Future<void> openPicker(WidgetTester tester) async {
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
      }

      testWidgets('search for "Tokyo" finds Asia/Tokyo', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Tokyo');
        await tester.pump();
        expect(find.text('Asia/Tokyo'), findsOneWidget);
      });

      testWidgets('search for "Eastern" finds America/New_York', (
        tester,
      ) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Eastern');
        await tester.pump();
        expect(find.text('America/New_York'), findsOneWidget);
      });

      testWidgets('search for "EST" finds America/New_York', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'EST');
        await tester.pump();
        expect(find.text('America/New_York'), findsOneWidget);
      });

      testWidgets('search for "Pacific" finds America/Los_Angeles', (
        tester,
      ) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Pacific');
        await tester.pump();
        expect(find.text('America/Los_Angeles'), findsOneWidget);
      });

      testWidgets('search for "PST" finds America/Los_Angeles', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'PST');
        await tester.pump();
        expect(find.text('America/Los_Angeles'), findsOneWidget);
      });

      testWidgets('search for "Central" finds America/Chicago', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Central');
        await tester.pump();
        expect(find.text('America/Chicago'), findsOneWidget);
      });

      testWidgets('search for "Mountain" finds America/Denver', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Mountain');
        await tester.pump();
        expect(find.text('America/Denver'), findsOneWidget);
      });

      testWidgets('search for "Paris" finds Europe/Paris', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.pump();
        expect(find.text('Europe/Paris'), findsOneWidget);
      });

      testWidgets('search for "CET" finds Europe/Paris', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'CET');
        await tester.pump();
        expect(find.text('Europe/Paris'), findsOneWidget);
      });

      testWidgets('search for "London" finds Europe/London', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'London');
        await tester.pump();
        expect(find.text('Europe/London'), findsOneWidget);
      });

      testWidgets('search for "GMT" finds Europe/London', (tester) async {
        await openPicker(tester);
        await tester.enterText(find.byType(TextField), 'GMT');
        await tester.pump();
        expect(find.text('Europe/London'), findsOneWidget);
      });

      testWidgets('search reduces result count', (tester) async {
        await openPicker(tester);
        final initialCount = tester.widgetList(find.byType(ListTile)).length;

        await tester.enterText(find.byType(TextField), 'Tokyo');
        await tester.pump();

        final filteredCount = tester.widgetList(find.byType(ListTile)).length;
        expect(filteredCount, lessThan(initialCount));
      });
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

  // CUR-543: Thorough tests for normalizeDeviceTimezone
  // This function MUST return the same abbreviation that getTimezoneAbbreviation
  // would return for the corresponding IANA timezone. Otherwise, timezone
  // comparison fails and TZ is incorrectly shown in the UI.
  group('normalizeDeviceTimezone', () {
    group('short abbreviations (already normalized)', () {
      test('returns PST as-is', () {
        expect(normalizeDeviceTimezone('PST'), 'PST');
      });

      test('returns EST as-is', () {
        expect(normalizeDeviceTimezone('EST'), 'EST');
      });

      test('returns CET as-is', () {
        expect(normalizeDeviceTimezone('CET'), 'CET');
      });

      test('returns UTC as-is', () {
        expect(normalizeDeviceTimezone('UTC'), 'UTC');
      });

      test('returns GMT as-is', () {
        expect(normalizeDeviceTimezone('GMT'), 'GMT');
      });

      test('returns MST as-is', () {
        expect(normalizeDeviceTimezone('MST'), 'MST');
      });

      test('returns CST as-is', () {
        expect(normalizeDeviceTimezone('CST'), 'CST');
      });
    });

    // CUR-543: US timezone long names (Windows/macOS format)
    // These MUST match getTimezoneAbbreviation for corresponding IANA zones
    group('US timezone long names', () {
      test('Eastern Standard Time → EST (matches America/New_York)', () {
        // getTimezoneAbbreviation('America/New_York') returns 'EST'
        // So normalizeDeviceTimezone MUST also return 'EST'
        expect(normalizeDeviceTimezone('Eastern Standard Time'), 'EST');
      });

      test('Eastern Daylight Time → EDT', () {
        expect(normalizeDeviceTimezone('Eastern Daylight Time'), 'EDT');
      });

      test('Pacific Standard Time → PST (matches America/Los_Angeles)', () {
        // getTimezoneAbbreviation('America/Los_Angeles') returns 'PST'
        expect(normalizeDeviceTimezone('Pacific Standard Time'), 'PST');
      });

      test('Pacific Daylight Time → PDT', () {
        expect(normalizeDeviceTimezone('Pacific Daylight Time'), 'PDT');
      });

      test('Central Standard Time → CST (matches America/Chicago)', () {
        expect(normalizeDeviceTimezone('Central Standard Time'), 'CST');
      });

      test('Central Daylight Time → CDT', () {
        expect(normalizeDeviceTimezone('Central Daylight Time'), 'CDT');
      });

      test('Mountain Standard Time → MST (matches America/Denver)', () {
        expect(normalizeDeviceTimezone('Mountain Standard Time'), 'MST');
      });

      test('Mountain Daylight Time → MDT', () {
        expect(normalizeDeviceTimezone('Mountain Daylight Time'), 'MDT');
      });
    });

    // CUR-543: European timezone long names
    group('European timezone long names', () {
      test('Central European Standard Time → CET (matches Europe/Paris)', () {
        // getTimezoneAbbreviation('Europe/Paris') returns 'CET'
        expect(
          normalizeDeviceTimezone('Central European Standard Time'),
          'CET',
        );
      });

      test('Central European Summer Time → CEST', () {
        expect(normalizeDeviceTimezone('Central European Summer Time'), 'CEST');
      });

      test('Greenwich Mean Time → GMT (matches Europe/London)', () {
        expect(normalizeDeviceTimezone('Greenwich Mean Time'), 'GMT');
      });

      test('British Summer Time → BST', () {
        expect(normalizeDeviceTimezone('British Summer Time'), 'BST');
      });

      test('Western European Time → WET', () {
        expect(normalizeDeviceTimezone('Western European Time'), 'WET');
      });

      test('Western European Summer Time → WEST', () {
        expect(normalizeDeviceTimezone('Western European Summer Time'), 'WEST');
      });

      test('Eastern European Time → EET', () {
        expect(normalizeDeviceTimezone('Eastern European Time'), 'EET');
      });

      test('Eastern European Summer Time → EEST', () {
        expect(normalizeDeviceTimezone('Eastern European Summer Time'), 'EEST');
      });
    });

    // CUR-543: Other common timezone long names
    group('other timezone long names', () {
      test('Japan Standard Time → JST (matches Asia/Tokyo)', () {
        expect(normalizeDeviceTimezone('Japan Standard Time'), 'JST');
      });

      test('Australian Eastern Standard Time → AEST', () {
        expect(
          normalizeDeviceTimezone('Australian Eastern Standard Time'),
          'AEST',
        );
      });

      test('Australian Eastern Daylight Time → AEDT', () {
        expect(
          normalizeDeviceTimezone('Australian Eastern Daylight Time'),
          'AEDT',
        );
      });

      test('India Standard Time → IST (matches Asia/Kolkata)', () {
        expect(normalizeDeviceTimezone('India Standard Time'), 'IST');
      });

      test('China Standard Time → CST (matches Asia/Shanghai)', () {
        // Note: CST is ambiguous (Central/China), but should work
        expect(normalizeDeviceTimezone('China Standard Time'), 'CST');
      });

      test('Coordinated Universal Time → UTC', () {
        expect(normalizeDeviceTimezone('Coordinated Universal Time'), 'UTC');
      });
    });

    // CUR-543: Edge cases
    group('edge cases', () {
      test('handles single word timezone', () {
        expect(normalizeDeviceTimezone('Timezone'), 'Timezone');
      });

      test('handles timezone with embedded abbreviation', () {
        expect(normalizeDeviceTimezone('PST Pacific'), 'PST');
      });

      test('handles unknown timezone gracefully', () {
        final result = normalizeDeviceTimezone('Some Unknown Timezone');
        expect(result, isNotEmpty);
      });

      test('handles empty string', () {
        expect(normalizeDeviceTimezone(''), '');
      });
    });

    // CUR-543: Cross-check with getTimezoneAbbreviation
    // The key requirement: when device TZ and event TZ are the same timezone,
    // normalizeDeviceTimezone(deviceTzName) MUST equal getTimezoneAbbreviation(ianaId)
    group('must match getTimezoneAbbreviation for same timezone', () {
      test(
        'Eastern timezone: device "Eastern Standard Time" matches event "America/New_York"',
        () {
          final deviceResult = normalizeDeviceTimezone('Eastern Standard Time');
          final eventResult = getTimezoneAbbreviation('America/New_York');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for Eastern timezone',
          );
        },
      );

      test(
        'Pacific timezone: device "Pacific Standard Time" matches event "America/Los_Angeles"',
        () {
          final deviceResult = normalizeDeviceTimezone('Pacific Standard Time');
          final eventResult = getTimezoneAbbreviation('America/Los_Angeles');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for Pacific timezone',
          );
        },
      );

      test(
        'Central European: device "Central European Standard Time" matches event "Europe/Paris"',
        () {
          final deviceResult = normalizeDeviceTimezone(
            'Central European Standard Time',
          );
          final eventResult = getTimezoneAbbreviation('Europe/Paris');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for CET timezone',
          );
        },
      );

      test(
        'Central US: device "Central Standard Time" matches event "America/Chicago"',
        () {
          final deviceResult = normalizeDeviceTimezone('Central Standard Time');
          final eventResult = getTimezoneAbbreviation('America/Chicago');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for Central timezone',
          );
        },
      );

      test(
        'Mountain: device "Mountain Standard Time" matches event "America/Denver"',
        () {
          final deviceResult = normalizeDeviceTimezone(
            'Mountain Standard Time',
          );
          final eventResult = getTimezoneAbbreviation('America/Denver');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for Mountain timezone',
          );
        },
      );

      test(
        'GMT: device "Greenwich Mean Time" matches event "Europe/London"',
        () {
          final deviceResult = normalizeDeviceTimezone('Greenwich Mean Time');
          final eventResult = getTimezoneAbbreviation('Europe/London');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for GMT timezone',
          );
        },
      );

      test(
        'Japan: device "Japan Standard Time" matches event "Asia/Tokyo"',
        () {
          final deviceResult = normalizeDeviceTimezone('Japan Standard Time');
          final eventResult = getTimezoneAbbreviation('Asia/Tokyo');
          expect(
            deviceResult,
            eventResult,
            reason: 'Device and event TZ should match for JST timezone',
          );
        },
      );
    });
  });
}
