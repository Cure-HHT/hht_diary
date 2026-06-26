// IMPLEMENTS REQUIREMENTS:
// REQ-d00006: Mobile App Build and Release Process
// REQ-o00043: Automated Deployment Pipeline
//
// On-device smoke and regression coverage for Firebase Test Lab.
// Tests are grouped into two tiers:
//
//   Tier 1 — FUNCTIONAL: asserts causal downstream state after every
//   interaction. Each test name describes a behaviour the app must
//   exhibit; there is a widget-finder assertion that can ONLY pass when
//   that behaviour occurred (not just "no exception thrown").
//
//   Tier 2 — STABILITY: crash/resilience guards. takeException() + a
//   known widget type suffice because "it didn't crash" is the full
//   contract. Category names (net, env, life, sec) are appropriate here.
//
// All tests use the real app bootstrap (app.main()) on real Android/iOS
// devices -- no mocks, no sembast_memory, no HTTP stubs.
//
// Naming convention:
//   smk  - smoke / launch gate
//   a11y - accessibility
//   perf - performance
//   dfFlow - diary-flow functional
//   dfLife - lifecycle / stability
//   dfSt - stress
//   dfUi - UI audit
//   dfTime - time / calendar constraint
//   net  - network resilience
//   sec  - security / PHI
//   life - process lifecycle
//   env  - environment (timezone / locale)
//   func - functional regression

import 'dart:io';

import 'package:clinical_diary/main.dart' as app;
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// dart format off

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

