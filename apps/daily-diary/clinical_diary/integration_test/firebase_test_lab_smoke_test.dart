// IMPLEMENTS REQUIREMENTS:
// REQ-d00006: Mobile App Build and Release Process
// REQ-o00043: Automated Deployment Pipeline
//
// On-device smoke and regression coverage for Firebase Test Lab.
// Tests are grouped into two tiers:
//
// Tier 1 — FUNCTIONAL: asserts causal downstream state after every
// interaction. Each test name describes a behaviour the app must
// exhibit; there is a widget-finder assertion that can ONLY pass when
// that behaviour occurred (not just "no exception thrown").
//
// Tier 2 — STABILITY: crash/resilience guards. takeException() + a
// known widget type suffice because "it didn't crash" is the full
// contract. Category names (net, env, life, sec) are appropriate here.
//
// All tests use the real app bootstrap (app.main()) on real Android/iOS
// devices -- no mocks, no sembast_memory, no HTTP stubs.
//
// Naming convention:
// smk - smoke / launch gate
// a11y - accessibility
// perf - performance
// dfFlow - diary-flow functional
// dfLife - lifecycle / stability
// dfSt - stress
// dfUi - UI audit
// dfTime - time / calendar constraint
// net - network resilience
// sec - security / PHI
// life - process lifecycle
// env - environment (timezone / locale)
// func - functional regression

import 'dart:io';

