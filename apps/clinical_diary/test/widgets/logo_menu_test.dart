// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogoMenu', () {
    testWidgets('displays medical services icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
    });

    testWidgets('icon is tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      // Find the icon button and tap it
      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      // Menu should be visible
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('shows Data Management section header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('shows Add Example Data option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Add Example Data'), findsOneWidget);
    });

    testWidgets('shows Reset All Data option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Reset All Data'), findsOneWidget);
    });

    testWidgets('calls onAddExampleData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () => called = true,
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Example Data'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onResetAllData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () => called = true,
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All Data'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows Instructions and Feedback option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Instructions & Feedback'), findsOneWidget);
    });

    testWidgets('calls onInstructionsAndFeedback when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Instructions & Feedback'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows End Clinical Trial when enrolled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: () {},
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('End Clinical Trial'), findsOneWidget);
    });

    testWidgets('hides End Clinical Trial when not enrolled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('End Clinical Trial'), findsNothing);
    });

    testWidgets('calls onEndClinicalTrial when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: () => called = true,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('End Clinical Trial'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows Clinical Trial section when enrolled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: () {},
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Clinical Trial'), findsOneWidget);
    });

    testWidgets('shows external link icon for Instructions & Feedback',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogoMenu(
              onAddExampleData: () {},
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.medical_services_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });
  });
}
