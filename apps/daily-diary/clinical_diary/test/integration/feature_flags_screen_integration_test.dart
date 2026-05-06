// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation
//
// Phase 12.9 (CUR-1169): Restored from the legacy integration_test/ tree.
// Originally needed Datastore.initialize because the legacy app boot wired
// it in implicitly. The new FeatureFlagsScreen is fully decoupled from the
// diary stack — it only talks to FeatureFlagService.instance — so this
// integration test brings up just the screen and asserts on the
// per-screen-section flows that test/screens/feature_flags_screen_test.dart
// does not cover (multi-section layout, sponsor dropdown selection, the
// long-duration threshold slider gating, and a full reset round-trip).

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildScreen() {
  return const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: FeatureFlagsScreen(),
  );
}

void main() {
  setUpAll(() {
    F.appFlavor = Flavor.dev;
  });

  late FeatureFlagService featureFlags;

  setUp(() {
    featureFlags = FeatureFlagService.instance..resetToDefaults();
  });

  tearDown(() {
    featureFlags.resetToDefaults();
  });

  group('FeatureFlagsScreen Integration', () {
    // -----------------------------------------------------------------------
    // Screen layout — assert that the screen renders all four major sections
    // (sponsor config / UI features / validation features / font accessibility)
    // in one pass. test/screens/feature_flags_screen_test.dart only checks
    // the warning banner + a single switch.
    // -----------------------------------------------------------------------
    testWidgets('renders sponsor / UI / validation / font sections', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // App bar title and reset button.
      expect(find.text('Feature Flags'), findsOneWidget);
      expect(find.byIcon(Icons.restore), findsOneWidget);

      // Sponsor configuration: dropdown + load button.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download), findsOneWidget);

      // UI Features (visible at the top of the list).
      expect(find.text('Use Review Screen'), findsOneWidget);
      expect(find.text('Use Animations'), findsOneWidget);

      // Font accessibility section is further down — scroll to it.
      await tester.scrollUntilVisible(
        find.text('Roboto (Default)'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Roboto (Default)'), findsOneWidget);

      // Validation features.
      await tester.scrollUntilVisible(
        find.text('Old Entry Justification'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Old Entry Justification'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Toggle persistence — proves the screen writes through to the singleton
    // service for every toggle, not just the first one. This is the
    // integration-level claim: any toggle change is observable from outside
    // the widget tree.
    // -----------------------------------------------------------------------
    testWidgets(
      'toggling each switch writes through to FeatureFlagService.instance',
      (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle();

        // Use Review Screen: false -> true.
        expect(featureFlags.useReviewScreen, isFalse);
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Use Review Screen'),
        );
        await tester.pumpAndSettle();
        expect(featureFlags.useReviewScreen, isTrue);
        // Sanity: the singleton's state matches what the UI flipped.
        expect(FeatureFlagService.instance.useReviewScreen, isTrue);

        // Use Animations: true -> false.
        expect(featureFlags.useAnimations, isTrue);
        await tester.tap(find.widgetWithText(SwitchListTile, 'Use Animations'));
        await tester.pumpAndSettle();
        expect(featureFlags.useAnimations, isFalse);

        // Old Entry Justification (further down — scroll into view).
        final oldEntrySwitch = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(oldEntrySwitch, 100);
        await tester.pumpAndSettle();
        expect(featureFlags.requireOldEntryJustification, isFalse);
        await tester.tap(oldEntrySwitch);
        await tester.pumpAndSettle();
        expect(featureFlags.requireOldEntryJustification, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // Long-duration threshold slider gating — the slider is disabled when
    // long-duration confirmation is OFF, and enabled when it's ON. Dragging
    // the slider changes the threshold value. (REQ-CAL-p00003.)
    // -----------------------------------------------------------------------
    testWidgets('long-duration slider gates on the long-duration switch', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // The slider is below the validation switches; scroll until it's in view.
      await tester.scrollUntilVisible(find.byType(Slider), 100);
      await tester.pumpAndSettle();

      // Initially: long-duration confirmation OFF, slider disabled.
      expect(featureFlags.enableLongDurationConfirmation, isFalse);
      var slider = tester.widget<Slider>(find.byType(Slider));
      expect(
        slider.onChanged,
        isNull,
        reason: 'Slider should be disabled while long-duration is OFF',
      );

      // Turn on long-duration confirmation.
      final longDurationSwitch = find.widgetWithText(
        SwitchListTile,
        'Long Duration Confirmation',
      );
      await tester.scrollUntilVisible(longDurationSwitch, 100);
      await tester.pumpAndSettle();
      await tester.tap(longDurationSwitch);
      await tester.pumpAndSettle();
      expect(featureFlags.enableLongDurationConfirmation, isTrue);

      // Slider is now enabled.
      await tester.scrollUntilVisible(find.byType(Slider), 100);
      await tester.pumpAndSettle();
      slider = tester.widget<Slider>(find.byType(Slider));
      expect(
        slider.onChanged,
        isNotNull,
        reason: 'Slider should be enabled when long-duration is ON',
      );

      // Default threshold; drag the slider and confirm the service updates.
      expect(
        featureFlags.longDurationThresholdMinutes,
        FeatureFlags.defaultLongDurationThresholdMinutes,
      );
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(
        featureFlags.longDurationThresholdMinutes,
        greaterThan(FeatureFlags.defaultLongDurationThresholdMinutes),
      );
    });

    // -----------------------------------------------------------------------
    // Sponsor dropdown — opens, lists every known sponsor, and selecting
    // one updates the dropdown's display value. Single-screen flow with no
    // service-singleton mutation (sponsor config is a separate config blob).
    // -----------------------------------------------------------------------
    testWidgets('sponsor dropdown lists every known sponsor and selects', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Each known sponsor is listed (each appears at least once — the
      // currently-selected one shows up in both the dropdown and the
      // closed-state field, so use findsWidgets, not findsOneWidget).
      for (final sponsor in FeatureFlags.knownSponsors) {
        expect(find.text(sponsor), findsWidgets);
      }

      // If there's more than one sponsor, switching to a different one
      // updates the closed-state display.
      if (FeatureFlags.knownSponsors.length > 1) {
        final other = FeatureFlags.knownSponsors[1];
        await tester.tap(find.text(other).last);
        await tester.pumpAndSettle();
        expect(find.text(other), findsOneWidget);
      }
    });

    // -----------------------------------------------------------------------
    // Reset round-trip — change values, open the dialog, confirm reset,
    // see that every changed value is back to defaults and a snackbar
    // appears.
    // -----------------------------------------------------------------------
    testWidgets('reset confirmation restores every flag to default', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Change three values.
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Use Review Screen'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Use Animations'));
      await tester.pumpAndSettle();

      final oldEntrySwitch = find.widgetWithText(
        SwitchListTile,
        'Old Entry Justification',
      );
      await tester.scrollUntilVisible(oldEntrySwitch, 100);
      await tester.pumpAndSettle();
      await tester.tap(oldEntrySwitch);
      await tester.pumpAndSettle();

      expect(featureFlags.useReviewScreen, isTrue);
      expect(featureFlags.useAnimations, isFalse);
      expect(featureFlags.requireOldEntryJustification, isTrue);

      // Open the reset dialog.
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap the Reset confirm button (scoped to the dialog so we don't
      // accidentally hit the Load button).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      // All three values are back to defaults.
      expect(featureFlags.useReviewScreen, FeatureFlags.defaultUseReviewScreen);
      expect(featureFlags.useAnimations, FeatureFlags.defaultUseAnimations);
      expect(
        featureFlags.requireOldEntryJustification,
        FeatureFlags.defaultRequireOldEntryJustification,
      );

      // A success snackbar is shown.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Reset cancel — change a value, open the dialog, tap Cancel, value
    // remains changed.
    // -----------------------------------------------------------------------
    testWidgets('reset confirmation cancel preserves changed values', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Use Review Screen'),
      );
      await tester.pumpAndSettle();
      expect(featureFlags.useReviewScreen, isTrue);

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      // Tap Cancel (the TextButton inside the dialog).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(featureFlags.useReviewScreen, isTrue);
    });
  });
}