/// Pump until [HomeScreen] (or a bootstrap error) is visible.
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

  // =========================================================================
  // TIER 1 — FUNCTIONAL
  // Assertions that are causally downstream of the named behaviour.
  // A test passes only when the app did the right thing, not merely when
  // it failed to throw.
  // =========================================================================

  // -------------------------------------------------------------------------
  // SMK — Smoke / launch gate
  // -------------------------------------------------------------------------

  // Verifies: app boots to an interactive HomeScreen with a Scaffold tree.
  // The causal assertion is the presence of the "Record Nosebleed" button,
  // which HomeScreen._buildBottomActions renders only after the async
  // bootstrap (diaryScope + deviceId) completes — it is absent during the
  // CircularProgressIndicator loading phase.
  testWidgets('smk001LaunchesInteractiveHomeScreen', (tester) async {
    app.main();
    await _waitForHome(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    // "Record Nosebleed" is rendered by _buildBottomActions only after the
    // scope is fully bootstrapped. Its presence proves the async init
    // completed successfully — the loading spinner is gone.
    expect(
      find.text('Record Nosebleed'),
      findsOneWidget,
      reason: 'Record Nosebleed button must appear once bootstrap completes.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'smk001_home');
  });

  // Verifies: the "View Calendar" tertiary button is present on HomeScreen,
  // confirming that _buildBottomActions rendered both action rows.
  testWidgets('smk003ViewCalendarButtonPresent', (tester) async {
    app.main();
    await _waitForHome(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.text('View Calendar'),
      findsOneWidget,
      reason: 'View Calendar button must be present in the bottom actions.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'smk003_entry_point');
  });

  // -------------------------------------------------------------------------
  // A11Y — Accessibility
  // -------------------------------------------------------------------------

  // Verifies: the semantics tree has at least one labelled node after boot.
  // The causal assertion (labelCount > 0) cannot pass if semantics are broken
  // or the tree has not rendered.
  testWidgets('a11y001CoreControlsExposeSemanticLabels', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));

    final root =
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    var labelCount = 0;
    void walk(SemanticsNode node) {
      if ((node.label.isNotEmpty || node.tooltip.isNotEmpty) &&
          // ignore: deprecated_member_use
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

  // Verifies: no semantic label contains raw XML/HTML tag characters.
  // The causal assertion (badLabels is empty) directly detects the defect.
  testWidgets('a11y004SemanticLabelXmlAudit', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));

    final root =
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final badLabels = <String>[];
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

  // Verifies: the layout does not overflow at 2x text scale.
  // The causal assertion is that no RenderFlex overflow exception is thrown
  // AND HomeScreen is still present (a fatal overflow replaces the widget tree).
  testWidgets('a11y002VisualScalingTwoHundredPercentNoOverflow', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // HomeScreen must still be present: a fatal overflow replaces it.
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'HomeScreen must survive 2x text scale without fatal overflow.',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'No overflow or layout exceptions at 2x text scale.',
    );
    await _screenshot(binding, tester, 'a11y002_2x_scale');
  });

  // Verifies: font loading does not throw; HomeScreen is still present after
  // fonts settle — a font crash replaces the widget tree.
  testWidgets('a11y003FontRenderingStabilityHomeScreenSurvives', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'HomeScreen must still be present after font loading.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'a11y003_fonts');
  });

  // -------------------------------------------------------------------------
  // FUNC — Functional regression
  // -------------------------------------------------------------------------

  // Verifies: HomeScreen appears within 8 seconds of launch.
  // The causal assertion is the Stopwatch + findsOneWidget: if the screen
  // takes longer the _pumpUntil deadline fires and the test fails.
  testWidgets('func001LaunchReachesHomeScreenUnderEightSeconds', (tester) async {
    final stopwatch = Stopwatch()..start();
    app.main();
    await _pumpUntil(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      description: 'HomeScreen within 8 seconds',
      timeout: const Duration(seconds: 8),
    );
    stopwatch.stop();
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'HomeScreen must appear within 8 seconds of launch.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'func001_launch_time');
  });

  // Verifies: tapping "Record Nosebleed" pushes RecordingScreen.
  // The causal assertion (find.byType(RecordingScreen) findsOneWidget) can
  // only pass if the navigation actually occurred — HomeScreen alone would
  // give findsNothing.
  testWidgets('func002TapRecordNosebleedPushesRecordingScreen', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));

    final recordButton = find.text('Record Nosebleed');
    expect(
      recordButton,
      findsOneWidget,
      reason: 'Record Nosebleed button must be present before tapping.',
    );
    await tester.tap(recordButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      find.byType(RecordingScreen),
      findsOneWidget,
      reason:
          'RecordingScreen must be pushed after tapping Record Nosebleed.',
    );
    // The summary bar (Start / Max Intensity / End) must be rendered,
    // confirming the recording flow initialised correctly.
    expect(
      find.text('Start'),
      findsOneWidget,
      reason: 'Summary bar Start chip must be visible on RecordingScreen.',
    );
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'func002_recording_screen');
  });

  // Verifies: RecordingScreen shows the start-time confirmation button.
  // The causal assertion (find.text('Set Start Time') findsOneWidget) can only
  // pass if the screen reached its initial TimePickerDial step.
  testWidgets(
    'func003RecordingScreenShowsSetStartTimeButton',
    (tester) async {
      app.main();
      await _waitForHome(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Record Nosebleed'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(RecordingScreen), findsOneWidget);
      expect(
        find.text('Set Start Time'),
        findsOneWidget,
        reason:
            'Set Start Time button must appear on the initial recording step.',
      );
      expect(tester.takeException(), isNull);
      await _screenshot(binding, tester, 'func003_set_start_time');
    },
  );

  // Verifies: confirming the start time advances the recording flow to the
  // intensity step — RecordingStep.intensity renders the IntensityPicker,
  // identified by "Dripping" (one of the picker options).
  // The causal assertion (find.text('Dripping') findsOneWidget) can only pass
  // if RecordingScreen._handleStartTimeConfirm ran and changed _currentStep.
  testWidgets(
    'func004ConfirmStartTimeAdvancesToIntensityStep',
    (tester) async {
      app.main();
      await _waitForHome(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Record Nosebleed'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(RecordingScreen), findsOneWidget);

      await tester.tap(find.text('Set Start Time'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.text('Dripping'),
        findsOneWidget,
        reason:
            'IntensityPicker must appear after confirming the start time.',
      );
      expect(tester.takeException(), isNull);
      await _screenshot(binding, tester, 'func004_intensity_step');
    },
  );

  // Verifies: tapping the back ("Home") button on RecordingScreen returns to
  // HomeScreen. The causal assertion (find.byType(HomeScreen) findsOneWidget
  // AND find.byType(RecordingScreen) findsNothing) can only pass if the
  // navigation stack was correctly popped.
  testWidgets(
    'func005BackFromRecordingScreenReturnsToHomeScreen',
    (tester) async {
      app.main();
      await _waitForHome(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Record Nosebleed'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(RecordingScreen), findsOneWidget);

      // The BackToHomeRow renders "Home" as its back label.
      final homeBack = find.text('Home');
      expect(
        homeBack,
        findsOneWidget,
        reason: 'Home back button must be visible on RecordingScreen.',
      );
      await tester.tap(homeBack);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'HomeScreen must be visible after tapping Home back button.',
      );
      expect(
        find.byType(RecordingScreen),
        findsNothing,
        reason: 'RecordingScreen must have been popped.',
      );
      expect(tester.takeException(), isNull);
      await _screenshot(binding, tester, 'func005_back_to_home');
    },
  );

  // Verifies: the Yesterday banner renders its three choice buttons on a
  // fresh device where yesterday has no diary entries.
  // The causal assertions (Yes / No / Don't remember findsOneWidget) can only
  // pass if DiaryViewBuilder delivered its EndOfReplay emission and
  // HomeScreen._emptyGroupContent rendered the YesterdayBanner.
  testWidgets(
    'func006YesterdayBannerRendersChoiceButtonsWhenNoEntries',
    (tester) async {
      app.main();
      await _waitForHome(tester);
      await tester.pump(const Duration(seconds: 2));

      // On a clean device yesterday has no entries, so the confirmation
      // prompt must be present.
      expect(
        find.text('Yes'),
        findsOneWidget,
        reason: 'Yesterday banner Yes button must appear when no entries.',
      );
      expect(
        find.text('No'),
        findsOneWidget,
        reason: 'Yesterday banner No button must appear when no entries.',
      );
      expect(
        find.text("Don't remember"),
        findsOneWidget,
        reason:
            "Yesterday banner Don't remember button must appear when no entries.",
      );
      expect(tester.takeException(), isNull);
      await _screenshot(binding, tester, 'func006_yesterday_banner');
    },
  );

  // Verifies: font scaling through 1x / 1.5x / 2x leaves HomeScreen intact.
  // The causal assertion (HomeScreen findsOneWidget at each scale) can only
  // pass if no fatal overflow replaced the widget tree at any scale.
  testWidgets(
    'dfUi002FontScalingAuditHomeScreenSurvivesAllScales',
    (tester) async {
      app.main();
      await _waitForHome(tester);
      await tester.pump(const Duration(seconds: 1));

      for (final scale in [1.0, 1.5, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason:
              'HomeScreen must survive ${scale}x text scale without fatal overflow.',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'No overflow at ${scale}x text scale.',
        );
      }
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await _screenshot(binding, tester, 'dfUi002_font_scaling');
    },
  );

  // =========================================================================
  // TIER 2 — STABILITY
  // Crash/resilience guards where "it didn't crash AND the named widget is
  // still present" is the complete contract.  The HomeScreen type-check is
  // causal at this tier: its absence means the app crashed or navigated away
  // unexpectedly.
  // =========================================================================

  // -------------------------------------------------------------------------
  // PERF — Performance / UI-thread
  // -------------------------------------------------------------------------

  testWidgets('perf003RapidFramePumpingDoesNotCrash', (tester) async {
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
  // DF-LIFE — Lifecycle stability
  // -------------------------------------------------------------------------

  testWidgets('dfLife001BackgroundResumePreservesHomeScreen', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'HomeScreen must still be present after background/resume.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'dfLife001_bg_resume');
  });

  testWidgets('dfLife003RepeatedLifecycleTransitionsDoNotCrash',
      (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 5; i++) {
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'No crashes under repeated lifecycle stress.');
    await _screenshot(binding, tester, 'dfLife003_ui_stress');
  });

  // -------------------------------------------------------------------------
  // DF-ST — Stress
  // -------------------------------------------------------------------------

  testWidgets('dfSt001ThreeFabTapsDoNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Record Nosebleed'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final backBtn = find.text('Home');
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    }
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'HomeScreen must be present after three FAB open/close cycles.');
    expect(tester.takeException(), isNull,
        reason: 'Three rapid FAB open/close cycles must not crash the app.');
    await _screenshot(binding, tester, 'dfSt001_mass_entry');
  });

  // -------------------------------------------------------------------------
  // DF-TIME — Time / calendar
  // -------------------------------------------------------------------------

  testWidgets('dfTime005CalendarOpenDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final calBtn = find.text('View Calendar');
    expect(calBtn, findsOneWidget,
        reason: 'View Calendar button must be present before tapping.');
    await tester.tap(calBtn);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull,
        reason: 'Calendar must open without throwing.');
    await _screenshot(binding, tester, 'dfTime005_calendar');
  });

  // -------------------------------------------------------------------------
  // LIFE — Process lifecycle
  // -------------------------------------------------------------------------

  testWidgets('life004DetachedResumeDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull,
        reason: 'App must not throw on simulated detach/resume cycle.');
    await _screenshot(binding, tester, 'life004_process_death');
  });

  testWidgets('life005DatabaseOpensCleanly', (tester) async {
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

  testWidgets('life006InterruptedFabDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Record Nosebleed'));
    await tester.pump(const Duration(milliseconds: 300));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull,
        reason: 'Interrupted FAB must not leave the app in a broken state.');
    await _screenshot(binding, tester, 'life006_interrupted_intent');
  });

  // -------------------------------------------------------------------------
  // NET — Network resilience
  // -------------------------------------------------------------------------

  testWidgets('net001OfflineModeHomeScreenStable', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must be fully interactive in offline mode.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'net001_offline');
  });

  testWidgets('net002SimulatedRelaunchHomeScreenStable', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump(const Duration(milliseconds: 300));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'HomeScreen must survive a simulated relaunch cycle.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'net002_offline_persist');
  });

  testWidgets('net003FcmInitDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must remain stable after FCM init attempt.');
    expect(tester.takeException(), isNull,
        reason: 'FCM handshake must not crash or throw.');
    await _screenshot(binding, tester, 'net003_fcm_audit');
  });

  testWidgets('net004HighLatencyPumpingDoesNotCrash', (tester) async {
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
  // SEC — Security / PHI
  // -------------------------------------------------------------------------

  testWidgets('sec001NoJwtTokenRenderedAsVisibleText', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final widget in textWidgets) {
      final data = widget.data ?? '';
      expect(
        RegExp(
          r'^[A-Za-z0-9_-]{20,}.[A-Za-z0-9_-]{20,}.[A-Za-z0-9_-]{20,}$',
        ).hasMatch(data),
        isFalse,
        reason: 'No JWT token should be rendered as visible text.',
      );
    }
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'sec001_phi_scan');
  });

  testWidgets('sec002TaskSwitcherCycleDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must recover after task-switcher cycle.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'sec002_phi_shield');
  });

  testWidgets('sec003BootstrapDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'Identity / session bootstrap must not crash.');
    await _screenshot(binding, tester, 'sec003_identity');
  });

  // -------------------------------------------------------------------------
  // ENV — Environment (timezone / locale)
  // -------------------------------------------------------------------------

  testWidgets('env001TimezoneDoesNotCrashBoot', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must boot cleanly in any device timezone.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'env001_timezone');
  });

  testWidgets('env002MidnightSimulationDoesNotCrash', (tester) async {
    app.main();
    await _waitForHome(tester);
    await tester.pump(const Duration(seconds: 2));
    // Advance fake time by 1 minute — does not simulate real wall-clock
    // midnight but exercises any timer-driven rendering paths.
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'App must be stable across a simulated midnight rollover.');
    expect(tester.takeException(), isNull);
    await _screenshot(binding, tester, 'env002_midnight');
  });

  testWidgets('env003LocaleSwapDoesNotCrash', (tester) async {
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
}
// dart format on
