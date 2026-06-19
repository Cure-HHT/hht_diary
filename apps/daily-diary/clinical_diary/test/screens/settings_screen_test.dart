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

      // CUR-1438: Color Scheme / dark mode, the Language selector, and the
      // "Larger Text and Controls" toggle are hidden for the Callisto UAT build
      // (gated by AppConfig.showUatRestrictedSettings = false). The underlying
      // preferences + write-path logic are retained, just not shown here.
      testWidgets('hides the color scheme section for UAT (CUR-1438)', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Color Scheme'), findsNothing);
        expect(find.text('Light Mode'), findsNothing);
        expect(find.text('Dark Mode'), findsNothing);
      });

      testWidgets('displays accessibility section (fonts only for UAT)', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Accessibility'), findsOneWidget);
        // CUR-1438: "Larger Text and Controls" is hidden for UAT.
        expect(find.text('Larger Text and Controls'), findsNothing);
      });

      testWidgets('hides the language section for UAT (CUR-1438)', (
        tester,
      ) async {
        setUpTestScreenSize(tester);
        addTearDown(() => resetTestScreenSize(tester));

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsNothing);
        expect(find.text('Español'), findsNothing);
        expect(find.text('Français'), findsNothing);
        expect(find.text('Deutsch'), findsNothing);
      });
    });

    group('Daily Reminder', () {
      // Verifies: DIARY-PRD-notification-yesterday-entry/F
      testWidgets(
        'toggling the daily reminder submits reminder.yesterdayEnabled',
        (tester) async {
          setUpTestScreenSize(tester);
          addTearDown(() => resetTestScreenSize(tester));

          await tester.pumpWidget(buildSettingsScreen());
          await tester.pumpAndSettle();

          final toggle = find.text('Enable daily reminder');
          await tester.scrollUntilVisible(toggle, 200);
          await tester.tap(toggle);
          await tester.pumpAndSettle();

          // Default is enabled → tapping turns it off.
          final s = submissionFor('reminder.yesterdayEnabled');
          expect(s.rawInput['value'], false);
        },
      );
    });
  });
}
