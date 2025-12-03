// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DaySelectionScreen', () {
    final testDate = DateTime(2025, 11, 28);

    testWidgets('displays the formatted date', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dateStr = DateFormat('EEEE, MMMM d, y').format(testDate);
      expect(find.text(dateStr), findsOneWidget);
    });

    testWidgets('displays "What happened on this day?" question', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What happened on this day?'), findsOneWidget);
    });

    testWidgets('displays Add nosebleed event button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add nosebleed event'), findsOneWidget);
    });

    testWidgets('displays No nosebleed events button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No nosebleed events'), findsOneWidget);
    });

    testWidgets('displays I dont recall button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("I don't recall / unknown"), findsOneWidget);
    });

    testWidgets('calls onAddNosebleed when Add nosebleed event is tapped', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () => called = true,
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add nosebleed event'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onNoNosebleeds when No nosebleed events is tapped', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () => called = true,
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No nosebleed events'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onUnknown when I dont recall is tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("I don't recall / unknown"));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('Add nosebleed button has add icon', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the add icon is present with the button
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('No nosebleed events button has check icon', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('displays back button', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('back button is tappable', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the back button exists and is an IconButton
      final backButtonFinder = find.byIcon(Icons.arrow_back);
      expect(backButtonFinder, findsOneWidget);

      // Verify it's inside an IconButton that can be tapped
      expect(
        find.ancestor(of: backButtonFinder, matching: find.byType(IconButton)),
        findsOneWidget,
      );
    });

    testWidgets('has three action buttons with correct text', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          DaySelectionScreen(
            date: testDate,
            onAddNosebleed: () {},
            onNoNosebleeds: () {},
            onUnknown: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all three buttons exist by their text
      expect(find.text('Add nosebleed event'), findsOneWidget);
      expect(find.text('No nosebleed events'), findsOneWidget);
      expect(find.text("I don't recall / unknown"), findsOneWidget);
    });
  });
}
