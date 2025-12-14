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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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

    testWidgets('shows Export Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () {},
            onImportData: () {},
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

      expect(find.text('Export Data'), findsOneWidget);
    });

    testWidgets('shows Import Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () {},
            onImportData: () {},
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

      expect(find.text('Import Data'), findsOneWidget);
    });

    testWidgets('shows Reset All Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () {},
            onImportData: () {},
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

    testWidgets('calls onExportData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () => called = true,
            onImportData: () {},
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

      await tester.tap(find.text('Export Data'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onImportData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () {},
            onImportData: () => called = true,
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

      await tester.tap(find.text('Import Data'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onResetAllData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
            onExportData: () {},
            onImportData: () {},
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
