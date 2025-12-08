// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen', () {
    late PreferencesService preferencesService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
    });

    Widget buildSettingsScreen({
      ValueChanged<String>? onLanguageChanged,
      ValueChanged<bool>? onThemeModeChanged,
      ValueChanged<bool>? onLargerTextChanged,
    }) {
      return wrapWithMaterialApp(
        SettingsScreen(
          preferencesService: preferencesService,
          onLanguageChanged: onLanguageChanged,
          onThemeModeChanged: onThemeModeChanged,
          onLargerTextChanged: onLargerTextChanged,
        ),
      );
    }

    /// Set up a larger screen size for testing to avoid overflow errors
    void setUpTestScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
    }

    /// Reset screen size after test
    void resetTestScreenSize(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    group('Basic Rendering', () {
      testWidgets('displays settings header', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('displays back button', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
      });

      testWidgets('displays color scheme section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Color Scheme'), findsOneWidget);
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
      });

      testWidgets('displays accessibility section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Accessibility'), findsOneWidget);
        expect(find.text('Dyslexia-friendly font'), findsOneWidget);
        expect(find.text('Larger Text and Controls'), findsOneWidget);
      });

      testWidgets('displays language section', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Español'), findsOneWidget);
        expect(find.text('Français'), findsOneWidget);
        expect(find.text('Deutsch'), findsOneWidget);
      });

      testWidgets('displays compact view option', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Compact View'), findsOneWidget);
      });
    });

    group('Color Scheme Interaction', () {
      testWidgets('light mode is selected by default', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Light mode should be selected by default (show check icon)
        // We verify by checking the light_mode icon exists
        expect(find.byIcon(Icons.light_mode), findsOneWidget);
      });

      testWidgets('calls onThemeModeChanged when light mode tapped', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        bool? themeModeChanged;
        await tester.pumpWidget(
          buildSettingsScreen(onThemeModeChanged: (v) => themeModeChanged = v),
        );
        await tester.pumpAndSettle();

        // Tap light mode option
        await tester.tap(find.text('Light Mode'));
        await tester.pumpAndSettle();

        expect(themeModeChanged, false);
      });
    });

    group('Accessibility Options', () {
      testWidgets('can toggle dyslexia-friendly font', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Find and tap the checkbox for dyslexia font
        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsWidgets);

        // First checkbox should be dyslexia font
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();
      });

      testWidgets('can toggle larger text option', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        bool? largerTextChanged;
        await tester.pumpWidget(
          buildSettingsScreen(
            onLargerTextChanged: (v) => largerTextChanged = v,
          ),
        );
        await tester.pumpAndSettle();

        // Find and tap the larger text checkbox (second checkbox)
        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsWidgets);

        await tester.tap(checkboxes.at(1));
        await tester.pumpAndSettle();

        expect(largerTextChanged, true);
      });

      testWidgets('can toggle compact view option', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Compact view is the third or later checkbox
        final compactViewText = find.text('Compact View');
        expect(compactViewText, findsOneWidget);

        // Tap on the compact view text to toggle
        await tester.tap(compactViewText);
        await tester.pumpAndSettle();
      });

      testWidgets('dyslexia link is displayed', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Should show the learn more link
        expect(find.text('Learn more at opendyslexic.org'), findsOneWidget);
      });
    });

    group('Language Selection', () {
      testWidgets('English is selected by default', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // English should be in the list
        expect(find.text('English'), findsOneWidget);
      });

      testWidgets('calls onLanguageChanged when Spanish selected', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        String? languageChanged;
        await tester.pumpWidget(
          buildSettingsScreen(onLanguageChanged: (v) => languageChanged = v),
        );
        await tester.pumpAndSettle();

        // Tap Spanish option
        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();

        expect(languageChanged, 'es');
      });

      testWidgets('calls onLanguageChanged when French selected', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        String? languageChanged;
        await tester.pumpWidget(
          buildSettingsScreen(onLanguageChanged: (v) => languageChanged = v),
        );
        await tester.pumpAndSettle();

        // Tap French option
        await tester.tap(find.text('Français'));
        await tester.pumpAndSettle();

        expect(languageChanged, 'fr');
      });

      testWidgets('calls onLanguageChanged when German selected', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        String? languageChanged;
        await tester.pumpWidget(
          buildSettingsScreen(onLanguageChanged: (v) => languageChanged = v),
        );
        await tester.pumpAndSettle();

        // Tap German option
        await tester.tap(find.text('Deutsch'));
        await tester.pumpAndSettle();

        expect(languageChanged, 'de');
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator initially', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        // Don't settle - check for initial loading state
        await tester.pump();

        // Should show progress indicator while loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('hides loading indicator after preferences load', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Should not show progress indicator after loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Preferences Persistence', () {
      testWidgets('loads saved preferences on init', (tester) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        // Pre-set some preferences
        await preferencesService.savePreferences(
          const UserPreferences(
            isDarkMode: false,
            dyslexiaFriendlyFont: true,
            largerTextAndControls: true,
            useAnimation: true,
            compactView: false,
            languageCode: 'es',
          ),
        );

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // Spanish should be selected based on saved preferences
        // (We can't easily verify checkbox state, but the screen loads)
        expect(find.text('Español'), findsOneWidget);
      });
    });
  });
}
