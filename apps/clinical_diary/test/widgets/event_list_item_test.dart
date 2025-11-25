// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventListItem', () {
    final testDate = DateTime(2024, 1, 15);

    testWidgets('displays time range when both start and end time provided', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.textContaining('10:30 AM'), findsOneWidget);
      expect(find.textContaining('10:45 AM'), findsOneWidget);
    });

    testWidgets('displays only start time when end time is missing', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 14, 0),
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('2:00 PM'), findsOneWidget);
    });

    testWidgets('displays -- when no times provided', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('displays severity name', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        severity: NosebleedSeverity.steadyStream,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('Steady stream'), findsOneWidget);
    });

    testWidgets('does not display severity when null', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      for (final severity in NosebleedSeverity.values) {
        expect(find.text(severity.displayName), findsNothing);
      }
    });

    testWidgets('displays duration in minutes', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45), // 15 minutes
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('15m'), findsOneWidget);
    });

    testWidgets('displays duration in hours and minutes', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 11, 30), // 1 hour 30 minutes
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('displays duration in hours only when no remaining minutes', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 0),
        endTime: DateTime(2024, 1, 15, 12, 0), // 2 hours exactly
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets('shows Incomplete badge for incomplete records', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        isIncomplete: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show Incomplete badge for complete records', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
        endTime: DateTime(2024, 1, 15, 10, 45),
        severity: NosebleedSeverity.dripping,
        isIncomplete: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.text('Incomplete'), findsNothing);
    });

    testWidgets('shows chevron icon when onTap is provided', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(
              record: record,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('does not show chevron icon when onTap is null', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        startTime: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

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
        MaterialApp(
          home: Scaffold(
            body: EventListItem(
              record: record,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EventListItem));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('renders as a Card', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays severity indicator bar', (tester) async {
      final record = NosebleedRecord(
        id: 'test-1',
        date: testDate,
        severity: NosebleedSeverity.dripping,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventListItem(record: record),
          ),
        ),
      );

      // Find the container that serves as the severity indicator
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
  });
}
