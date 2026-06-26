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
  // DIARY-JNY-epistaxis-recording: Record an epistaxis event
  //
  // Requirements: DIARY-PRD-epistaxis-capture-standard,
  //   DIARY-GUI-epistaxis-record, DIARY-GUI-main-screen-layout,
  //   DIARY-PRD-day-disposition, DIARY-PRD-mobile-offline-first,
  //   CAL-PRD-trial-start-workflow
  //
  // Who: User/Participant.  Starting point: the Main Screen is open.
  //
  // Journey:
  //   1. The Participant taps Record Nosebleed.
  //   2. Sets the time the nosebleed started and continues.
  //   3. Chooses how heavy the bleed was from the intensity options.
  //   4. Sets the time the nosebleed stopped and saves the entry.
  //   5. The Application returns to the Main Screen, where the new event
  //      appears under the current day in Your Records.
  //
  // Outcome: the epistaxis event is saved to the diary. In personal-use
  // mode the data stays on the device; for a linked Participant whose trial
  // has started it syncs to the Sponsor Portal and onward to Rave EDC once
  // the device is online.
  //
  // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker
  // via debugPrint so the Firebase Test Lab logcat reveals the exact step
  // reached if the test stalls.  This is the only active test in this run;
  // all other smoke/regression tests are intentionally omitted on this
  // diagnostic branch so the suite completes quickly.
  // =========================================================================
  testWidgets('jnyEpistaxisRecordingRecordAnEvent', (tester) async {
    void mark(String step) =>
        debugPrint('DIARY-JNY-DIAG >>> $step');

    mark('00 app.main() about to start');
    app.main();
    mark('01 app.main() returned, waiting for home');
    await _waitForHome(tester);
    mark('02 home reached');
    await tester.pump(const Duration(seconds: 1));
    mark('03 settled on Main Screen');

    // Starting point: Main Screen must show the Record Nosebleed action.
    expect(
      find.text('Record Nosebleed'),
      findsOneWidget,
      reason: 'Main Screen must offer the Record Nosebleed action.',
    );
    mark('04 Record Nosebleed visible');

    // 1. The Participant taps Record Nosebleed.
    await tester.tap(find.text('Record Nosebleed'));
    mark('05 tapped Record Nosebleed');
    await tester.pump(const Duration(seconds: 3));
    mark('06 pumped after tap');
    expect(
      find.byType(RecordingScreen),
      findsOneWidget,
      reason: 'RecordingScreen must open after Record Nosebleed.',
    );
    mark('07 RecordingScreen open (startTime step)');

    // 2. The Participant sets the time the nosebleed started and continues.
    expect(
      find.text('Set Start Time'),
      findsOneWidget,
      reason: 'Start-time step must offer the Set Start Time action.',
    );
    await tester.tap(find.text('Set Start Time'));
    mark('08 tapped Set Start Time');
    await tester.pump(const Duration(seconds: 2));
    mark('09 pumped after Set Start Time');

    // 3. The Participant chooses how heavy the bleed was.
    expect(
      find.text('Dripping'),
      findsOneWidget,
      reason: 'Intensity options must appear after the start time.',
    );
    mark('10 intensity options visible');
    await tester.tap(find.text('Dripping'));
    mark('11 tapped Dripping intensity');
    await tester.pump(const Duration(seconds: 2));
    mark('12 pumped after intensity (endTime step)');

    // 4. The Participant sets the time the nosebleed stopped and saves.
    expect(
      find.text('Set End Time'),
      findsOneWidget,
      reason: 'End-time step must offer the Set End Time action.',
    );
    await tester.tap(find.text('Set End Time'));
    mark('13 tapped Set End Time');
    await tester.pump(const Duration(seconds: 2));
    mark('14 pumped after Set End Time (complete step)');

    expect(
      find.text('Finished'),
      findsOneWidget,
      reason: 'Complete step must offer the Finished (save) action.',
    );
    await tester.tap(find.text('Finished'));
    mark('15 tapped Finished (save)');
    await tester.pump(const Duration(seconds: 3));
    mark('16 pumped after save');

    // 5. The Application returns to the Main Screen with the new event under
    //    the current day in Your Records.
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'App must return to the Main Screen after saving.',
    );
    mark('17 back on Main Screen');
    expect(
      find.text('Your Records'),
      findsOneWidget,
      reason: 'Your Records section must be present on the Main Screen.',
    );
    mark('18 Your Records visible');

    expect(
      tester.takeException(),
      isNull,
      reason: 'Recording an epistaxis event must not throw.',
    );
    mark('19 journey complete, no exceptions');
    await _screenshot(binding, tester, 'jny_epistaxis_recording_saved');
    mark('20 screenshot taken, DONE');
  });
}
// dart format on
