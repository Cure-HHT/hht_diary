// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('LogoMenu', () {
    testWidgets('displays logo image with correct size and grey filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);

      // Verify logo size is 100x40
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 100);
      expect(image.height, 40);
    });

    testWidgets('icon is tappable', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the logo image and tap it
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      // Menu should be visible
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('shows Data Management section header', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('shows Add Example Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('Add Example Data'), findsOneWidget);
    });

    testWidgets('shows Reset All Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('Reset All Data?'), findsOneWidget);
    });

    testWidgets('calls onAddExampleData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () => called = true,
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Example Data'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onResetAllData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () => called = true,
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All Data?'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows Instructions and Feedback option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('Instructions & Feedback'), findsOneWidget);
    });

    testWidgets('calls onInstructionsAndFeedback when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Instructions & Feedback'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows End Clinical Trial when enrolled', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: () {},
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('End Clinical Trial?'), findsOneWidget);
    });

    testWidgets('hides End Clinical Trial when not enrolled', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('End Clinical Trial?'), findsNothing);
    });

    testWidgets('calls onEndClinicalTrial when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: () => called = true,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      await tester.tap(find.text('End Clinical Trial?'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows Clinical Trial section when enrolled', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: () {},
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('Clinical Trial'), findsOneWidget);
    });

    testWidgets('shows external link icon for Instructions & Feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onAddExampleData: () {},
            onResetAllData: () {},
            onFeatureFlags: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });
  });
}
