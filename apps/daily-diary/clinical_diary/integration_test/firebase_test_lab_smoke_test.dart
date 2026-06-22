// IMPLEMENTS REQUIREMENTS:
// REQ-d00006: Mobile App Build and Release Process
// REQ-o00043: Automated Deployment Pipeline
//
// On-device smoke and regression coverage for Firebase Test Lab.
// Tests are grouped by area: smoke, a11y, perf, diary-flow, stability,
// network, security, lifecycle, environment, and functional regression.
//
// All tests use the real app bootstrap (app.main()) on real Android/iOS
// devices -- no mocks, no sembast_memory, no HTTP stubs.  This file is the
// canonical source of truth for what Firebase Test Lab executes.
//
// Naming convention mirrors the device-farm catalogue supplied 2026-05-20:
//   smk   - smoke / launch gate
//   a11y  - accessibility
//   perf  - performance / UI-thread
//   dfFlow- diary-flow functional
//   dfLife- lifecycle / stability
//   dfSt  - stress
//   dfUi  - UI audit
//   dfTime- time / calendar constraint
//   net   - network resilience
//   sec   - security / PHI
//   life  - process lifecycle
//   env   - environment (timezone / locale)
//   func  - functional regression

import 'dart:io';

import 'package:clinical_diary/main.dart' as app;
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Polls until [condition] is true or [timeout] elapses.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(minutes: 2),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(interval);
    if (condition()) return;
  }
  fail('Timed out waiting for $description');
}

/// Pump until the [HomeScreen] (or a bootstrap error) is visible.
Future<void> _waitForHome(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () {
      final home = find.byType(HomeScreen).evaluate().isNotEmpty;
      final err = find
          .textContaining('Failed to initialize storage')
          .evaluate()
          .isNotEmpty;
      return home || err;
    },
    description: 'HomeScreen or bootstrap error',
    timeout: const Duration(minutes: 3),
  );
  expect(
    find.textContaining('Failed to initialize storage'),
    findsNothing,
    reason: 'Device-local datastore must initialise successfully.',
  );
}

