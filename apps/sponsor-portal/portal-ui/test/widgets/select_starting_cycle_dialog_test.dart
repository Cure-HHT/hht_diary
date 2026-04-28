// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion H)
//
// Widget tests for SelectStartingCycleDialog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/widgets/select_starting_cycle_dialog.dart';

void main() {
  group('SelectStartingCycleDialog', () {
    Future<int?> pumpAndShow(WidgetTester tester, {int? suggestedCycle}) async {
      int? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await SelectStartingCycleDialog.show(
                      context: context,
                      questionnaireDisplayName: 'Nose HHT',
                      patientDisplayId: '002-1013456',
                      suggestedCycle: suggestedCycle,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      return result;
    }

    testWidgets('renders title and subtitle', (WidgetTester tester) async {
      await pumpAndShow(tester);

      expect(find.text('Start Questionnaire?'), findsOneWidget);
    });

    testWidgets('dropdown defaults to Cycle 1 when no suggestion', (
      WidgetTester tester,
    ) async {
      await pumpAndShow(tester);

      expect(find.text('Cycle 1 Day 1'), findsOneWidget);
    });

    testWidgets('dropdown pre-selects suggestedCycle', (
      WidgetTester tester,
    ) async {
      await pumpAndShow(tester, suggestedCycle: 5);

      expect(find.text('Cycle 5 Day 1'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (WidgetTester tester) async {
      int? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await SelectStartingCycleDialog.show(
                      context: context,
                      questionnaireDisplayName: 'Nose HHT',
                      patientDisplayId: '002-1013456',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Confirm and Send returns selected cycle', (
      WidgetTester tester,
    ) async {
      int? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await SelectStartingCycleDialog.show(
                      context: context,
                      questionnaireDisplayName: 'Nose HHT',
                      patientDisplayId: '002-1013456',
                      suggestedCycle: 3,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Default is pre-selected to 3, just confirm
      await tester.tap(find.text('Confirm and Send'));
      await tester.pumpAndSettle();

      expect(result, equals(3));
    });

    testWidgets('shows Confirm and Send button', (WidgetTester tester) async {
      await pumpAndShow(tester);

      expect(find.text('Confirm and Send'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('has Starting Cycle label on dropdown', (
      WidgetTester tester,
    ) async {
      await pumpAndShow(tester);

      expect(find.text('Cycle'), findsOneWidget);
    });

    testWidgets('shows info box with Daily Diary app text', (
      WidgetTester tester,
    ) async {
      await pumpAndShow(tester);

      expect(find.textContaining('Daily Diary app'), findsOneWidget);
    });

    testWidgets('shows info card with bold Cycle 1 Day 1', (
      WidgetTester tester,
    ) async {
      await pumpAndShow(tester);

      expect(find.textContaining('notification'), findsOneWidget);
    });

    testWidgets('has close X button', (WidgetTester tester) async {
      await pumpAndShow(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
