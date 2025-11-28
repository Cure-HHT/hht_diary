// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/date_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateHeader', () {
    testWidgets('displays formatted date', (tester) async {
      final testDate = DateTime(2024, 1, 15); // Monday, January 15

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(date: testDate, onChange: (_) {}),
          ),
        ),
      );

      expect(find.text('Monday, January 15'), findsOneWidget);
    });

    testWidgets('displays calendar icon when editable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('does not display calendar icon when not editable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsNothing);
    });

    testWidgets('opens date picker when tapped and editable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Monday, January 15'));
      await tester.pumpAndSettle();

      // Date picker should be shown
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('does not open date picker when tapped and not editable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Monday, January 15'));
      await tester.pumpAndSettle();

      // Date picker should NOT be shown
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('has background color when editable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: true,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DateHeader),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNotNull);
    });

    testWidgets('has transparent background when not editable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(
              date: DateTime(2024, 1, 15),
              onChange: (_) {},
              editable: false,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DateHeader),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, Colors.transparent);
    });

    testWidgets('displays different dates correctly', (tester) async {
      // Test with a different date
      final testDate = DateTime(2024, 12, 25); // Wednesday, December 25

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(date: testDate, onChange: (_) {}),
          ),
        ),
      );

      expect(find.text('Wednesday, December 25'), findsOneWidget);
    });

    testWidgets('is wrapped in GestureDetector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateHeader(date: DateTime(2024, 1, 15), onChange: (_) {}),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });
}