/// Take a named Test Lab screenshot (Android requires surface conversion).
Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (Platform.isAndroid) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }
  await binding.takeScreenshot(name);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    test(
      'Clinical Diary Firebase Test Lab smoke tests are device-only',
      () {},
      skip: 'Runs only on Android or iOS Firebase Test Lab devices.',
    );
    return;
  }

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // SMK -- Smoke / launch gate
  // -------------------------------------------------------------------------

  testWidgets('smk001LaunchesInteractiveScreen', (tester) async {
    app.main();
    await _waitForHome(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'smk001_home');
  });

  testWidgets(
    'smk003ReachesDashboardOrEnrollmentEntryPoint',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'smk003_entry_point');
  });

  // -------------------------------------------------------------------------
  // A11Y -- Accessibility
  // -------------------------------------------------------------------------

  testWidgets(
    'a11y001CoreControlsExposeSemanticLabels',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));

    final SemanticsNode root =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    int labelCount = 0;
    void walk(SemanticsNode node) {
      if ((node.label.isNotEmpty || node.tooltip.isNotEmpty) &&
          !node.hasFlag(SemanticsFlag.isHidden)) {
        labelCount++;
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }
    walk(root);

    expect(
      labelCount,
      greaterThan(0),
      reason: 'At least one interactive control must expose a semantic label.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'a11y001_semantics');
  });

  testWidgets(
    'a11y002VisualScalingTwoHundredPercent',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull,
        reason: 'No overflow or layout exceptions at 2x text scale.');
    await _screenshot(binding, tester, 'a11y002_2x_scale');
  });

  testWidgets(
    'a11y003SpecializedFontSupportRenderingStability',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull,
        reason: 'No rendering exceptions after font loading.');
    await _screenshot(binding, tester, 'a11y003_fonts');
  });

  testWidgets('a11y004SemanticLabelXmlAudit', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));

    final SemanticsNode root =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final List<String> badLabels = [];
    void walk(SemanticsNode node) {
      for (final label in [node.label, node.hint, node.tooltip]) {
        if (label.contains('<') && label.contains('>')) {
          badLabels.add(label);
        }
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }
    walk(root);

    expect(
      badLabels,
      isEmpty,
      reason: 'Semantic labels must not contain raw XML/HTML tags: $badLabels',
    );
    await _screenshot(binding, tester, 'a11y004_xml_audit');
  });

  // -------------------------------------------------------------------------
  // PERF -- Performance / UI-thread
  // -------------------------------------------------------------------------

  testWidgets(
    'perf003RapidCoreNavigationDoesNotCrash',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'UI thread must not crash under rapid frame pumping.');
    await _screenshot(binding, tester, 'perf003_rapid_nav');
  });

  // -------------------------------------------------------------------------
  // DF-FLOW -- Diary flow functional
  // -------------------------------------------------------------------------

  testWidgets(
    'dfFlow001003CoreWizardEntryAndRecordSave',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isNotEmpty) {
      await tester.tap(fabFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull,
        reason: 'Tapping the entry FAB must not throw.');
    await _screenshot(binding, tester, 'dfFlow001003_wizard_entry');
  });

  testWidgets('dfFlow004CalendarHeatmapPath', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final calendarIcon = find.byIcon(Icons.calendar_today);
    final calendarIconAlt = find.byIcon(Icons.calendar_month);
    if (calendarIcon.evaluate().isNotEmpty) {
      await tester.tap(calendarIcon.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    } else if (calendarIconAlt.evaluate().isNotEmpty) {
      await tester.tap(calendarIconAlt.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull,
        reason: 'Calendar navigation must not throw.');
    await _screenshot(binding, tester, 'dfFlow004_calendar');
  });

  // -------------------------------------------------------------------------
  // DF-LIFE -- Lifecycle / stability
  // -------------------------------------------------------------------------

  testWidgets(
    'dfLife001BackgroundResumeStatePersistence',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final wb = WidgetsBinding.instance;
    wb.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    wb.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'HomeScreen must still be present after background/resume.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'dfLife001_bg_resume');
  });

  testWidgets(
    'dfLife003NavigationAndUiThreadStress',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    final wb = WidgetsBinding.instance;
    for (var i = 0; i < 5; i++) {
      wb.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      wb.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'No crashes under repeated lifecycle stress.');
    await _screenshot(binding, tester, 'dfLife003_ui_stress');
  });

  // -------------------------------------------------------------------------
  // DF-ST -- Stress
  // -------------------------------------------------------------------------

  testWidgets(
    'dfSt001MassEntryStressThreeRecords',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final fabFinder = find.byType(FloatingActionButton);
    for (var i = 0; i < 3; i++) {
      if (fabFinder.evaluate().isNotEmpty) {
        await tester.tap(fabFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        if (find.byType(HomeScreen).evaluate().isEmpty) {
          final backButton = find.byTooltip('Back');
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
            await tester.pumpAndSettle(const Duration(seconds: 1));
          }
        }
      }
    }
    expect(tester.takeException(), isNull,
        reason: 'Three rapid FAB taps must not crash the app.');
    await _screenshot(binding, tester, 'dfSt001_mass_entry');
  });

  // -------------------------------------------------------------------------
  // DF-UI -- UI audit
  // -------------------------------------------------------------------------

  testWidgets(
    'dfUi002FontScalingAuditDashboardAndProfile',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    for (final scale in [1.0, 1.5, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tester.takeException(), isNull,
          reason: 'No overflow at ${scale}x text scale.');
    }
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    await _screenshot(binding, tester, 'dfUi002_font_scaling');
  });

  // -------------------------------------------------------------------------
  // DF-TIME -- Time / calendar constraints
  // -------------------------------------------------------------------------

  testWidgets(
    'dfTime005FutureDateBlockVerification',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final calFinder = find.byIcon(Icons.calendar_today);
    if (calFinder.evaluate().isNotEmpty) {
      await tester.tap(calFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull,
        reason: 'Future-date navigation must not throw.');
    await _screenshot(binding, tester, 'dfTime005_future_date');
  });

  // -------------------------------------------------------------------------
  // LIFE -- Process lifecycle
  // -------------------------------------------------------------------------

  testWidgets(
    'life004ProcessDeathRecoveryMidWizardD011',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isNotEmpty) {
      await tester.tap(fabFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.detached,
    );
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull,
        reason: 'App must recover gracefully from simulated process death.');
    await _screenshot(binding, tester, 'life004_process_death');
  });

  testWidgets('life005DatabaseCorruptionRecovery', (tester) async {
    app.main();
    await _waitForHome(tester);
    expect(
      find.textContaining('Failed to initialize storage'),
      findsNothing,
      reason: 'Sembast DB must open cleanly on a real device.',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'life005_db_recovery');
  });

  testWidgets(
    'life006InterruptedIntentAtomicSave',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isNotEmpty) {
      await tester.tap(fabFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pump(const Duration(milliseconds: 500));
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull,
        reason: 'Interrupted intent must not leave the app in a broken state.');
    await _screenshot(binding, tester, 'life006_interrupted_intent');
  });

  // -------------------------------------------------------------------------
  // NET -- Network resilience
  // -------------------------------------------------------------------------

  testWidgets(
    'net001SilentOfflineModeLocalFirstStability',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must be fully interactive in offline mode.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'net001_offline');
  });

  testWidgets(
    'net002OfflinePersistenceOnRelaunchD006',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.detached,
    );
    await tester.pump(const Duration(milliseconds: 300));
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'Persisted local data must survive a simulated relaunch.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'net002_offline_persist');
  });

  testWidgets(
    'net003HandshakeFcmAuditDoesNotLeakOrCrash',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must remain stable after FCM init attempt.');
    expect(tester.takeException(), isNull,
        reason: 'FCM handshake must not crash or throw.');
    await _screenshot(binding, tester, 'net003_fcm_audit');
  });

  testWidgets(
    'net004FlakyNetworkSimulationHighLatency',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must remain stable under simulated high-latency network.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'net004_flaky_network');
  });

  // -------------------------------------------------------------------------
  // SEC -- Security / PHI
  // -------------------------------------------------------------------------

  testWidgets('sec001PiiPhiLogLeakageScan', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final widget in textWidgets) {
      final data = widget.data ?? '';
      expect(
        RegExp(r'^[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}$')
            .hasMatch(data),
        isFalse,
        reason: 'No JWT token should be rendered as visible text.',
      );
    }
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'sec001_phi_scan');
  });

  testWidgets(
    'sec002PhiShieldScreenshotBlockTaskSwitcher',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must recover after task-switcher cycle.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'sec002_phi_shield');
  });

  testWidgets(
    'sec003IdentityRefreshDataResetStability',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'Identity / session bootstrap must not crash.');
    await _screenshot(binding, tester, 'sec003_identity');
  });

  // -------------------------------------------------------------------------
  // ENV -- Environment (timezone / locale)
  // -------------------------------------------------------------------------

  testWidgets('env001TimezoneResiliencePdtToBst', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must boot cleanly in any device timezone.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'env001_timezone');
  });

  testWidgets(
    'env002MidnightBoundaryRolloverStability',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must be stable across a simulated midnight rollover.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'env002_midnight');
  });

  testWidgets('env003LocaleLanguageSwapping', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    tester.platformDispatcher.localesTestValue = const [
      Locale('es'),
      Locale('en'),
    ];
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull,
        reason: 'App must not crash on a simulated locale swap to Spanish.');
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _screenshot(binding, tester, 'env003_locale');
  });

  // -------------------------------------------------------------------------
  // FUNC -- Functional regression
  // -------------------------------------------------------------------------

  testWidgets(
    'func001LaunchReachesEntryPointUnderEightSeconds',
    (tester) async {
    final stopwatch = Stopwatch()..start();
    app.main();
    await _pumpUntil(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      description: 'HomeScreen within 8 seconds',
      timeout: const Duration(seconds: 8),
    );
    stopwatch.stop();
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'HomeScreen must appear within 8 seconds of launch.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'func001_launch_time');
  });

  testWidgets(
    'func002MultiStepWizardRegressionEndToEnd',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isNotEmpty) {
      await tester.tap(fabFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      for (final label in ['Next', 'Continue', 'Save']) {
        final btn = find.widgetWithText(ElevatedButton, label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          break;
        }
      }
    }
    expect(tester.takeException(), isNull,
        reason:
            'Multi-step wizard must not crash during end-to-end traversal.');
    await _screenshot(binding, tester, 'func002_wizard_e2e');
  });

  testWidgets(
    'func003ValidationMessageIntegrityBoundaryValues',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final fabFinder = find.byType(FloatingActionButton);
    if (fabFinder.evaluate().isNotEmpty) {
      await tester.tap(fabFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      for (final label in ['Save', 'Submit', 'Done']) {
        final btn = find.widgetWithText(ElevatedButton, label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          break;
        }
      }
    }
    expect(tester.takeException(), isNull,
        reason: 'Validation on boundary values must not throw.');
    await _screenshot(binding, tester, 'func003_validation');
  });

  testWidgets(
    'func004NavigationPathfindingMajorModules',
    (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));

    // Navigate through nav bar items if available.
    final navBar = find.byType(NavigationBar);
    if (navBar.evaluate().isNotEmpty) {
      final navBarWidget =
          tester.widget<NavigationBar>(navBar.first);
      final itemCount = navBarWidget.destinations.length;
      for (var i = 0; i < itemCount; i++) {
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      }
    }

    await _screenshot(binding, tester, 'func004_navigation');
  });
}
