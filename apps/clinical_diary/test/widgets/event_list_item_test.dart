// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('EventListItem', () {
    final testDate = DateTime(2024, 1, 15);

    testWidgets('displays time range when both start and end time provided', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.textContaining('10:30 AM'), findsOneWidget);
      expect(find.textContaining('10:45 AM'), findsOneWidget);
    });

    testWidgets('displays only start time when end time is missing', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 14, 0),
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('2:00 PM'), findsOneWidget);
    });

    testWidgets('displays -- when no times provided', (tester) async {
      final record = NosebleedRecord(id: 'test-1', date: testDate);

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('displays intensity name', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        intensity: NosebleedIntensity.steadyStream,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('Steady stream'), findsOneWidget);
    });

    testWidgets('does not display intensity when null', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      for (final intensity in NosebleedIntensity.values) {
        expect(find.text(intensity.displayName), findsNothing);
      }
    });

    testWidgets('displays duration in minutes', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45), // 15 minutes
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('15m'), findsOneWidget);
    });

    testWidgets('displays duration in hours and minutes', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 11, 30), // 1 hour 30 minutes
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('displays duration in hours only when no remaining minutes', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 12, 0), // 2 hours exactly
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets('shows Incomplete badge for incomplete records', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        isIncomplete: true,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show Incomplete badge for complete records', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        intensity: NosebleedIntensity.dripping,
        isIncomplete: false,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.text('Incomplete'), findsNothing);
    });

    testWidgets('shows chevron icon when onTap is provided', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(EventListItem(record: record, onTap: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('does not show chevron icon when onTap is null', (
      tester,
    ) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        wrapWithScaffold(
          EventListItem(record: record, onTap: () => tapped = true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EventListItem));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('renders as a Card', (tester) async {
      final record = NosebleedRecord(id: 'test-1', date: testDate);

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays intensity indicator bar', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        intensity: NosebleedIntensity.dripping,
      );

      await tester.pumpWidget(wrapWithScaffold(EventListItem(record: record)));
      await tester.pumpAndSettle();

      // Find the container that serves as the intensity indicator
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasIndicator = containers.any((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return container.constraints?.maxWidth == 4;
        }
        return false;
      });

      expect(hasIndicator, true);
    });

    group('No Nosebleeds event card', () {
      testWidgets('displays green checkmark icon', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isNoNosebleedsEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('displays "No nosebleeds" title', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isNoNosebleedsEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('No nosebleeds'), findsOneWidget);
      });

      testWidgets('displays confirmation subtitle', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isNoNosebleedsEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirmed no events for this day'), findsOneWidget);
      });

      testWidgets('has green background', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isNoNosebleedsEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, Colors.green.shade50);
      });
    });

    group('Multi-day event indicator', () {
      testWidgets('shows (+1 day) when event crosses midnight', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2024, 1, 15, 23, 30), // 11:30 PM
          endTime: DateTime(2024, 1, 16, 0, 15), // 12:15 AM next day
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('(+1 day)'), findsOneWidget);
      });

      testWidgets('does not show (+1 day) for same-day events', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2024, 1, 15, 10, 30),
          endTime: DateTime(2024, 1, 15, 10, 45),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('(+1 day)'), findsNothing);
      });

      testWidgets('does not show (+1 day) when end time is missing', (
        tester,
      ) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2024, 1, 15, 23, 30),
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('(+1 day)'), findsNothing);
      });

      testWidgets('shows correct duration for multi-day events', (
        tester,
      ) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          startTime: DateTime(2024, 1, 15, 23, 30), // 11:30 PM
          endTime: DateTime(2024, 1, 16, 0, 15), // 12:15 AM next day = 45 min
          intensity: NosebleedIntensity.dripping,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('45m'), findsOneWidget);
      });
    });

    group('Unknown event card', () {
      testWidgets('displays yellow question mark icon', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isUnknownEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.help_outline), findsOneWidget);
      });

      testWidgets('displays "Unknown" title', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isUnknownEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unknown'), findsOneWidget);
      });

      testWidgets('displays unable to recall subtitle', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isUnknownEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to recall events for this day'),
          findsOneWidget,
        );
      });

      testWidgets('has yellow background', (tester) async {
        final record = NosebleedRecord(
          id: 'test-1',
          date: testDate,
          isUnknownEvent: true,
        );

        await tester.pumpWidget(
          wrapWithScaffold(EventListItem(record: record)),
        );
        await tester.pumpAndSettle();

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, Colors.yellow.shade50);
      });
    });
  });
}
