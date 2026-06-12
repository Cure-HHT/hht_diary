import 'package:clinical_diary/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('mobile QA smoke automation', () {
    testWidgets('SMK-001 launches to an interactive screen', (tester) async {
      await _launchAndPrepare(tester);

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await binding.takeScreenshot('SMK-001_launch');
    });

    testWidgets('SMK-003 reaches dashboard or enrollment entry point', (
      tester,
    ) async {
      await _launchAndPrepare(tester);

      final expectedEntryPoints = <Finder>[
        find.text('Nosebleed Diary'),
        find.bySemanticsLabel('Nosebleed Diary'),
        find.bySemanticsLabel('Record Nosebleed'),
        find.textContaining('Clinical Trial'),
        find.textContaining('link', findRichText: true),
      ];

      final matched = expectedEntryPoints.any(tester.any);
      expect(
        matched,
        isTrue,
        reason:
            'Expected dashboard, record action, or enrollment entry point after launch.',
      );

      await binding.takeScreenshot('SMK-003_home_or_enrollment');
    });

    testWidgets('A11Y-001 core controls expose semantic labels', (
      tester,
    ) async {
      await _launchAndPrepare(tester);

      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      final coreLabels = <String>[
        'App menu',
        'User menu',
        'Record Nosebleed',
        'Calendar',
      ];
      final visibleCoreLabels = coreLabels
          .where((label) => tester.any(find.bySemanticsLabel(label)))
          .toList();

      expect(
        visibleCoreLabels,
        isNotEmpty,
        reason:
            'At least one core dashboard control should be exposed in the semantics tree.',
      );

      await binding.takeScreenshot('A11Y-001_semantics');
    });

    testWidgets('PERF-003 rapid core navigation does not crash', (
      tester,
    ) async {
      await _launchAndPrepare(tester);

      for (var i = 0; i < 5; i++) {
        await _tapIfPresent(tester, find.bySemanticsLabel('Calendar'));
        await _settleForQa(tester);
        await _returnToDashboardIfPossible(tester);

        await _tapIfPresent(tester, find.bySemanticsLabel('App menu'));
        await _settleForQa(tester);
        await _tapIfPresent(tester, find.bySemanticsLabel('Dismiss menu'));
        await _settleForQa(tester);

        await _tapIfPresent(tester, find.bySemanticsLabel('User menu'));
        await _settleForQa(tester);
        await _returnToDashboardIfPossible(tester);
      }

      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('PERF-003_navigation_stress');
    });
  });
}

Future<void> _launchAndPrepare(WidgetTester tester) async {
  app.main();
  await _settleForQa(tester, pumps: 16);
  await _dismissYesterdayPromptIfPresent(tester);
}

Future<void> _settleForQa(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 250),
  int pumps = 8,
}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(step);
  }
}

Future<void> _dismissYesterdayPromptIfPresent(WidgetTester tester) async {
  if (!tester.any(find.textContaining('Did you have nosebleeds?'))) return;

  final noButton = find.text('No');
  final dontRememberButton = find.text("Don't remember");
  if (tester.any(noButton)) {
    await tester.tap(noButton.first, warnIfMissed: false);
  } else if (tester.any(dontRememberButton)) {
    await tester.tap(dontRememberButton.first, warnIfMissed: false);
  }
  await _settleForQa(tester);
}

Future<void> _tapIfPresent(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return;
  await tester.tap(finder.first, warnIfMissed: false);
}

Future<void> _returnToDashboardIfPossible(WidgetTester tester) async {
  await _tapIfPresent(tester, find.byTooltip('Back'));
  await _tapIfPresent(tester, find.byIcon(Icons.arrow_back));
  await _tapIfPresent(tester, find.textContaining('Back'));
  await _settleForQa(tester);
  await _dismissYesterdayPromptIfPresent(tester);
}