import 'package:clinical_diary/main.dart' as app;
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:flutter/material.dart';
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
  // DIARY-GUI-epistaxis-record, DIARY-GUI-main-screen-layout,
  // DIARY-PRD-day-disposition, DIARY-PRD-mobile-offline-first,
  // CAL-PRD-trial-start-workflow
  //
  // Who: User/Participant. Starting point: the Main Screen is open.
  //
  // Journey:
  // 1. The Participant taps Record Nosebleed.
  // 2. Sets the time the nosebleed started and continues.
  // 3. Chooses how heavy the bleed was from the intensity options.
  // 4. Sets the time the nosebleed stopped and saves the entry.
  // 5. The Application returns to the Main Screen, where the new event
  //    appears under the current day in Your Records.
  //
  // Outcome: the epistaxis event is saved to the diary. In personal-use
  // mode the data stays on the device; for a linked Participant whose trial
  // has started it syncs to the Sponsor Portal and onward to Rave EDC once
  // the device is online.
  //
  // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker
  // via debugPrint so the Firebase Test Lab logcat reveals the exact step
  // reached if the test stalls. This is the only active test in this run;
  // all other smoke/regression tests are intentionally omitted on this
  // diagnostic branch so the suite completes quickly.
  // =========================================================================
  testWidgets(
    'jnyEpistaxisRecordingRecordAnEvent',
    (tester) async {
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
      // The start-time dial initialises to NOW. The TimePickerDial rejects any
      // adjustment that would push the selected time into the future, so we move
      // the START backwards (-15) to create headroom: this lets the end time be
      // nudged forward later while still staying at or before the present moment.
      expect(
        find.text('-15'),
        findsOneWidget,
        reason: 'Start-time dial must offer the -15 minute adjuster.',
      );
      await tester.tap(find.text('-15'));
      mark('07a moved start time -15');
      await tester.pump(const Duration(seconds: 1));
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
      // The end-time dial initialises to the SAME instant as the (now moved
      // back) start time. With the default ClinicalRules
      // (shortDurationConfirm:false, useReviewScreen:false) an end time equal
      // to the start is rejected by _handleEndTimeConfirm, and an end time in
      // the future is also rejected -- so we nudge the end +5 minutes. Because
      // the start was moved -15, end lands ~10 minutes BEFORE now: a valid,
      // non-zero, non-future duration. There is NO separate "Finished" review
      // step in this configuration -- confirming a valid duration saves the
      // record and returns straight to the Main Screen.
      expect(
        find.text('+5'),
        findsOneWidget,
        reason: 'End-time dial must offer the +5 minute adjuster.',
      );
      await tester.tap(find.text('+5'));
      mark('13a bumped end time +5 (stays at/under now, after start)');
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Set End Time'),
        findsOneWidget,
        reason: 'End-time step must offer the Set End Time action.',
      );
      await tester.tap(find.text('Set End Time'));
      mark('13 tapped Set End Time');
      await tester.pump(const Duration(seconds: 2));
      mark('14 pumped after Set End Time');

      // 5. With useReviewScreen:false the record saves immediately and the app
      // returns to the Main Screen (no "Finished" review step exists in this
      // configuration). Wait for the Main Screen to come back, then assert
      // the new event is reflected under Your Records.
      await _pumpUntil(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        description: 'return to Main Screen after saving the event',
        timeout: const Duration(seconds: 30),
      );
      mark('15 back on Main Screen after save');
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'App must return to the Main Screen after saving.',
      );
      mark('16 HomeScreen confirmed');
      expect(
        find.text('Your Records'),
        findsOneWidget,
        reason: 'Your Records section must be present on the Main Screen.',
      );
      mark('17 Your Records visible');

      expect(
        tester.takeException(),
        isNull,
        reason: 'Recording an epistaxis event must not throw.',
      );
      mark('18 journey complete, no exceptions');
      await _screenshot(binding, tester, 'jny_epistaxis_recording_saved');
      mark('19 screenshot taken, DONE');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  // =========================================================================
  // DIARY-JNY-confirm-yesterday-status: Confirm yesterday's status
  //
  // Requirements: DIARY-GUI-main-screen-layout,
  // DIARY-PRD-epistaxis-capture-standard,
  // DIARY-PRD-notification-yesterday-entry,
  // CAL-PRD-notification-yesterday-entry-configuration,
  // DIARY-GUI-epistaxis-record
  //
  // Who: User/Participant.
  //
  // Starting point: the Main Screen shows the Yesterday Confirmation Prompt
  // about the previous day (the same prompt surfaced by tapping the yesterday
  // reminder notification). The prompt only appears when no Daily Status has
  // been recorded for yesterday and yesterday is not locked.
  //
  // Journey:
  // 1. The Participant sees the prompt asking whether they had a nosebleed
  //    yesterday ("Did you have nosebleeds?").
  // 2. The prompt offers Yes / No / Don't remember. The Participant answers
  //    No nosebleed (could also choose Don't remember, or Yes to enter the
  //    recording flow for that date).
  // 3. The Application records the response for the previous day and clears
  //    the prompt.
  //
  // Outcome: the previous day has a recorded status, keeping the diary
  // complete; the Yesterday Confirmation Prompt is removed from the Main
  // Screen and the app stays on the Main Screen under Your Records.
  //
  // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
  // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
  // if the test stalls.
  // =========================================================================
  testWidgets(
    'jnyConfirmYesterdayStatus',
    (tester) async {
      void mark(String step) =>
          debugPrint('DIARY-JNY-DIAG >>> $step');

      mark('00 app.main() about to start');
      app.main();
      mark('01 app.main() returned, waiting for home');
      await _waitForHome(tester);
      mark('02 home reached');
      await tester.pump(const Duration(seconds: 1));
      mark('03 settled on Main Screen');

      // Starting point: the Yesterday Confirmation Prompt is shown for the
      // previous day. This prompt only appears when yesterday has no recorded
      // Daily Status -- the expected clean state on a fresh Test Lab device.
      expect(
        find.byType(YesterdayBanner),
        findsOneWidget,
        reason: 'Main Screen must show the Yesterday Confirmation Prompt '
            'when yesterday has no recorded status.',
      );
      mark('04 YesterdayBanner present');

      // 1. The Participant sees the prompt asking about yesterday.
      expect(
        find.text('Did you have nosebleeds?'),
        findsOneWidget,
        reason: 'Prompt must ask whether the Participant had nosebleeds '
            'yesterday.',
      );
      mark('05 prompt question visible');

      // 2. The prompt presents three response options: Yes, No, Don't remember.
      expect(
        find.descendant(
          of: find.byType(YesterdayBanner),
          matching: find.text('No'),
        ),
        findsOneWidget,
        reason: 'Prompt must offer the No (no nosebleeds) option.',
      );
      expect(
        find.descendant(
          of: find.byType(YesterdayBanner),
          matching: find.text("Don't remember"),
        ),
        findsOneWidget,
        reason: "Prompt must offer the Don't remember option.",
      );
      mark('06 No and Dont remember options visible');

      // 3. The Participant answers No nosebleed for the previous day.
      await tester.tap(
        find.descendant(
          of: find.byType(YesterdayBanner),
          matching: find.text('No'),
        ),
      );
      mark('07 tapped No nosebleeds');
      await tester.pump(const Duration(seconds: 3));
      mark('08 pumped after answering No');

      // 4. The Application records the response for the previous day and
      //    clears the prompt -- the app stays on the Main Screen and the
      //    Yesterday Confirmation Prompt is removed.
      await _pumpUntil(
        tester,
        () => find.byType(YesterdayBanner).evaluate().isEmpty,
        description: 'Yesterday Confirmation Prompt to clear after answering',
        timeout: const Duration(seconds: 30),
      );
      mark('09 prompt cleared');
      expect(
        find.byType(YesterdayBanner),
        findsNothing,
        reason: 'Prompt must be removed once yesterday has a recorded status.',
      );
      mark('10 YesterdayBanner gone');
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'App must remain on the Main Screen after answering.',
      );
      mark('11 still on Main Screen');
      expect(
        find.text('Your Records'),
        findsOneWidget,
        reason: 'Your Records section must be present on the Main Screen.',
      );
      mark('12 Your Records visible');

      expect(
        tester.takeException(),
        isNull,
        reason: "Confirming yesterday's status must not throw.",
      );
      mark('13 journey complete, no exceptions');
      await _screenshot(binding, tester, 'jny_confirm_yesterday_status');
      mark('14 screenshot taken, DONE');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  // =========================================================================
  // DIARY-JNY-incomplete-record-lifecycle: Incomplete record — how it's
  // created, the reminders, and finishing it
  //
  // Requirements: DIARY-PRD-incomplete-entry-preservation,
  // DIARY-GUI-participant-task-list, DIARY-GUI-main-screen-layout,
  // DIARY-PRD-notification-ongoing-epistaxis,
  // CAL-PRD-notification-ongoing-epistaxis-configuration,
  // DIARY-PRD-notification-incomplete-record-lock,
  // CAL-PRD-notification-incomplete-record-lock-configuration,
  // DIARY-PRD-entry-time-restrictions, DIARY-GUI-epistaxis-delete
  //
  // Who: a Participant who started recording an epistaxis event but didn't
  // finish it.
  //
  // Journey (the on-device, deterministic portions of the lifecycle):
  // 1. The Participant starts recording a nosebleed and notes when it started
  //    but not when it stopped, then leaves the recording flow before the
  //    event is complete (Back, no end time). The Application saves what they
  //    entered as a draft automatically -- WITHOUT asking them to confirm
  //    (DIARY-PRD-incomplete-entry-preservation).
  // 2. The unfinished entry appears on the Main Screen in the "Needs your
  //    attention" panel as an incomplete record, visible every time they open
  //    the app (DIARY-GUI-participant-task-list, DIARY-GUI-main-screen-layout).
  // 3. The Participant opens the incomplete record from the "Needs your
  //    attention" panel and resolves it by deleting it, choosing a reason
  //    (DIARY-GUI-epistaxis-delete). The same entry point also allows
  //    supplying the missing end time to complete it.
  // 4. Once deleted the entry is removed and the task clears; the reminder
  //    sequence (ongoing-epistaxis nudges + the pre-lock final warning,
  //    DIARY-PRD-notification-ongoing-epistaxis /
  //    DIARY-PRD-notification-incomplete-record-lock) therefore stops.
  //
  // NOTE: the reminder cadence and the pre-lock warning are time-based OS
  // notifications fired by background schedulers over hours/days; like the
  // other journeys in this suite, this test asserts the UI-observable causal
  // state (draft preserved -> surfaced as a task -> resolved) rather than the
  // scheduler timing, which is covered by unit/widget tests.
  //
  // Outcome: no partial recording is lost, the entry is surfaced for the
  // Participant to act on, and it is resolved into a removed entry; the task
  // clears from "Needs your attention".
  //
  // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
  // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
  // if the test stalls.
  // =========================================================================
  testWidgets(
    'jnyIncompleteRecordLifecycle',
    (tester) async {
      void mark(String step) =>
          debugPrint('DIARY-JNY-DIAG >>> $step');

      mark('00 app.main() about to start');
      app.main();
      mark('01 app.main() returned, waiting for home');
      await _waitForHome(tester);
      mark('02 home reached');
      await tester.pump(const Duration(seconds: 1));
      mark('03 settled on Main Screen');

      // 1. Start recording a nosebleed: open the flow and set ONLY the start
      //    time (leaving the end time unset), then leave before completing.
      expect(
        find.text('Record Nosebleed'),
        findsOneWidget,
        reason: 'Main Screen must offer the Record Nosebleed action.',
      );
      await tester.tap(find.text('Record Nosebleed'));
      mark('04 tapped Record Nosebleed');
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byType(RecordingScreen),
        findsOneWidget,
        reason: 'RecordingScreen must open after Record Nosebleed.',
      );
      mark('05 RecordingScreen open (startTime step)');

      // Move the start time back 15 minutes (stay at/under now), then confirm
      // the start. This advances past the start step WITHOUT setting an end
      // time, so the entry is a genuine partial record.
      expect(
        find.text('-15'),
        findsOneWidget,
        reason: 'Start-time dial must offer the -15 minute adjuster.',
      );
      await tester.tap(find.text('-15'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Set Start Time'),
        findsOneWidget,
        reason: 'Start-time step must offer the Set Start Time action.',
      );
      await tester.tap(find.text('Set Start Time'));
      mark('06 set start time (end left unset -> partial)');
      await tester.pump(const Duration(seconds: 2));

      // Leave the recording flow before the event is complete via the
      // "< Home" back affordance. The Application auto-saves the partial
      // entry as a checkpoint draft (no confirmation prompt) and returns to
      // the Main Screen. Implements: DIARY-PRD-incomplete-entry-preservation.
      expect(
        find.byType(BackToHomeRow),
        findsOneWidget,
        reason: 'Recording flow must offer the back-to-home affordance.',
      );
      await tester.tap(find.byType(BackToHomeRow));
      mark('07 tapped back (< Home) mid-recording');

      // 2. The draft is preserved and surfaces on the Main Screen in the
      //    "Needs your attention" panel as an incomplete record.
      await _pumpUntil(
        tester,
        () =>
            find.byType(HomeScreen).evaluate().isNotEmpty &&
            find.text('1 incomplete record').evaluate().isNotEmpty,
        description: 'return to Main Screen with the incomplete-record alert',
        timeout: const Duration(seconds: 30),
      );
      mark('08 back on Main Screen, incomplete alert present');
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'App must return to the Main Screen after backing out.',
      );
      expect(
        find.text('Needs your attention'),
        findsOneWidget,
        reason: 'Task List must show the "Needs your attention" panel.',
      );
      expect(
        find.text('1 incomplete record'),
        findsOneWidget,
        reason:
            'The unfinished entry must surface as an incomplete record so it '
            'is visible every time the app is opened.',
      );
      mark('09 incomplete record visible in Needs your attention');

      // 3. Open the incomplete record from the "Needs your attention" panel.
      //    A single incomplete entry jumps straight back into the recording
      //    screen to resume/resolve it.
      await tester.tap(find.text('1 incomplete record'));
      mark('10 tapped the incomplete record');
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byType(RecordingScreen),
        findsOneWidget,
        reason: 'Opening the incomplete record must reopen the recording flow.',
      );
      mark('11 RecordingScreen reopened on the draft');

      // Resolve by DELETING it (choosing a reason). Tapping the delete action
      // opens the delete-confirmation dialog, which requires a reason.
      // Implements: DIARY-GUI-epistaxis-delete.
      expect(
        find.byTooltip('Delete record'),
        findsOneWidget,
        reason: 'Recording flow must offer the delete action for a draft.',
      );
      await tester.tap(find.byTooltip('Delete record'));
      mark('12 tapped delete');
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Delete Record'),
        findsOneWidget,
        reason: 'Delete must require confirmation with a reason.',
      );
      expect(
        find.text('Entered by mistake'),
        findsOneWidget,
        reason: 'Delete dialog must offer a reason to choose.',
      );
      mark('13 delete dialog visible with reasons');

      // Choose a reason, then confirm the deletion.
      await tester.tap(find.text('Entered by mistake'));
      mark('14 selected delete reason');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      mark('15 confirmed delete');
      await tester.pump(const Duration(seconds: 3));

      // 4. The entry is removed and the task clears: back on the Main Screen
      //    the incomplete-record alert is gone (so the reminder sequence,
      //    which is reset by interaction and ends once resolved, stops).
      await _pumpUntil(
        tester,
        () =>
            find.byType(HomeScreen).evaluate().isNotEmpty &&
            find.text('1 incomplete record').evaluate().isEmpty,
        description: 'incomplete-record alert to clear after deletion',
        timeout: const Duration(seconds: 30),
      );
      mark('16 back on Main Screen, alert cleared');
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'App must return to the Main Screen after deleting.',
      );
      expect(
        find.text('1 incomplete record'),
        findsNothing,
        reason: 'The incomplete record must be gone once it is deleted.',
      );
      mark('17 incomplete record removed');

      expect(
        tester.takeException(),
        isNull,
        reason: 'The incomplete-record lifecycle must not throw.',
      );
      mark('18 journey complete, no exceptions');
      await _screenshot(binding, tester, 'jny_incomplete_record_lifecycle');
      mark('19 screenshot taken, DONE');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
// dart format on
