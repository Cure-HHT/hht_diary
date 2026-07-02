import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_helpers.dart';

void main() {
  // Verifies: DIARY-PRD-mobile-application/A+B
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

    // Verifies: DIARY-BASE-local-data-reset/B+C — the reset item is disabled
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

    // Verifies: DIARY-BASE-local-data-reset/B+C — when the gate is open the
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

  group('LogoMenu service-mode entry', () {
    setUp(() {
      // Make the version label render non-empty so the tap target exists.
      PackageInfo.setMockInitialValues(
        appName: 'diary',
        packageName: 'org.curehht.diary',
        version: '1.2.3',
        buildNumber: '7',
        buildSignature: '',
      );
    });

    Future<void> pumpMenu(
      WidgetTester tester, {
      required VoidCallback? onOpenServiceMode,
    }) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: null,
            onInstructionsAndFeedback: () {},
            onOpenServiceMode: onOpenServiceMode,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.text('v1.2.3+7'), findsOneWidget);
    }

    // Verifies: DIARY-GUI-service-mode-entry/A — seven taps on the version
    //   label reveals Service Mode (invokes the navigation callback).
    testWidgets('tapping the version label 7x invokes onOpenServiceMode', (
      tester,
    ) async {
      var opened = 0;
      await pumpMenu(tester, onOpenServiceMode: () => opened++);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('v1.2.3+7'));
        await tester.pumpAndSettle();
      }

      expect(opened, 1);
    });

    // Verifies: DIARY-GUI-service-mode-entry/A — fewer than seven taps does not
    //   reveal Service Mode.
    testWidgets('six taps does not invoke onOpenServiceMode', (tester) async {
      var opened = 0;
      await pumpMenu(tester, onOpenServiceMode: () => opened++);

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('v1.2.3+7'));
        await tester.pumpAndSettle();
      }

      expect(opened, 0);
    });

    // Verifies: DIARY-GUI-service-mode-entry/A — with no handler wired the
    //   easter egg is inert and does not throw.
    testWidgets('seven taps is inert when onOpenServiceMode is null', (
      tester,
    ) async {
      await pumpMenu(tester, onOpenServiceMode: null);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('v1.2.3+7'));
        await tester.pumpAndSettle();
      }

      // No exception; the menu stays open (never popped).
      expect(find.text('v1.2.3+7'), findsOneWidget);
    });
  });

  // Verifies: DIARY-DEV-sponsor-branding-assets/D — the logo-menu affordance is
  //   NEVER invisible. When enrolled to a sponsor whose logo is unconfigured
  //   (null builder) or unavailable (builder renders its fallback), the menu
  //   falls back to the app default brand instead of an empty/zero SizedBox
  //   (the pre-fix bug, which hid reset / end-trial / licenses / service-mode).
  group('LogoMenu branding fallback (enrolled, no sponsor logo)', () {
    testWidgets('enrolled with a null sponsor logo builder shows the default '
        'brand (menu stays visible)', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: () {},
            onInstructionsAndFeedback: () {},
            isEnrolled: true,
            // No sponsor logo configured.
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pre-fix this branch rendered `const SizedBox()` → no Image → menu gone.
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 100);
      expect(image.height, 40);

      // And it is still tappable / opens the menu.
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.text('Clinical Trial'), findsOneWidget);
    });

    testWidgets('enrolled but sponsor logo unavailable falls back to the '
        'default brand via the builder fallback', (tester) async {
      // A builder that cannot resolve the logo bytes renders the fallback it
      // was handed — which must be the default brand, not an empty box.
      Widget fallbackOnlyBuilder({
        required double width,
        required double height,
        required Widget fallback,
      }) => fallback;

      await tester.pumpWidget(
        wrapWithScaffold(
          LogoMenu(
            onResetAllData: () {},
            onEndClinicalTrial: () {},
            onInstructionsAndFeedback: () {},
            isEnrolled: true,
            sponsorLogoBuilder: fallbackOnlyBuilder,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pre-fix the fallback was `SizedBox(40x120)` → no Image → menu gone.
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.text('Clinical Trial'), findsOneWidget);
    });
  });
}
