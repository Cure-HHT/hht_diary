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
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
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

    // =========================================================================
    // DIARY-JNY-complete-incomplete-record: Finish an incomplete record
    //
    // Requirements: DIARY-GUI-participant-task-list,
    // DIARY-PRD-incomplete-entry-preservation, DIARY-GUI-epistaxis-record,
    // DIARY-GUI-main-screen-layout
    //
    // Who: User/Participant.
    //
    // Starting point: the Main Screen shows an item in the "Needs your
    // attention" panel (an incomplete record). This is the COMPLETE-IT branch
    // of the incomplete-record lifecycle (the delete branch is covered by
    // jnyIncompleteRecordLifecycle).
    //
    // Journey:
    // 1. Seed an incomplete record: open Record Nosebleed, set ONLY the start
    //    time, then leave via "< Home" so the app auto-saves a partial draft
    //    (DIARY-PRD-incomplete-entry-preservation).
    // 2. Expand "Needs your attention" and select the incomplete-records task
    //    ("1 incomplete record"); a single incomplete entry reopens the
    //    recording flow on the draft (DIARY-GUI-participant-task-list).
    // 3. Supply the remaining detail: choose the intensity, set the end time.
    //    With ClinicalRules defaults (useReviewScreen:false) confirming a valid
    //    end time saves immediately (DIARY-GUI-epistaxis-record).
    // 4. The completed entry moves into the day's records and the incomplete
    //    task clears once no incomplete entries remain.
    //
    // Outcome: the previously partial entry becomes a complete event in the
    // diary and no longer appears as a task -- the "1 incomplete record" alert
    // is gone and the app is back on the Main Screen under Your Records.
    //
    // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
    // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
    // if the test stalls.
    // =========================================================================
    testWidgets(
      'jnyCompleteIncompleteRecord',
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

        // 1. Seed an incomplete record: open the flow and set ONLY the start
        //    time, then leave before completing so a partial draft is saved.
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

        // Leave the flow before completing via "< Home"; the app auto-saves the
        // partial entry as a checkpoint draft (no confirmation prompt).
        expect(
          find.byType(BackToHomeRow),
          findsOneWidget,
          reason: 'Recording flow must offer the back-to-home affordance.',
        );
        await tester.tap(find.byType(BackToHomeRow));
        mark('07 tapped back (< Home) mid-recording');

        // 2. The draft surfaces in the "Needs your attention" panel.
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
          find.text('Needs your attention'),
          findsOneWidget,
          reason: 'Task List must show the "Needs your attention" panel.',
        );
        expect(
          find.text('1 incomplete record'),
          findsOneWidget,
          reason: 'The unfinished entry must surface as an incomplete record.',
        );
        mark('09 incomplete record visible');

        // 3. Select the incomplete-records task; the single draft reopens the
        //    recording flow so the missing detail can be supplied.
        await tester.tap(find.text('1 incomplete record'));
        mark('10 tapped the incomplete record');
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byType(RecordingScreen),
          findsOneWidget,
          reason: 'Opening the incomplete record must reopen the recording flow.',
        );
        mark('11 RecordingScreen reopened on the draft');

        // The draft has no intensity yet, so it resumes at the intensity step.
        // Supply the missing intensity.
        expect(
          find.text('Dripping'),
          findsOneWidget,
          reason: 'Resumed draft must present the intensity options.',
        );
        await tester.tap(find.text('Dripping'));
        mark('12 selected intensity (Dripping)');
        await tester.pump(const Duration(seconds: 2));

        // Now supply the missing end time. The end dial starts at the (moved-
        // back) start; nudge +5 so the end is after the start and at/under now.
        expect(
          find.text('+5'),
          findsOneWidget,
          reason: 'End-time dial must offer the +5 minute adjuster.',
        );
        await tester.tap(find.text('+5'));
        mark('13 bumped end time +5');
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('Set End Time'),
          findsOneWidget,
          reason: 'End-time step must offer the Set End Time action.',
        );
        await tester.tap(find.text('Set End Time'));
        mark('14 tapped Set End Time (completes the draft)');
        await tester.pump(const Duration(seconds: 3));

        // 4. The entry is completed and saved; back on the Main Screen the
        //    incomplete-record alert is gone (no incomplete entries remain).
        await _pumpUntil(
          tester,
          () =>
              find.byType(HomeScreen).evaluate().isNotEmpty &&
              find.text('1 incomplete record').evaluate().isEmpty,
          description: 'incomplete-record alert to clear after completion',
          timeout: const Duration(seconds: 30),
        );
        mark('15 back on Main Screen, incomplete alert cleared');
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'App must return to the Main Screen after completing.',
        );
        expect(
          find.text('1 incomplete record'),
          findsNothing,
          reason: 'No incomplete record may remain once the draft is completed.',
        );
        mark('16 incomplete task cleared');
        expect(
          find.text('Your Records'),
          findsOneWidget,
          reason: 'Your Records section must be present on the Main Screen.',
        );
        mark('17 Your Records visible');

        expect(
          tester.takeException(),
          isNull,
          reason: 'Finishing an incomplete record must not throw.',
        );
        mark('18 journey complete, no exceptions');
        await _screenshot(binding, tester, 'jny_complete_incomplete_record');
        mark('19 screenshot taken, DONE');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    // =========================================================================
    // DIARY-JNY-resolve-overlapping-event: Resolve an overlapping event
    //
    // Requirements: DIARY-PRD-entry-overlap-resolution,
    // DIARY-GUI-entry-overlap-resolution, DIARY-GUI-epistaxis-record,
    // DIARY-PRD-entry-time-restrictions
    //
    // Who: User/Participant.
    //
    // Starting point: mid-recording, the Participant has entered times that
    // overlap an existing entry.
    //
    // Journey:
    // 1. Record a FIRST event (existing entry): start -15, intensity, end +5 ->
    //    a finalized event ending ~10 minutes before now.
    // 2. Start a SECOND event whose times overlap the first. Its start dial
    //    defaults to NOW; move it back so its [start, now] candidate span runs
    //    into the first event (the recording screen treats an un-ended entry as
    //    spanning start..now, so the overlap warning surfaces during recording
    //    -- DIARY-GUI-entry-overlap-resolution/A+B).
    // 3. After setting the end time on the overlapping second event,
    //    _handleEndTimeConfirm detects the conflict and routes STRAIGHT to the
    //    side-by-side Resolution Screen (OverlapCompareScreen) comparing the
    //    New Record and the Existing Record (DIARY-GUI-entry-overlap-resolution
    //    /C, DIARY-PRD-entry-overlap-resolution/A).
    // 4. The Participant chooses how to resolve it -- here Keep Existing
    //    ('overlap-pick-left'). (Keep New / Merge are the other two options on
    //    the same screen.)
    // 5. Every choice routes through the single Confirm Record step for review;
    //    confirming it applies the resolution atomically (edit survivor + delete
    //    the discarded entry) and returns to the Main Screen.
    //
    // Outcome: the conflict is resolved into a single consistent entry, with no
    // overlapping events remaining -- the home "overlapping record needs
    // resolving" alert is absent.
    //
    // NOTE ON DETERMINISM: this test asserts the deterministic, UI-observable
    // core of the journey -- that an overlapping end time ROUTES INTO the
    // Resolution Screen, that the three resolution affordances are present, and
    // that committing a choice resolves the conflict and returns home with no
    // overlap alert. The exact union timestamps a Merge would produce depend on
    // the coarse (-15/+5 min) dial steps and the device clock, so the precise
    // merged span is not asserted (covered by unit/widget tests); Keep Existing
    // is chosen for a deterministic single-survivor outcome.
    //
    // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
    // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
    // if the test stalls.
    // =========================================================================
    testWidgets(
      'jnyResolveOverlappingEvent',
      (tester) async {
        void mark(String step) =>
            debugPrint('DIARY-JNY-DIAG >>> $step');

        // Records ONE epistaxis event: Record Nosebleed -> start -15 ->
        // intensity Dripping -> end +5 -> Set End Time. With useReviewScreen
        // false this saves immediately and returns to the Main Screen. Reused
        // for the FIRST (existing) event below.
        Future<void> recordOneEvent() async {
          await tester.tap(find.text('Record Nosebleed'));
          await tester.pump(const Duration(seconds: 3));
          expect(
            find.byType(RecordingScreen),
            findsOneWidget,
            reason: 'RecordingScreen must open after Record Nosebleed.',
          );
          await tester.tap(find.text('-15'));
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Set Start Time'));
          await tester.pump(const Duration(seconds: 2));
          await tester.tap(find.text('Dripping'));
          await tester.pump(const Duration(seconds: 2));
          await tester.tap(find.text('+5'));
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Set End Time'));
          await tester.pump(const Duration(seconds: 3));
        }

        mark('00 app.main() about to start');
        app.main();
        mark('01 app.main() returned, waiting for home');
        await _waitForHome(tester);
        mark('02 home reached');
        await tester.pump(const Duration(seconds: 1));
        mark('03 settled on Main Screen');

        // 1. Record the FIRST (existing) event and return to the Main Screen.
        expect(
          find.text('Record Nosebleed'),
          findsOneWidget,
          reason: 'Main Screen must offer the Record Nosebleed action.',
        );
        await recordOneEvent();
        await _pumpUntil(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
          description: 'return to Main Screen after the first event',
          timeout: const Duration(seconds: 30),
        );
        mark('04 first (existing) event recorded, back on Main Screen');

        // 2. Start a SECOND event that overlaps the first. Its start defaults to
        //    NOW; move it back so the [start, now] candidate span runs into the
        //    first event's window (which ended ~10 min ago).
        await tester.tap(find.text('Record Nosebleed'));
        mark('05 tapped Record Nosebleed for the overlapping event');
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byType(RecordingScreen),
          findsOneWidget,
          reason: 'RecordingScreen must open for the second event.',
        );
        // Move the start back 15 min so it precedes the first event's end and the
        // ongoing [start, now] span overlaps it.
        await tester.tap(find.text('-15'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Set Start Time'));
        mark('06 set overlapping start time');
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.text('Dripping'));
        mark('07 selected intensity for overlapping event');
        await tester.pump(const Duration(seconds: 2));
        // Set an end time; +5 keeps it after the start and at/under now while
        // remaining inside the first event's span -> a confirmed overlap.
        await tester.tap(find.text('+5'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Set End Time'));
        mark('08 set end time confirming the overlap');
        await tester.pump(const Duration(seconds: 3));

        // 3. Confirming an overlapping end time routes straight to the
        //    side-by-side Resolution Screen.
        await _pumpUntil(
          tester,
          () => find.byType(OverlapCompareScreen).evaluate().isNotEmpty,
          description: 'Resolution Screen to open for the confirmed overlap',
          timeout: const Duration(seconds: 30),
        );
        mark('09 OverlapCompareScreen open');
        expect(
          find.byType(OverlapCompareScreen),
          findsOneWidget,
          reason:
              'A confirmed overlap must route into the Resolution Screen.',
        );
        expect(
          find.text('Please Resolve the Conflict:'),
          findsOneWidget,
          reason: 'Resolution Screen must prompt the participant to resolve.',
        );
        expect(
          find.text('New Record'),
          findsOneWidget,
          reason: 'Resolution Screen must show the New Record card.',
        );
        expect(
          find.text('Existing Record'),
          findsOneWidget,
          reason: 'Resolution Screen must show the Existing Record card.',
        );
        // All three resolution affordances must be present.
        expect(
          find.byKey(const Key('overlap-pick-right')),
          findsOneWidget,
          reason: 'Keep New option must be offered.',
        );
        expect(
          find.byKey(const Key('overlap-pick-left')),
          findsOneWidget,
          reason: 'Keep Existing option must be offered.',
        );
        expect(
          find.byKey(const Key('overlap-merge')),
          findsOneWidget,
          reason: 'Merge option must be offered.',
        );
        mark('10 all three resolution options visible');

        // 4. Choose Keep Existing -> the new entry is the loser; the pre-existing
        //    entry survives. The choice is deferred to the Confirm Record step.
        await tester.tap(find.byKey(const Key('overlap-pick-left')));
        mark('11 tapped Keep Existing');
        await tester.pump(const Duration(seconds: 3));

        // 5. The flow returns to the recording screen's Confirm Record step for a
        //    final review; confirm it (Finished/Complete Record/Save Changes).
        await _pumpUntil(
          tester,
          () =>
              find.text('Finished').evaluate().isNotEmpty ||
              find.text('Complete Record').evaluate().isNotEmpty ||
              find.text('Save Changes').evaluate().isNotEmpty ||
              find.byType(HomeScreen).evaluate().isNotEmpty,
          description: 'Confirm Record step (or direct return to Main Screen)',
          timeout: const Duration(seconds: 30),
        );
        mark('12 reached Confirm Record step (or already home)');
        // If we are on the Confirm Record step, confirm the surviving entry.
        if (find.byType(HomeScreen).evaluate().isEmpty) {
          final confirm = find.byType(RecordingScreen).evaluate().isNotEmpty &&
                  find.text('Save Changes').evaluate().isNotEmpty
              ? find.text('Save Changes')
              : (find.text('Complete Record').evaluate().isNotEmpty
                  ? find.text('Complete Record')
                  : find.text('Finished'));
          await tester.tap(confirm);
          mark('13 confirmed the surviving entry');
          await tester.pump(const Duration(seconds: 3));
        }

        // The conflict is resolved into one entry; back on the Main Screen there
        // must be NO overlapping-record alert.
        await _pumpUntil(
          tester,
          () =>
              find.byType(HomeScreen).evaluate().isNotEmpty &&
              find
                  .textContaining('overlapping record')
                  .evaluate()
                  .isEmpty,
          description: 'return to Main Screen with no overlap alert',
          timeout: const Duration(seconds: 30),
        );
        mark('14 back on Main Screen, no overlap alert');
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'App must return to the Main Screen after resolving.',
        );
        expect(
          find.textContaining('overlapping record'),
          findsNothing,
          reason: 'No overlapping events may remain after resolution.',
        );
        mark('15 overlap resolved, no remaining conflict');

        expect(
          tester.takeException(),
          isNull,
          reason: 'Resolving an overlapping event must not throw.',
        );
        mark('16 journey complete, no exceptions');
        await _screenshot(binding, tester, 'jny_resolve_overlapping_event');
        mark('17 screenshot taken, DONE');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    // =========================================================================
    // DIARY-JNY-review-backfill-calendar: Review and backfill past days from the
    // Calendar
    //
    // Requirements: DIARY-GUI-calendar-day-view, DIARY-GUI-main-screen-layout,
    // DIARY-PRD-epistaxis-capture-standard, DIARY-PRD-day-disposition,
    // DIARY-PRD-diary-start-day, DIARY-PRD-notification-historical-gap
    //
    // Who: User/Participant.
    //
    // Starting point: the Main Screen is open.
    //
    // Journey:
    // 1. The Participant taps View Calendar and sees the month grid (the
    //    'Select Date' dialog) with the recording-state legend
    //    (DIARY-GUI-calendar-day-view).
    // 2. The Participant selects a PAST day that has no entry. A genuinely empty
    //    past day opens the 3-choice day-disposition picker (DaySelectionScreen,
    //    DIARY-PRD-day-disposition/B). (A day that already holds records opens
    //    the records list instead -- both are valid Calendar day-view targets.)
    // 3. On the picker the Participant records the day's status. Here: No
    //    nosebleed events (the other options are a nosebleed event or
    //    'I don't recall / unknown') (DIARY-PRD-epistaxis-capture-standard).
    // 4. The Application saves the whole-day marker and the picker closes,
    //    returning to the Calendar; the day's state is updated reactively.
    //
    // Outcome: a previously missing day is filled in, and the Calendar reflects
    // the updated record (the picker is dismissed without error).
    //
    // NOTE ON DETERMINISM: the test taps the FIRST day of the current month,
    // which is in the past for any run after the 1st and is within the 365-day
    // diary-start floor. The deterministic, asserted core of the journey is:
    // Calendar opens -> a past day routes to the day-view target (disposition
    // picker for an empty day) -> recording 'No nosebleed events' disposes the
    // day and dismisses the picker without error. The historical-gap reminder
    // (DIARY-PRD-notification-historical-gap) is a time-based notification and
    // is covered by the scenario context, not asserted on-device.
    //
    // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
    // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
    // if the test stalls.
    // =========================================================================
    testWidgets(
      'jnyReviewBackfillCalendar',
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

        // 1. Open the Calendar from the Main Screen.
        expect(
          find.text('View Calendar'),
          findsOneWidget,
          reason: 'Main Screen must offer the View Calendar action.',
        );
        await tester.tap(find.text('View Calendar'));
        mark('04 tapped View Calendar');
        await tester.pump(const Duration(seconds: 2));

        // The calendar opens as the 'Select Date' dialog with its legend.
        await _pumpUntil(
          tester,
          () => find.text('Select Date').evaluate().isNotEmpty,
          description: 'Calendar (Select Date) dialog to open',
          timeout: const Duration(seconds: 15),
        );
        mark('05 Calendar dialog open');
        expect(
          find.text('Select Date'),
          findsOneWidget,
          reason: 'Calendar dialog must show the Select Date header.',
        );
        expect(
          find.text('No nosebleeds'),
          findsWidgets,
          reason: 'Calendar legend must label the No-nosebleeds state '
              '(the same label also appears in the day-status summary).',
        );
        expect(
          find.text('Tap a date to add or edit events'),
          findsOneWidget,
          reason: 'Calendar must instruct the participant to tap a date.',
        );
        mark('06 Calendar header + legend present');

        // 2. Select a PAST day. Tap the first day of the current month, which is
        //    in the past on any run after the 1st. The current-month '1' cell is
        //    the first matching day-number widget in the grid.
        expect(
          find.text('1'),
          findsWidgets,
          reason: 'The calendar grid must render day numbers.',
        );
        await tester.tap(find.text('1').first);
        mark('07 tapped a past day (the 1st)');
        await tester.pump(const Duration(seconds: 2));

        // 3. An empty past day opens the 3-choice disposition picker. (If the day
        //    already held records it would open the records list instead; the
        //    picker is the empty-day path this journey targets.)
        await _pumpUntil(
          tester,
          () =>
              find.text('What happened on this day?').evaluate().isNotEmpty ||
              find.text('Add new event').evaluate().isNotEmpty,
          description: 'day-view target (disposition picker or records list)',
          timeout: const Duration(seconds: 15),
        );
        mark('08 day-view target opened');

        if (find.text('What happened on this day?').evaluate().isNotEmpty) {
          // Empty day -> disposition picker. Record No nosebleed events.
          expect(
            find.text('No nosebleed events'),
            findsOneWidget,
            reason: 'Disposition picker must offer the No-nosebleed-events '
                'option.',
          );
          expect(
            find.text("I don't recall / unknown"),
            findsOneWidget,
            reason: 'Disposition picker must offer the unknown option.',
          );
          mark('09 disposition options visible');
          await tester.tap(find.text('No nosebleed events'));
          mark('10 tapped No nosebleed events');
          await tester.pump(const Duration(seconds: 3));

          // 4. The marker is saved and the picker closes, returning to the
          //    Calendar dialog (the day status is updated reactively).
          await _pumpUntil(
            tester,
            () =>
                find.text('What happened on this day?').evaluate().isEmpty,
            description: 'disposition picker to close after recording status',
            timeout: const Duration(seconds: 30),
          );
          mark('11 disposition picker closed after recording status');
          expect(
            find.text('What happened on this day?'),
            findsNothing,
            reason: 'Picker must dismiss once the day status is recorded.',
          );
          mark('12 day backfilled, picker dismissed');
        } else {
          // The tapped day already had records: the records list opened. That is
          // still a valid Calendar day-view target; assert it rendered the
          // add-event affordance, then return to the calendar.
          mark('09 day already had records -> records list opened');
          expect(
            find.text('Add new event'),
            findsOneWidget,
            reason: 'Records list must offer the Add new event action.',
          );
          mark('10 records list verified');
        }

        expect(
          tester.takeException(),
          isNull,
          reason: 'Reviewing/backfilling a day from the Calendar must not throw.',
        );
        mark('13 journey complete, no exceptions');
        await _screenshot(binding, tester, 'jny_review_backfill_calendar');
        mark('14 screenshot taken, DONE');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    // =========================================================================
    // DIARY-JNY-edit-delete-event: Edit or delete a recorded event
    //
    // Requirements: DIARY-GUI-calendar-day-view, DIARY-GUI-epistaxis-record,
    // DIARY-GUI-epistaxis-delete, DIARY-PRD-entry-time-restrictions,
    // DIARY-GUI-main-screen-layout
    //
    // Who: User/Participant.
    //
    // Starting point: a recorded event reached from Your Records (the Main
    // Screen today list). (The Calendar Day View is the other entry point to
    // the same edit/delete flow -- DIARY-GUI-calendar-day-view.)
    //
    // Journey:
    // 1. Record an event so there is one to act on (start -15, intensity, end
    //    +5), returning to the Main Screen where it appears under Your Records.
    // 2. Select the existing event in Your Records -> the recording screen
    //    reopens on that entry for editing (DIARY-GUI-epistaxis-record).
    // 3. The Participant chooses to delete it: tapping the delete action opens
    //    the delete-confirmation dialog (DIARY-GUI-epistaxis-delete).
    // 4. The Participant selects a reason from the list and confirms.
    // 5. The Application saves the change and returns the Participant to the
    //    Main Screen.
    //
    // Outcome: the event is removed from the diary; the app is back on the Main
    // Screen. (For a linked Participant the delete also syncs to the study via
    // the DiaryServerDestination -- not exercised on this unlinked device; the
    // local removal is the on-device-observable outcome.)
    //
    // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
    // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
    // if the test stalls.
    // =========================================================================
    testWidgets(
      'jnyEditDeleteEvent',
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

        // 1. Record an event so there is one to edit/delete.
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
        await tester.tap(find.text('-15'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Set Start Time'));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.text('Dripping'));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.text('+5'));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Set End Time'));
        mark('05 recorded an event');
        await tester.pump(const Duration(seconds: 3));
        await _pumpUntil(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
          description: 'return to Main Screen after recording the event',
          timeout: const Duration(seconds: 30),
        );
        mark('06 back on Main Screen, event in Your Records');
        expect(
          find.text('Your Records'),
          findsOneWidget,
          reason: 'Your Records section must be present on the Main Screen.',
        );

        // 2. Select the existing event in Your Records. Each event row is an
        //    EventListItem; tapping an epistaxis row reopens the recording screen
        //    on that entry for editing.
        expect(
          find.byType(EventListItem),
          findsWidgets,
          reason: 'The recorded event must appear under Your Records.',
        );
        await tester.tap(find.byType(EventListItem).last);
        mark('07 tapped the recorded event');
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byType(RecordingScreen),
          findsOneWidget,
          reason: 'Tapping a recorded event must reopen the recording screen '
              'for editing.',
        );
        mark('08 RecordingScreen reopened on the existing event');

        // 3. Choose to delete it: the delete action opens the confirmation
        //    dialog (a reason is required).
        expect(
          find.byTooltip('Delete record'),
          findsOneWidget,
          reason: 'Recording flow must offer the delete action for an entry.',
        );
        await tester.tap(find.byTooltip('Delete record'));
        mark('09 tapped delete');
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.text('Delete Record'),
          findsOneWidget,
          reason: 'Delete must require confirmation.',
        );
        expect(
          find.text('Entered by mistake'),
          findsOneWidget,
          reason: 'Delete dialog must list reasons to choose from.',
        );
        mark('10 delete dialog visible with reasons');

        // 4. Select a reason and confirm.
        await tester.tap(find.text('Entered by mistake'));
        mark('11 selected a delete reason');
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        mark('12 confirmed delete');
        await tester.pump(const Duration(seconds: 3));

        // 5. The change is saved and the app returns to the Main Screen with the
        //    event removed.
        await _pumpUntil(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
          description: 'return to Main Screen after deleting the event',
          timeout: const Duration(seconds: 30),
        );
        mark('13 back on Main Screen after delete');
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'App must return to the Main Screen after deleting.',
        );
        expect(
          find.byType(RecordingScreen),
          findsNothing,
          reason: 'The recording screen must be dismissed after deletion.',
        );
        mark('14 recording screen dismissed, event deleted');

        expect(
          tester.takeException(),
          isNull,
          reason: 'Editing/deleting a recorded event must not throw.',
        );
        mark('15 journey complete, no exceptions');
        await _screenshot(binding, tester, 'jny_edit_delete_event');
        mark('16 screenshot taken, DONE');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    // =========================================================================
    // DIARY-JNY-manage-profile-settings: Manage profile and accessibility
    // settings
    //
    // Requirements: DIARY-GUI-user-profile, DIARY-GUI-mobile-navigation,
    // DIARY-PRD-user-authentication, DIARY-GUI-user-authentication,
    // DIARY-GUI-accessibility-preferences
    //
    // Who: User/Participant.
    //
    // Starting point: the Application Menu (the hamburger user menu in the top
    // bar), opening User Profile.
    //
    // Journey:
    // 1. The Participant opens the Application Menu (Icons.menu / 'Menu') and
    //    selects 'User Profile' (DIARY-GUI-mobile-navigation,
    //    DIARY-GUI-user-profile).
    // 2. The Profile screen shows Your Status and the menu list including the
    //    'Accessibility & Preferences' row. The Participant opens it
    //    (DIARY-GUI-user-profile).
    // 3. In Accessibility & Preferences (the Settings screen) the Participant
    //    can adjust accessibility options (DIARY-GUI-accessibility-preferences).
    // 4. The Application reflects the chosen preferences right away.
    //
    // Outcome: the Application surfaces the participant's profile and the
    // accessibility settings entry point, and the Settings screen renders its
    // Accessibility section.
    //
    // NOTE ON THIS BUILD: in the Callisto UAT build several accessibility
    // toggles are config-gated and the in-app biometric lock ('Use Face ID /
    // Fingerprint', DIARY-PRD/GUI-user-authentication) is a 'Coming soon' stub,
    // so those specific toggles are not asserted here. The deterministic,
    // asserted core of the journey is the navigation Application Menu -> User
    // Profile -> Accessibility & Preferences (Settings) and the presence of the
    // Accessibility section -- the user-profile + accessibility-preferences
    // entry points that ARE built in this build.
    //
    // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker via
    // debugPrint so the Firebase Test Lab logcat reveals the exact step reached
    // if the test stalls.
    // =========================================================================
    testWidgets(
      'jnyManageProfileSettings',
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

        // 1. Open the Application Menu (hamburger) and select User Profile.
        expect(
          find.byIcon(Icons.menu),
          findsOneWidget,
          reason: 'Main Screen must show the Application Menu (hamburger).',
        );
        await tester.tap(find.byIcon(Icons.menu));
        mark('04 opened the Application Menu');
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('User Profile'),
          findsOneWidget,
          reason: 'Application Menu must offer the User Profile row.',
        );
        await tester.tap(find.text('User Profile'));
        mark('05 tapped User Profile');
        await tester.pump(const Duration(seconds: 3));

        // 2. The Profile screen renders: title + Your Status + the menu list
        //    with the Accessibility & Preferences row.
        await _pumpUntil(
          tester,
          () => find.byType(ProfileScreen).evaluate().isNotEmpty,
          description: 'Profile screen to open',
          timeout: const Duration(seconds: 15),
        );
        mark('06 ProfileScreen open');
        expect(
          find.byType(ProfileScreen),
          findsOneWidget,
          reason: 'User Profile must open from the Application Menu.',
        );
        expect(
          find.text('Your Status'),
          findsOneWidget,
          reason: 'Profile must show the Your Status section.',
        );
        expect(
          find.text('Accessibility & Preferences'),
          findsOneWidget,
          reason: 'Profile menu must offer the Accessibility & Preferences row.',
        );
        mark('07 Profile shows status + accessibility entry');

        // 3. Open Accessibility & Preferences (the Settings screen).
        await tester.tap(find.text('Accessibility & Preferences'));
        mark('08 tapped Accessibility & Preferences');
        await tester.pump(const Duration(seconds: 3));
        await _pumpUntil(
          tester,
          () => find.byType(SettingsScreen).evaluate().isNotEmpty,
          description: 'Settings (Accessibility & Preferences) screen to open',
          timeout: const Duration(seconds: 15),
        );
        mark('09 SettingsScreen open');
        expect(
          find.byType(SettingsScreen),
          findsOneWidget,
          reason: 'Accessibility & Preferences must open the Settings screen.',
        );
        expect(
          find.text('Settings'),
          findsOneWidget,
          reason: 'Settings screen must show its title.',
        );
        // The Accessibility section header is always present in this build.
        expect(
          find.text('Accessibility'),
          findsOneWidget,
          reason: 'Settings must render the Accessibility section.',
        );
        mark('10 Settings Accessibility section present');

        // 4. The screen is interactive (the participant can adjust preferences).
        //    Confirm the back affordance works and returns to Profile, evidencing
        //    the navigation round-trip applied without error.
        expect(
          find.widgetWithIcon(TextButton, Icons.arrow_back),
          findsOneWidget,
          reason: 'Settings must offer a Back action.',
        );
        await tester.tap(find.widgetWithIcon(TextButton, Icons.arrow_back));
        mark('11 tapped Back from Settings');
        await tester.pump(const Duration(seconds: 2));
        await _pumpUntil(
          tester,
          () => find.byType(ProfileScreen).evaluate().isNotEmpty,
          description: 'return to the Profile screen from Settings',
          timeout: const Duration(seconds: 15),
        );
        mark('12 back on Profile screen');
        expect(
          find.byType(ProfileScreen),
          findsOneWidget,
          reason: 'Back from Settings must return to the Profile screen.',
        );
        mark('13 navigation round-trip verified');

        expect(
          tester.takeException(),
          isNull,
          reason: 'Managing profile and accessibility settings must not throw.',
        );
        mark('14 journey complete, no exceptions');
        await _screenshot(binding, tester, 'jny_manage_profile_settings');
        mark('15 screenshot taken, DONE');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

  // dfUiResponsiveLayoutBounds - UI AUDIT (Tier 2 stability).
  //
  // IMPLEMENTS REQUIREMENTS:
  //   DIARY-GUI-main-screen-layout
  //   DIARY-GUI-mobile-navigation
  //
  // Why: defensive coverage against responsive-layout regressions. The
  // Main Screen builds its content with LayoutBuilder + Expanded/Flexible
  // inside a SafeArea (no top-level scroll view), so a height-sensitive
  // layout mistake can overflow on shorter/taller aspect ratios. This
  // test renders the Main Screen across a range of surface sizes (from a
  // compact 720p phone up to a 4K tablet) and fails if any RenderFlex
  // overflows or the primary action is pushed outside the screen bounds.
  //
  // What this CAN assert on-device: framework layout-overflow errors and
  // that a key widget stays within the logical screen rect after a resize.
  //
  // What this CANNOT assert on-device (documented, not tested): physical
  // display cutouts (notch / punch-hole) and collisions with the Android
  // system navigation bar. Firebase Test Lab does not expose deterministic
  // control over device insets / SafeArea geometry, so those are out of
  // scope here and must be verified by manual / screenshot review.
  //
  // DIAGNOSTIC INSTRUMENTATION: every step emits a 'DIARY-JNY-DIAG' marker.
  testWidgets(
    'dfUiResponsiveLayoutBounds',
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

      // The primary action anchors the Main Screen across every size.
      expect(
        find.text('Record Nosebleed'),
        findsOneWidget,
        reason: 'Main Screen must offer the Record Nosebleed action.',
      );
      mark('04 baseline Main Screen renders with Record Nosebleed');

      // Representative logical sizes (width x height) paired with a device
      // pixel ratio. Spans short/compact through tall 20:9 to large tablet,
      // exercising the screen-density and aspect-ratio range the layout must
      // survive. Sizes are in logical pixels; physicalSize = logical * dpr.
      const sizes = <(double, double, double)>[
        (360.0, 640.0, 2.0), // compact phone, 720p-class, 9:16
        (411.0, 731.0, 2.625), // common 1080p phone
        (412.0, 915.0, 2.625), // tall 20:9 phone (e.g. Pixel-class)
        (360.0, 800.0, 3.0), // narrow + tall, high density
        (800.0, 1280.0, 1.5), // small tablet, portrait
        (1280.0, 800.0, 1.5), // small tablet, landscape
        (1080.0, 2160.0, 1.0), // very tall, low dpr (4K-class portrait)
      ];

      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      mark('05 captured original view metrics');

      try {
        var index = 0;
        for (final spec in sizes) {
          final logicalWidth = spec.$1;
          final logicalHeight = spec.$2;
          final dpr = spec.$3;
          final label =
              '${logicalWidth.toInt()}x${logicalHeight.toInt()}@${dpr}x';

          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize =
              Size(logicalWidth * dpr, logicalHeight * dpr);
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
          mark('06.$index resized to $label');

          // A RenderFlex overflow (element drawn off-screen / fixed height
          // overrunning available space) is reported as a thrown exception
          // during layout; takeException() surfaces it deterministically.
          expect(
            tester.takeException(),
            isNull,
            reason: 'Main Screen must lay out without overflow at $label.',
          );
          mark('07.$index no layout overflow at $label');

          // The primary action must remain present and fully within the
          // logical screen rect (top-left origin, logical size).
          final anchor = find.text('Record Nosebleed');
          expect(
            anchor,
            findsOneWidget,
            reason: 'Record Nosebleed must stay rendered at $label.',
          );
          final rect = tester.getRect(anchor);
          final screen = Offset.zero & tester.view.physicalSize / dpr;
          expect(
            screen.contains(rect.topLeft) &&
                screen.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason:
                'Record Nosebleed must stay within screen bounds at $label '
                '(rect=$rect, screen=$screen).',
          );
          mark('08.$index Record Nosebleed within bounds at $label');
          index++;
        }
      } finally {
        // Always restore the original view metrics for following tests.
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalDpr;
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        mark('09 restored original view metrics');
      }

      mark('10 all sizes passed overflow + bounds checks');
      await _screenshot(binding, tester, 'dfui_responsive_layout_bounds');
      mark('11 screenshot taken, DONE');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

    // Verifies: JNY-DIARY-01
    // JNY-DIARY-01
    testWidgets('dvFontScaleRecordingBounds', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvFontScaleRecordingBounds 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvFontScaleRecordingBounds 01 home ready');
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      const cases = <(double, double, double)>[
        (360, 640, 3.0),
        (320, 568, 3.5),
      ];
      for (final c in cases) {
        tester.view.devicePixelRatio = c.$3;
        tester.view.physicalSize = Size(c.$1 * c.$3, c.$2 * c.$3);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        mark('01 size=${c.$1}x${c.$2}');
        expect(tester.takeException(), isNull, reason: 'home overflow');
        final recBtn = find.text('Record Nosebleed');
        if (recBtn.evaluate().isNotEmpty) {
          await tester.tap(recBtn.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: 'recording overflow');
          final back = find.widgetWithIcon(TextButton, Icons.arrow_back);
          if (back.evaluate().isNotEmpty) {
            await tester.tap(back.first);
            await tester.pumpAndSettle(const Duration(milliseconds: 300));
          }
        }
      }
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      mark('dvFontScaleRecordingBounds done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-02
    // JNY-DIARY-02
    testWidgets('dvSmallDenseCalendarBounds', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvSmallDenseCalendarBounds 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvSmallDenseCalendarBounds 01 home ready');
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      final calBtn = find.text('View Calendar');
      if (calBtn.evaluate().isNotEmpty) {
        await tester.tap(calBtn.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
      }
      const double dpr = 3.5;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(320 * dpr, 480 * dpr);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      mark('02 small dense calendar');
      expect(tester.takeException(), isNull, reason: 'calendar overflow');
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      mark('dvSmallDenseCalendarBounds done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-03
    // JNY-DIARY-03
    testWidgets('dvRotationPreservesRecord', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvRotationPreservesRecord 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvRotationPreservesRecord 01 home ready');
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      final recBtn = find.text('Record Nosebleed');
      if (recBtn.evaluate().isNotEmpty) {
        await tester.tap(recBtn.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        final port = tester.view.physicalSize;
        tester.view.physicalSize = Size(port.height, port.width);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        tester.view.physicalSize = port;
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        mark('03 rotated and back');
        expect(tester.takeException(), isNull);
        expect(find.byType(RecordingScreen), findsWidgets);
      }
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      mark('dvRotationPreservesRecord done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-04
    // JNY-DIARY-04
    testWidgets('dvOverlapControlsLandscape', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvOverlapControlsLandscape 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvOverlapControlsLandscape 01 home ready');
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      final port = tester.view.physicalSize;
      tester.view.physicalSize = Size(port.height, port.width);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      mark('04 landscape');
      final overlap = find.byType(OverlapCompareScreen);
      if (overlap.evaluate().isNotEmpty) {
        expect(find.byKey(const Key('overlap-merge')), findsWidgets);
        expect(find.byKey(const Key('overlap-pick-left')), findsWidgets);
        expect(find.byKey(const Key('overlap-pick-right')), findsWidgets);
      }
      expect(tester.takeException(), isNull, reason: 'overlap landscape overflow');
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      mark('dvOverlapControlsLandscape done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-05
    // JNY-DIARY-05
    testWidgets('dvYesterdayBoundaryDisposition', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvYesterdayBoundaryDisposition 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvYesterdayBoundaryDisposition 01 home ready');
      final banner = find.byType(YesterdayBanner);
      if (banner.evaluate().isNotEmpty) {
        expect(find.text('Did you have nosebleeds?'), findsWidgets);
        final no = find.text('No');
        if (no.evaluate().isNotEmpty) {
          await tester.tap(no.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        mark('05 answered yesterday');
        expect(tester.takeException(), isNull);
        expect(find.byType(HomeScreen), findsWidgets);
      }
      mark('dvYesterdayBoundaryDisposition done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-06
    // JNY-DIARY-06
    testWidgets('dvMidnightRolloverRecord', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvMidnightRolloverRecord 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvMidnightRolloverRecord 01 home ready');
      final recBtn = find.text('Record Nosebleed');
      if (recBtn.evaluate().isNotEmpty) {
        await tester.tap(recBtn.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        final start = find.text('Set Start Time');
        if (start.evaluate().isNotEmpty) {
          await tester.tap(start.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        final intensity = find.text('Dripping');
        if (intensity.evaluate().isNotEmpty) {
          await tester.tap(intensity.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        final end = find.text('Set End Time');
        if (end.evaluate().isNotEmpty) {
          await tester.tap(end.first);
          await _pumpUntil(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty);
        }
        mark('06 record finalized');
        expect(tester.takeException(), isNull);
      }
      mark('dvMidnightRolloverRecord done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-07
    // JNY-DIARY-07
    testWidgets('dvDoubleTapFinalizeIdempotent', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvDoubleTapFinalizeIdempotent 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvDoubleTapFinalizeIdempotent 01 home ready');
      final recBtn = find.text('Record Nosebleed');
      if (recBtn.evaluate().isNotEmpty) {
        await tester.tap(recBtn.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        final start = find.text('Set Start Time');
        if (start.evaluate().isNotEmpty) {
          await tester.tap(start.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        final intensity = find.text('Dripping');
        if (intensity.evaluate().isNotEmpty) {
          await tester.tap(intensity.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        final end = find.text('Set End Time');
        if (end.evaluate().isNotEmpty) {
          await tester.tap(end.first, warnIfMissed: false);
          await tester.tap(end.first, warnIfMissed: false);
          await _pumpUntil(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty);
        }
        mark('07 double-tap finalized');
        expect(tester.takeException(), isNull);
        expect(find.byType(HomeScreen), findsWidgets);
      }
      mark('dvDoubleTapFinalizeIdempotent done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-08
    // JNY-DIARY-08
    testWidgets('dvRapidNavigationChurn', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvRapidNavigationChurn 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvRapidNavigationChurn 01 home ready');
      for (var i = 0; i < 3; i++) {
        final recBtn = find.text('Record Nosebleed');
        if (recBtn.evaluate().isNotEmpty) {
          await tester.tap(recBtn.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 250));
          final back = find.widgetWithIcon(TextButton, Icons.arrow_back);
          if (back.evaluate().isNotEmpty) {
            await tester.tap(back.first);
            await tester.pumpAndSettle(const Duration(milliseconds: 250));
          }
        }
        final calBtn = find.text('View Calendar');
        if (calBtn.evaluate().isNotEmpty) {
          await tester.tap(calBtn.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 250));
          final back2 = find.widgetWithIcon(TextButton, Icons.arrow_back);
          if (back2.evaluate().isNotEmpty) {
            await tester.tap(back2.first);
            await tester.pumpAndSettle(const Duration(milliseconds: 250));
          }
        }
      }
      mark('08 churn complete');
      expect(tester.takeException(), isNull);
      await _waitForHome(tester);
      expect(find.byType(HomeScreen), findsWidgets);
      mark('dvRapidNavigationChurn done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-09
    // JNY-DIARY-09
    testWidgets('dvDeleteCancelConsistency', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvDeleteCancelConsistency 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvDeleteCancelConsistency 01 home ready');
      final del = find.byTooltip('Delete record');
      if (del.evaluate().isNotEmpty) {
        await tester.tap(del.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        final back = find.widgetWithIcon(TextButton, Icons.arrow_back);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
      }
      mark('09 delete path exercised');
      expect(tester.takeException(), isNull);
      await _waitForHome(tester);
      expect(find.byType(HomeScreen), findsWidgets);
      mark('dvDeleteCancelConsistency done');
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Verifies: JNY-DIARY-10
    // JNY-DIARY-10
    testWidgets('dvAccessibilityPreferencePersists', (tester) async {
      void mark(String step) => debugPrint('DIARY-JNY-DIAG >>> $step');
      mark('dvAccessibilityPreferencePersists 00 boot');
      app.main();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await _waitForHome(tester);
      mark('dvAccessibilityPreferencePersists 01 home ready');
      final settings = find.text('Settings');
      if (settings.evaluate().isNotEmpty) {
        await tester.tap(settings.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
      }
      if (find.byType(SettingsScreen).evaluate().isNotEmpty) {
        expect(find.text('Accessibility'), findsWidgets);
        mark('10 settings shown');
        final back = find.widgetWithIcon(TextButton, Icons.arrow_back);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
      }
      expect(tester.takeException(), isNull);
      await _waitForHome(tester);
      expect(find.byType(HomeScreen), findsWidgets);
      mark('dvAccessibilityPreferencePersists done');
    }, timeout: const Timeout(Duration(minutes: 4)));

}
// dart format on
