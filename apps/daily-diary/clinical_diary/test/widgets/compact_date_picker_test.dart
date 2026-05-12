// Tests for compact_date_picker.dart
// Covers: Date selection logic, formatting, date picker interactions

import 'package:clinical_diary/widgets/compact_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestWidget({
    required DateTime date,
    required ValueChanged<DateTime> onChange,
    DateTime? maxDate,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      home: Scaffold(
        body: Center(
          child: CompactDatePicker(
            date: date,
            onChange: onChange,
            maxDate: maxDate,
          ),
        ),
      ),
    );
  }

  group('CompactDatePicker', () {
    testWidgets('displays formatted date', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 12, 25),
          onChange: (_) {},
        ),
      );

      // Should display date in MMM d format (e.g., "Dec 25")
      expect(find.textContaining('Dec'), findsOneWidget);
      expect(find.textContaining('25'), findsOneWidget);
    });

    testWidgets('displays calendar icon', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 1, 15),
          onChange: (_) {},
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('tapping opens date picker', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 6, 15),
          onChange: (_) {},
          maxDate: DateTime(2024, 12, 31),
        ),
      );

      // Tap on the date picker widget
      await tester.tap(find.byType(CompactDatePicker));
      await tester.pumpAndSettle();

      // Date picker dialog should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('selecting a date calls onChange', (tester) async {
      DateTime? selectedDate;

      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 6, 15),
          onChange: (date) => selectedDate = date,
          maxDate: DateTime(2024, 12, 31),
        ),
      );

      // Open date picker
      await tester.tap(find.byType(CompactDatePicker));
      await tester.pumpAndSettle();

      // Find and tap a different date (day 20)
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // Tap OK to confirm
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(selectedDate, isNotNull);
      expect(selectedDate!.day, 20);
    });

    testWidgets('canceling date picker does not call onChange', (tester) async {
      var onChangeCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 6, 15),
          onChange: (_) => onChangeCalled = true,
          maxDate: DateTime(2024, 12, 31),
        ),
      );

      // Open date picker
      await tester.tap(find.byType(CompactDatePicker));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(onChangeCalled, false);
    });

    testWidgets('selecting same date does not call onChange', (tester) async {
      var onChangeCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 6, 15),
          onChange: (_) => onChangeCalled = true,
          maxDate: DateTime(2024, 12, 31),
        ),
      );

      // Open date picker
      await tester.tap(find.byType(CompactDatePicker));
      await tester.pumpAndSettle();

      // Tap the same date (15)
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // onChange should not be called when selecting the same date
      expect(onChangeCalled, false);
    });

    testWidgets('maxDate defaults to today when not provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime.now().subtract(const Duration(days: 1)),
          onChange: (_) {},
          // maxDate not provided - should default to DateTime.now()
        ),
      );

      // Open date picker
      await tester.tap(find.byType(CompactDatePicker));
      await tester.pumpAndSettle();

      // Date picker should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('applies correct styling', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 3, 14),
          onChange: (_) {},
        ),
      );

      // Find the container with border
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompactDatePicker),
          matching: find.byType(Container),
        ),
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.border, isNotNull);
    });

    testWidgets('displays different months correctly', (tester) async {
      // Test January
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 1, 1),
          onChange: (_) {},
        ),
      );
      expect(find.textContaining('Jan'), findsOneWidget);

      // Test July
      await tester.pumpWidget(
        buildTestWidget(
          date: DateTime(2024, 7, 4),
          onChange: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Jul'), findsOneWidget);
    });
  });
}
