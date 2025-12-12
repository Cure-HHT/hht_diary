// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set up flavor for tests
  F.appFlavor = Flavor.dev;
  AppConfig.testApiBaseOverride = 'https://test.example.com/api';

  group('FeatureFlagsScreen Integration Tests', () {
    late FeatureFlagService featureFlagService;

    setUp(() {
      featureFlagService = FeatureFlagService.instance..resetToDefaults();
    });

    tearDown(() {
      featureFlagService.resetToDefaults();
    });

    Widget buildFeatureFlagsScreen() {
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

    group('Screen Layout', () {
      testWidgets('displays app bar with title and reset button', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Check app bar title
        expect(find.text('Feature Flags'), findsOneWidget);

        // Check reset button in app bar
        expect(find.byIcon(Icons.restore), findsOneWidget);
      });

      testWidgets('displays warning banner', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Check for warning icon
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

        // Check for warning text
        expect(find.textContaining('testing'), findsOneWidget);
      });

      testWidgets('displays sponsor configuration section', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Check for sponsor configuration header (localized string)
        expect(find.text('Sponsor Configuration'), findsOneWidget);

        // Check for Load button
        expect(find.byIcon(Icons.cloud_download), findsOneWidget);
      });

      testWidgets('displays UI features section with switches', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Check for UI Features section header
        expect(find.text('UI Features'), findsOneWidget);

        // Check for Use Review Screen switch
        expect(find.text('Use Review Screen'), findsOneWidget);

        // Check for Use Animations switch
        expect(find.text('Use Animations'), findsOneWidget);
      });

      testWidgets('displays font accessibility section', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Scroll to make Font Accessibility section visible
        await tester.scrollUntilVisible(find.text('Font Accessibility'), 100);
        await tester.pumpAndSettle();

        // Check for Font Accessibility section header
        expect(find.text('Font Accessibility'), findsOneWidget);

        // Check for font checkboxes
        expect(find.text('Roboto (Default)'), findsOneWidget);
        expect(find.text('OpenDyslexic'), findsOneWidget);
        expect(find.text('Atkinson Hyperlegible'), findsOneWidget);
      });

      testWidgets('displays validation features section', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Scroll to make Validation Features section visible
        // (Font Accessibility section may push it off-screen)
        await tester.scrollUntilVisible(find.text('Validation Features'), 100);
        await tester.pumpAndSettle();

        // Check for Validation Features section header
        expect(find.text('Validation Features'), findsOneWidget);

        // Check for Old Entry Justification switch
        expect(find.text('Old Entry Justification'), findsOneWidget);

        // Check for Short Duration Confirmation switch
        expect(find.text('Short Duration Confirmation'), findsOneWidget);

        // Scroll to make Long Duration Confirmation visible
        await tester.scrollUntilVisible(
          find.text('Long Duration Confirmation'),
          100,
        );
        await tester.pumpAndSettle();

        // Check for Long Duration Confirmation switch
        expect(find.text('Long Duration Confirmation'), findsOneWidget);
      });
    });

    group('Toggle Switches', () {
      testWidgets('useReviewScreen toggle updates service value', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Initially false (default)
        expect(featureFlagService.useReviewScreen, false);

        // Find and tap the Use Review Screen SwitchListTile
        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Use Review Screen',
        );
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // Now should be true
        expect(featureFlagService.useReviewScreen, true);

        // Tap again to toggle back
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // Back to false
        expect(featureFlagService.useReviewScreen, false);
      });

      testWidgets('useAnimations toggle updates service value', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Initially true (default)
        expect(featureFlagService.useAnimations, true);

        // Find the Use Animations SwitchListTile
        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Use Animations',
        );
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // Now should be false
        expect(featureFlagService.useAnimations, false);
      });

      testWidgets('requireOldEntryJustification toggle updates service value', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Initially false (default)
        expect(featureFlagService.requireOldEntryJustification, false);

        // Scroll to and tap the Old Entry Justification SwitchListTile
        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(switchTile, 100);
        await tester.pumpAndSettle();
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // Now should be true
        expect(featureFlagService.requireOldEntryJustification, true);
      });

      testWidgets(
        'enableShortDurationConfirmation toggle updates service value',
        (tester) async {
          await tester.pumpWidget(buildFeatureFlagsScreen());
          await tester.pumpAndSettle();

          // Initially false (default)
          expect(featureFlagService.enableShortDurationConfirmation, false);

          // Find and tap the Short Duration Confirmation SwitchListTile
          // First scroll to make sure it's visible
          await tester.scrollUntilVisible(
            find.widgetWithText(SwitchListTile, 'Short Duration Confirmation'),
            100,
          );
          await tester.pumpAndSettle();

          final switchTile = find.widgetWithText(
            SwitchListTile,
            'Short Duration Confirmation',
          );
          await tester.tap(switchTile);
          await tester.pumpAndSettle();

          // Now should be true
          expect(featureFlagService.enableShortDurationConfirmation, true);
        },
      );

      testWidgets(
        'enableLongDurationConfirmation toggle updates service value',
        (tester) async {
          await tester.pumpWidget(buildFeatureFlagsScreen());
          await tester.pumpAndSettle();

          // Initially false (default)
          expect(featureFlagService.enableLongDurationConfirmation, false);

          // Find and tap the Long Duration Confirmation SwitchListTile
          // First scroll to make sure it's visible
          await tester.scrollUntilVisible(
            find.widgetWithText(SwitchListTile, 'Long Duration Confirmation'),
            100,
          );
          await tester.pumpAndSettle();

          final switchTile = find.widgetWithText(
            SwitchListTile,
            'Long Duration Confirmation',
          );
          await tester.tap(switchTile);
          await tester.pumpAndSettle();

          // Now should be true
          expect(featureFlagService.enableLongDurationConfirmation, true);
        },
      );
    });

    group('Long Duration Threshold Slider', () {
      testWidgets('slider is disabled when long duration confirmation is off', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Ensure long duration confirmation is off
        expect(featureFlagService.enableLongDurationConfirmation, false);

        // Scroll to make slider visible
        await tester.scrollUntilVisible(find.byType(Slider), 100);
        await tester.pumpAndSettle();

        // Find the slider
        final slider = tester.widget<Slider>(find.byType(Slider));

        // Slider should have onChanged null (disabled)
        expect(slider.onChanged, isNull);
      });

      testWidgets('slider is enabled when long duration confirmation is on', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // First scroll to and enable long duration confirmation
        await tester.scrollUntilVisible(
          find.widgetWithText(SwitchListTile, 'Long Duration Confirmation'),
          100,
        );
        await tester.pumpAndSettle();

        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Long Duration Confirmation',
        );
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        expect(featureFlagService.enableLongDurationConfirmation, true);

        // Scroll to make slider visible
        await tester.scrollUntilVisible(find.byType(Slider), 100);
        await tester.pumpAndSettle();

        // Find the slider
        final slider = tester.widget<Slider>(find.byType(Slider));

        // Slider should now be enabled
        expect(slider.onChanged, isNotNull);
      });

      testWidgets('slider changes threshold value', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // First scroll to and enable long duration confirmation
        await tester.scrollUntilVisible(
          find.widgetWithText(SwitchListTile, 'Long Duration Confirmation'),
          100,
        );
        await tester.pumpAndSettle();

        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Long Duration Confirmation',
        );
        await tester.tap(switchTile);
        await tester.pumpAndSettle();

        // Initial threshold is 60 minutes (1 hour)
        expect(featureFlagService.longDurationThresholdMinutes, 60);

        // Scroll to make slider visible
        await tester.scrollUntilVisible(find.byType(Slider), 100);
        await tester.pumpAndSettle();

        // Drag the slider to the right
        final sliderFinder = find.byType(Slider);
        await tester.drag(sliderFinder, const Offset(100, 0));
        await tester.pumpAndSettle();

        // Threshold should have increased
        expect(
          featureFlagService.longDurationThresholdMinutes,
          greaterThan(60),
        );
      });
    });

    group('Reset to Defaults', () {
      testWidgets('reset button shows confirmation dialog', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Tap the reset button in app bar
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Check for confirmation dialog (title has question mark)
        expect(find.text('Reset Feature Flags?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);
      });

      testWidgets('cancel button closes dialog without resetting', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Change a value first
        final switchTile = find.widgetWithText(
          SwitchListTile,
          'Use Review Screen',
        );
        await tester.tap(switchTile);
        await tester.pumpAndSettle();
        expect(featureFlagService.useReviewScreen, true);

        // Open reset dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Value should NOT have been reset
        expect(featureFlagService.useReviewScreen, true);
      });

      testWidgets('reset button resets all values to defaults', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Change multiple values
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Use Review Screen'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SwitchListTile, 'Use Animations'));
        await tester.pumpAndSettle();

        // Scroll to Old Entry Justification and tap it
        final oldEntrySwitch = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(oldEntrySwitch, 100);
        await tester.pumpAndSettle();
        await tester.tap(oldEntrySwitch);
        await tester.pumpAndSettle();

        expect(featureFlagService.useReviewScreen, true);
        expect(featureFlagService.useAnimations, false);
        expect(featureFlagService.requireOldEntryJustification, true);

        // Open reset dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Tap Reset
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        // All values should be reset to defaults
        expect(
          featureFlagService.useReviewScreen,
          FeatureFlags.defaultUseReviewScreen,
        );
        expect(
          featureFlagService.useAnimations,
          FeatureFlags.defaultUseAnimations,
        );
        expect(
          featureFlagService.requireOldEntryJustification,
          FeatureFlags.defaultRequireOldEntryJustification,
        );
      });

      testWidgets('reset shows success snackbar', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Open reset dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Tap Reset
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        // Check for success snackbar
        expect(find.textContaining('reset'), findsOneWidget);
      });
    });

    group('Sponsor Dropdown', () {
      testWidgets('displays all known sponsors', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Tap on the dropdown to open it
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Check that all known sponsors are in the dropdown
        for (final sponsor in FeatureFlags.knownSponsors) {
          expect(find.text(sponsor), findsWidgets);
        }
      });

      testWidgets('can select different sponsor', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Open the dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Select the second sponsor (if there are multiple)
        if (FeatureFlags.knownSponsors.length > 1) {
          final secondSponsor = FeatureFlags.knownSponsors[1];
          await tester.tap(find.text(secondSponsor).last);
          await tester.pumpAndSettle();

          // The dropdown should now show the selected sponsor
          expect(find.text(secondSponsor), findsOneWidget);
        }
      });
    });

    group('Feature Flag Behaviors', () {
      testWidgets('all defaults match FeatureFlags class defaults', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Verify the service values match the static defaults
        expect(
          featureFlagService.useReviewScreen,
          FeatureFlags.defaultUseReviewScreen,
        );
        expect(
          featureFlagService.useAnimations,
          FeatureFlags.defaultUseAnimations,
        );
        expect(
          featureFlagService.useOnePageRecordingScreen,
          FeatureFlags.defaultUseOnePageRecordingScreen,
        );
        expect(
          featureFlagService.requireOldEntryJustification,
          FeatureFlags.defaultRequireOldEntryJustification,
        );
        expect(
          featureFlagService.enableShortDurationConfirmation,
          FeatureFlags.defaultEnableShortDurationConfirmation,
        );
        expect(
          featureFlagService.enableLongDurationConfirmation,
          FeatureFlags.defaultEnableLongDurationConfirmation,
        );
        expect(
          featureFlagService.longDurationThresholdMinutes,
          FeatureFlags.defaultLongDurationThresholdMinutes,
        );
      });

      testWidgets('changes persist in service singleton', (tester) async {
        await tester.pumpWidget(buildFeatureFlagsScreen());
        await tester.pumpAndSettle();

        // Make changes using SwitchListTile widgets
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Use Review Screen'),
        );
        await tester.pumpAndSettle();

        // Scroll to Old Entry Justification and tap it
        final oldEntrySwitch = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(oldEntrySwitch, 100);
        await tester.pumpAndSettle();
        await tester.tap(oldEntrySwitch);
        await tester.pumpAndSettle();

        // Verify changes were made
        expect(featureFlagService.useReviewScreen, true);
        expect(featureFlagService.requireOldEntryJustification, true);

        // Changes persist in the singleton service
        expect(FeatureFlagService.instance.useReviewScreen, true);
        expect(FeatureFlagService.instance.requireOldEntryJustification, true);
      });
    });
  });
}
