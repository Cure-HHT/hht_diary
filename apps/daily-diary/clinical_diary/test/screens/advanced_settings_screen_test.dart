// Verifies: DIARY-DEV-action-write-path/A — Advanced controls submit
//   `set_user_setting` for the clinical.* keys through the scope.
// Verifies: DIARY-DEV-reactive-read-path/A — controls reflect the ClinicalRules
//   provided by ClinicalRulesScope.
import 'package:clinical_diary/screens/advanced_settings_screen.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdvancedSettingsScreen', () {
    late FakeReaction fake;

    setUp(() {
      fake = FakeReaction();
      for (var i = 0; i < 10; i++) {
        fake.queueDispatchResult(
          const DispatchSuccess<Object?>('ok', <String>[]),
        );
      }
    });

    tearDown(() async => fake.dispose());

    Future<void> pump(
      WidgetTester tester, {
      ClinicalRules rules = const ClinicalRules(),
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ReActionScope(
          scope: fake,
          child: wrapWithMaterialApp(
            ClinicalRulesScope(
              rules: rules,
              child: const AdvancedSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ActionSubmission submissionFor(String key) =>
        fake.submittedActions.firstWhere(
          (s) => s.actionName == 'set_user_setting' && s.rawInput['key'] == key,
          orElse: () => fail('no set_user_setting for $key'),
        );

    testWidgets('toggling short-duration confirm writes the user setting', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Confirm very short nosebleeds'));
      await tester.pumpAndSettle();
      expect(submissionFor(shortDurationConfirmKey).rawInput['value'], true);
    });

    testWidgets('toggling review screen writes the user setting', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Show a review step before saving'));
      await tester.pumpAndSettle();
      expect(submissionFor(useReviewScreenKey).rawInput['value'], true);
    });

    testWidgets('selecting a justification age writes the hours', (
      tester,
    ) async {
      await pump(tester);
      // Open the justification dropdown (currently "Off") and pick "1 day" (24h).
      final dropdown = find.descendant(
        of: find.widgetWithText(ListTile, 'Require a reason for late entries'),
        matching: find.byType(DropdownButton<int?>),
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 day').last);
      await tester.pumpAndSettle();
      expect(
        submissionFor(justificationThresholdHoursKey).rawInput['value'],
        24,
      );
    });

    testWidgets('sponsor-locked key is read-only (no write on tap)', (
      tester,
    ) async {
      await pump(
        tester,
        rules: const ClinicalRules(lockedKeys: {shortDurationConfirmKey}),
      );
      // The locked note is shown, and tapping the locked control writes nothing.
      expect(find.textContaining('Set by your study'), findsOneWidget);
      await tester.tap(find.text('Confirm very short nosebleeds'));
      await tester.pumpAndSettle();
      expect(
        fake.submittedActions.where(
          (s) =>
              s.actionName == 'set_user_setting' &&
              s.rawInput['key'] == shortDurationConfirmKey,
        ),
        isEmpty,
      );
    });

    testWidgets('reflects current rules (long-duration shows the threshold)', (
      tester,
    ) async {
      await pump(
        tester,
        rules: const ClinicalRules(
          longDurationConfirm: true,
          longDurationThresholdMinutes: 240,
        ),
      );
      // The long-duration dropdown shows "4 hours" for 240 minutes.
      expect(find.text('4 hours'), findsOneWidget);
    });
  });
}
