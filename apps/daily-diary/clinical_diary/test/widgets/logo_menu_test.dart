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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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

    testWidgets('shows Reset All Data option', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
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

    testWidgets('calls onResetAllData when tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () => called = true,
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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
            onResetAllData: () {},
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

    testWidgets('shows Data Management section when showDevTools is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
            showDevTools: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      // Data Management section header is shown when showDevTools is true
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('hides Data Management section when showDevTools is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
            showDevTools: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      // Dev-tools items (the section header + Reset All Data) are hidden when
      // showDevTools is false. Feature Flags has moved to Settings → Advanced.
      expect(find.text('Data Management'), findsNothing);
    });

    testWidgets(
      'does not show Feature Flags in app menu (moved to Advanced settings)',
      (tester) async {
        await tester.pumpWidget(
          wrapWithScaffold(
            LogoMenu(
              onResetAllData: () {},
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
              showDevTools: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Image));
        await tester.pumpAndSettle();

        // Feature Flags is no longer in the app menu — it moved to Settings → Advanced.
        expect(find.text('Feature Flags'), findsNothing);
      },
    );

    testWidgets('does not show Check for updates option (CUR-990)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      // Check for updates was removed — app updates are handled via app stores (CUR-990)
      expect(find.text('Check for updates'), findsNothing);
    });

    // Verifies: DIARY-PRD-local-data-reset/B+C — the reset item is disabled
    //   (greyed, non-tapping, with a reason) when the gate is closed.
    testWidgets(
      'reset item is disabled with a reason when resetEnabled=false',
      (tester) async {
        var called = false;
        await tester.pumpWidget(
          wrapWithScaffold(
            LogoMenu(
              onResetAllData: () => called = true,
              onEndClinicalTrial: null,
              onInstructionsAndFeedback: () {},
              resetEnabled: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Image));
        await tester.pumpAndSettle();

        // The disabled-reason subtitle is shown.
        expect(
          find.text('End your study participation to reset'),
          findsOneWidget,
        );

        // The disabled PopupMenuItem does not invoke the callback when tapped.
        await tester.tap(find.text('Reset All Data?'));
        await tester.pumpAndSettle();
        expect(called, isFalse);
      },
    );

    // Verifies: DIARY-PRD-local-data-reset/B+C — when the gate is open the
    //   reset item is enabled, has no disabled reason, and fires its callback.
    testWidgets('reset item is enabled when resetEnabled=true', (tester) async {
      var called = false;
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () => called = true,
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.text('End your study participation to reset'), findsNothing);

      await tester.tap(find.text('Reset All Data?'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets('menu closes after selecting Reset All Data', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () => called = true,
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

      // Callback should have been called
      expect(called, true);
    });
  });
}
