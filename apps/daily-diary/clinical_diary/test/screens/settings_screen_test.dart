// Verifies: DIARY-DEV-action-write-path/A — settings toggles submit
//   `set_user_setting` through the scope's actionSubmitter.
// Verifies: DIARY-DEV-reactive-read-path/A — the screen renders the values
//   provided by the settings projection (via AppPreferencesScope).

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  group('SettingsScreen', () {
    late FakeReaction fake;

    setUp(() {
      fake = FakeReaction();
    });

    tearDown(() async {
      await fake.dispose();
    });

    /// Mount the screen under [ReActionScope] + [AppPreferencesScope] with the
    /// given current [prefs]. Every submit() needs a queued result, so prime a
    /// generous run of successes.
    Widget buildSettingsScreen({
      UserPreferences prefs = const UserPreferences(),
    }) {
      for (var i = 0; i < 10; i++) {
        fake.queueDispatchResult(
          const DispatchSuccess<Object?>('ok', <String>[]),
        );
      }
      return ReActionScope(
        scope: fake,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppPreferencesScope(
            preferences: prefs,
            child: const SettingsScreen(),
          ),
        ),
      );
    }

    void setUpTestScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
    }

    void resetTestScreenSize(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    /// The single `set_user_setting` submission for [key], or fails if none.
    ActionSubmission submissionFor(String key) {
      return fake.submittedActions.firstWhere(
        (s) => s.actionName == 'set_user_setting' && s.rawInput['key'] == key,
        orElse: () => fail('no set_user_setting submitted for $key'),
      );
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
    });

    group('Reflects driven preferences', () {
      testWidgets('renders the larger-text checkbox as checked when set on', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(
          buildSettingsScreen(
            prefs: const UserPreferences(largerTextAndControls: true),
          ),
        );
        await tester.pumpAndSettle();

        // First checkbox is the larger-text option.
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
        expect(checkbox.value, isTrue);
      });
    });

    group('Color Scheme Interaction', () {
      testWidgets(
        'submits set_user_setting(pref.darkMode, false) on Light Mode',
        (tester) async {
          setUpTestScreenSize(tester);
          addTearDown(() => resetTestScreenSize(tester));

          await tester.pumpWidget(buildSettingsScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Light Mode'));
          await tester.pumpAndSettle();

          final s = submissionFor(prefDarkMode);
          expect(s.rawInput['value'], false);
        },
      );
    });

    group('Accessibility Options', () {
      testWidgets('toggling larger text submits set_user_setting', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();

        final s = submissionFor(prefLargerText);
        expect(s.rawInput['value'], true);
      });
    });

    group('Language Selection', () {
      testWidgets('selecting Spanish submits pref.languageCode=es', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();

        final s = submissionFor(prefLanguageCode);
        expect(s.rawInput['value'], 'es');
      });

      testWidgets('selecting French submits pref.languageCode=fr', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Français'));
        await tester.pumpAndSettle();

        final s = submissionFor(prefLanguageCode);
        expect(s.rawInput['value'], 'fr');
      });

      testWidgets('selecting German submits pref.languageCode=de', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Deutsch'));
        await tester.pumpAndSettle();

        final s = submissionFor(prefLanguageCode);
        expect(s.rawInput['value'], 'de');
      });
    });
  });
}
