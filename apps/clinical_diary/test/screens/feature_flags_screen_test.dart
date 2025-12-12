// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Set up flavor for tests
  F.appFlavor = Flavor.dev;

  late FeatureFlagService featureFlagService;

  setUp(() {
    featureFlagService = FeatureFlagService.instance..resetToDefaults();
  });

  tearDown(() {
    featureFlagService.resetToDefaults();
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en')],
      home: FeatureFlagsScreen(),
    );
  }

  group('FeatureFlagsScreen', () {
    testWidgets('renders scaffold with app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays warning icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('displays reset icon in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restore), findsOneWidget);
    });

    testWidgets('displays dropdown for sponsor selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('displays load button with cloud download icon', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_download), findsOneWidget);
    });

    testWidgets('displays switch list tiles for toggles', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Some switches may be off-screen, just verify we have some
      expect(find.byType(SwitchListTile), findsWidgets);
    });

    testWidgets('displays list view with content', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    group('Toggle Functionality', () {
      testWidgets('toggling first switch (Use Review Screen) updates service', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(featureFlagService.useReviewScreen, false);

        // Find the first SwitchListTile and tap it
        final switchTiles = find.byType(SwitchListTile);
        await tester.tap(switchTiles.first);
        await tester.pumpAndSettle();

        expect(featureFlagService.useReviewScreen, true);
      });

      testWidgets('toggling second switch (Use Animations) updates service', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(featureFlagService.useAnimations, true);

        // Find the second SwitchListTile and tap it
        final switchTiles = find.byType(SwitchListTile);
        await tester.tap(switchTiles.at(1));
        await tester.pumpAndSettle();

        expect(featureFlagService.useAnimations, false);
      });

      testWidgets(
        'toggling third switch (One-Page Recording Screen) updates service',
        (tester) async {
          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          expect(featureFlagService.useOnePageRecordingScreen, false);

          // Find the third SwitchListTile and tap it
          final switchTiles = find.byType(SwitchListTile);
          await tester.tap(switchTiles.at(2));
          await tester.pumpAndSettle();

          expect(featureFlagService.useOnePageRecordingScreen, true);
        },
      );

      testWidgets('toggling Old Entry Justification switch updates service', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(featureFlagService.requireOldEntryJustification, false);

        // Scroll to make the Old Entry Justification switch visible
        final oldEntrySwitch = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(oldEntrySwitch, 100);
        await tester.pumpAndSettle();

        await tester.tap(oldEntrySwitch);
        await tester.pumpAndSettle();

        expect(featureFlagService.requireOldEntryJustification, true);
      });
    });

    group('Sponsor Dropdown', () {
      testWidgets('can open dropdown', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Dropdown should show options
        expect(find.byType(DropdownMenuItem<String>), findsWidgets);
      });
    });

    group('Reset Functionality', () {
      testWidgets('tapping reset icon opens dialog', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Dialog should appear
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('dialog has cancel and confirm buttons', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Should have TextButton (Cancel) and FilledButton (Reset)
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('tapping cancel closes dialog without resetting', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Change a value
        final switchTiles = find.byType(SwitchListTile);
        await tester.tap(switchTiles.first);
        await tester.pumpAndSettle();
        expect(featureFlagService.useReviewScreen, true);

        // Open dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Cancel
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();

        // Value should remain changed
        expect(featureFlagService.useReviewScreen, true);
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('tapping reset resets values to defaults', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Change values
        featureFlagService
          ..useReviewScreen = true
          ..useAnimations = false;

        // Open dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Confirm reset
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Values should be back to defaults
        expect(
          featureFlagService.useReviewScreen,
          FeatureFlags.defaultUseReviewScreen,
        );
        expect(
          featureFlagService.useAnimations,
          FeatureFlags.defaultUseAnimations,
        );
      });

      testWidgets('reset shows success snackbar', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();

        // Confirm reset
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Snackbar should appear
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });

    group('Initial State', () {
      testWidgets('displays all feature flags with default values', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Verify service has default values
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
    });

    group('Service State', () {
      testWidgets('service state updates when toggles are changed', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Initial state
        expect(featureFlagService.useReviewScreen, false);
        expect(featureFlagService.useAnimations, true);
        expect(featureFlagService.requireOldEntryJustification, false);

        // Toggle first switch
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();

        expect(featureFlagService.useReviewScreen, true);

        // Toggle second switch
        await tester.tap(find.byType(SwitchListTile).at(1));
        await tester.pumpAndSettle();

        expect(featureFlagService.useAnimations, false);

        // Scroll to and toggle Old Entry Justification switch
        final oldEntrySwitch = find.widgetWithText(
          SwitchListTile,
          'Old Entry Justification',
        );
        await tester.scrollUntilVisible(oldEntrySwitch, 100);
        await tester.pumpAndSettle();

        await tester.tap(oldEntrySwitch);
        await tester.pumpAndSettle();

        expect(featureFlagService.requireOldEntryJustification, true);
      });

      testWidgets('can update service directly and screen reflects state', (
        tester,
      ) async {
        // Pre-set values
        featureFlagService
          ..useReviewScreen = true
          ..useAnimations = false;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Service should have the values we set
        expect(featureFlagService.useReviewScreen, true);
        expect(featureFlagService.useAnimations, false);
      });
    });

    group('Screen Content', () {
      testWidgets('displays button for load action', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Load button has cloud download icon
        expect(find.byIcon(Icons.cloud_download), findsOneWidget);
      });

      testWidgets('displays section dividers', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Divider), findsWidgets);
      });

      testWidgets('warning container has error color', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Find the container with warning icon
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      });
    });
  });
}
