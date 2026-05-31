// Verifies: DIARY-PRD-incomplete-entry-preservation/A+C
// Verifies: DIARY-GUI-epistaxis-record/A
// Verifies: DIARY-PRD-entry-time-restrictions/D
// Verifies: DIARY-DEV-action-write-path/A
// Verifies: DIARY-DEV-reactive-read-path/A
// Verifies: DIARY-GUI-entry-overlap-resolution
//
// Screen-level coverage for the multi-step RecordingScreen on the new
// event_sourcing write path. Writes are asserted via FakeReaction
// (queueDispatchResult + submittedActions); overlap rows are seeded by emitting
// view updates on the diary_entries view.

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingScreen', () {
    late FakeReaction fake;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeReaction();
      // Device timezone fixed to UTC so stored == displayed (identity).
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      // Generous queue of successes for every submit(). Actions that return an
      // aggregate id (record/checkpoint) get a String result.
      for (var i = 0; i < 10; i++) {
        fake.queueDispatchResult(
          const DispatchSuccess<Object?>('minted-aggregate-id', <String>[]),
        );
      }
    });

    tearDown(() async {
      TimezoneConverter.testDeviceOffsetMinutes = null;
      await fake.dispose();
    });

    // Clinical rules (justification/lock gate, duration confirmations, review
    // screen) now come from the event-sourced settings via ClinicalRulesScope —
    // not FeatureFlagService. Default is "no restriction"; tests that exercise a
    // rule pass an explicit [rules].
    Future<void> pumpScreen(
      WidgetTester tester, {
      EpistaxisEntryView? existing,
      DateTime? initialDate,
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
              child: RecordingScreen(
                existing: existing,
                initialDate: initialDate,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Drive the diary_entries view with one finalized [rows] snapshot followed
    /// by EndOfReplay, so the screen's DiaryViewBuilder sees them as live.
    void seedDiaryEntries(List<EpistaxisEntryView> rows) {
      for (final r in rows) {
        fake.emitViewUpdate<DiaryEntryRow>(
          diaryEntriesViewName,
          Snapshot<DiaryEntryRow>(value: r.row, sequence: 0),
        );
      }
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryEntriesViewName,
        const EndOfReplay<DiaryEntryRow>(sequence: 0),
      );
    }

    /// The single submission for [actionName], or fails if none/many.
    ActionSubmission submissionFor(String actionName) {
      final matches = fake.submittedActions
          .where((s) => s.actionName == actionName)
          .toList();
      expect(
        matches,
        hasLength(1),
        reason:
            'expected exactly one $actionName submission, '
            'got ${fake.submittedActions.map((s) => s.actionName).toList()}',
      );
      return matches.single;
    }

    // ---------------------------------------------------------------------
    // Step-flow / clinical-rule coverage (adapted to the new write path).
    // ---------------------------------------------------------------------

    testWidgets(
      'initial render shows start time picker, summary bar, and date header',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Max Intensity'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Set Start Time confirm advances to the intensity step',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        expect(find.byType(IntensityPicker), findsOneWidget);
      },
    );

    // CUR-560: modifying start time on an entry with intensity already set
    // skips the intensity step.
    testWidgets(
      'skips intensity and advances to end time when intensity already set',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final existing = buildEpistaxisView(
          aggregateId: 'agg-cur560',
          startTime: start,
          intensity: NosebleedIntensity.dripping,
          isComplete: false,
        );

        await pumpScreen(tester, existing: existing);
        expect(find.text('Nosebleed End Time'), findsOneWidget);

        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        expect(find.text('Nosebleed Start'), findsOneWidget);

        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        expect(find.text('Nosebleed End Time'), findsOneWidget);
        expect(find.byType(IntensityPicker), findsNothing);
      },
    );

    testWidgets(
      'editing entry that is missing intensity opens the intensity step',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisView(
          aggregateId: 'agg-incomplete-1',
          startTime: start,
          isComplete: false,
        );

        await pumpScreen(tester, existing: existing);

        expect(find.byType(IntensityPicker), findsOneWidget);
      },
    );

    // ---------------------------------------------------------------------
    // Decision-table coverage.
    // ---------------------------------------------------------------------

    testWidgets(
      'Complete a brand-new entry -> one record_epistaxis_event submission',
      (tester) async {
        await pumpScreen(tester);

        // Step 1: confirm start -> intensity.
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Step 2: pick Dripping.
        await tester.tap(
          find.descendant(
            of: find.byType(IntensityPicker),
            matching: find.text('Dripping'),
          ),
        );
        await tester.pumpAndSettle();

        // Step 3: confirm end -> saves immediately (useReviewScreen=false).
        await tester.tap(find.text('Set End Time'));
        await tester.pump();

        final s = submissionFor('record_epistaxis_event');
        expect(s.rawInput['startTime'], isNotNull);
        expect(s.rawInput['startTimeZone'], isNotNull);
        expect(s.rawInput['startTimeUtcOffset'], isNotNull);
        expect(s.rawInput['endTime'], isNotNull);
        expect(s.rawInput['intensity'], 'dripping');
        expect(s.rawInput.containsKey('aggregateId'), isFalse);
      },
    );

    testWidgets(
      'Complete a resumed draft -> edit_epistaxis_event on the same aggregateId',
      (tester) async {
        final now = DateTime.now();
        // Whole-minute start safely in the past, so the end-time dial (which
        // snaps to minutes) does not produce a value before start.
        final start = DateTime(now.year, now.month, now.day - 1, 10);
        // Resumed draft: has start + intensity, no end, not complete.
        final existing = buildEpistaxisView(
          aggregateId: 'agg-resume-1',
          startTime: start,
          intensity: NosebleedIntensity.dripping,
          isComplete: false,
        );

        await pumpScreen(tester, existing: existing);
        // Lands on the end-time step.
        expect(find.text('Nosebleed End Time'), findsOneWidget);

        await tester.tap(find.text('Set End Time'));
        await tester.pump();

        final s = submissionFor('edit_epistaxis_event');
        expect(s.rawInput['aggregateId'], 'agg-resume-1');
        expect(s.rawInput['intensity'], 'dripping');
        expect(s.rawInput['endTime'], isNotNull);
        // A finalize must NOT also write a checkpoint.
        expect(
          fake.submittedActions.where(
            (a) => a.actionName == 'checkpoint_epistaxis_event',
          ),
          isEmpty,
        );
      },
    );

    testWidgets('Back out of a brand-new partial -> checkpoint_epistaxis_event '
        '(aggregateId null) with the partial payload', (tester) async {
      await pumpScreen(tester);

      // Confirm only the start time (partial: no intensity, no end).
      await tester.tap(find.text('Set Start Time'));
      await tester.pumpAndSettle();

      // Back out -> auto-save as a checkpoint.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      final s = submissionFor('checkpoint_epistaxis_event');
      expect(s.rawInput['aggregateId'], isNull);
      expect(s.rawInput['startTime'], isNotNull);
      // Partial: no end time / intensity carried.
      expect(s.rawInput.containsKey('endTime'), isFalse);
      expect(s.rawInput.containsKey('intensity'), isFalse);
    });

    testWidgets(
      'Back out while editing a finalized entry -> edit_epistaxis_event '
      '(NOT checkpoint)',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 3));
        final end = DateTime.now().subtract(const Duration(hours: 2));
        final existing = buildEpistaxisView(
          aggregateId: 'agg-finalized-1',
          startTime: start,
          endTime: end,
          endTimeZone: 'UTC',
          intensity: NosebleedIntensity.dripping,
        );

        await pumpScreen(tester, existing: existing);

        // Change something so there is an unsaved partial to auto-save.
        await tester.tap(find.text('Max Intensity'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(IntensityPicker),
            matching: find.text('Spotting'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        final s = submissionFor('edit_epistaxis_event');
        expect(s.rawInput['aggregateId'], 'agg-finalized-1');
        expect(
          fake.submittedActions.where(
            (a) => a.actionName == 'checkpoint_epistaxis_event',
          ),
          isEmpty,
        );
      },
    );

    testWidgets(
      'Delete -> delete_entry with {aggregateId, entryType, changeReason}',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final end = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisView(
          aggregateId: 'agg-del-1',
          startTime: start,
          endTime: end,
          endTimeZone: 'UTC',
          intensity: NosebleedIntensity.spotting,
        );

        await pumpScreen(tester, existing: existing);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pump();

        final s = submissionFor('delete_entry');
        expect(s.rawInput['aggregateId'], 'agg-del-1');
        expect(s.rawInput['entryType'], 'epistaxis_event');
        expect(s.rawInput['changeReason'], 'entered-in-error');
      },
    );

    testWidgets(
      'editing existing entry on the review screen submits edit_epistaxis_event '
      'with the same aggregateId',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final end = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisView(
          aggregateId: 'agg-edit-1',
          startTime: start,
          endTime: end,
          endTimeZone: 'UTC',
          intensity: NosebleedIntensity.dripping,
        );

        await pumpScreen(
          tester,
          existing: existing,
          rules: const ClinicalRules(useReviewScreen: true),
        );

        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton, warnIfMissed: false);
        await tester.pump();

        final s = submissionFor('edit_epistaxis_event');
        expect(s.rawInput['aggregateId'], 'agg-edit-1');
      },
    );

    // Verifies: DIARY-PRD-entry-time-restrictions — a date past the lock
    //   threshold is read-only: lock banner shown, delete hidden, and an
    //   explicit save is refused (no submission).
    testWidgets('locked date is read-only (banner, no delete, save blocked)', (
      tester,
    ) async {
      final start = DateTime.now().subtract(const Duration(hours: 5));
      final existing = buildEpistaxisView(
        aggregateId: 'agg-locked',
        startTime: start,
        endTime: DateTime.now().subtract(const Duration(hours: 4)),
        endTimeZone: 'UTC',
        intensity: NosebleedIntensity.dripping,
      );

      await pumpScreen(
        tester,
        existing: existing,
        // lockThreshold 1h + entry 5h old + trialStart null => locked.
        rules: const ClinicalRules(
          gate: EntryGateRules(lockThreshold: Duration(hours: 1)),
        ),
      );

      expect(find.textContaining('locked'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Even if a Save button is reachable, the locked guard refuses to submit.
      final save = find.widgetWithText(FilledButton, 'Save Changes');
      if (save.evaluate().isNotEmpty) {
        await tester.tap(save, warnIfMissed: false);
        await tester.pump();
      }
      expect(
        fake.submittedActions.where(
          (s) => s.actionName == 'edit_epistaxis_event',
        ),
        isEmpty,
      );
    });

    // Regression: the screen is pushed as `Navigator.push<String?>` (e.g. the
    // day-disposition + home resume flows). Discarding a brand-new entry via the
    // trash icon must pop a String? (null), NOT a bool — popping `true` threw
    // "type 'bool' is not a subtype of type 'String?'" and the trash did nothing.
    testWidgets('trash on a new entry pops null on a String?-typed route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? popResult = 'sentinel';
      var popped = false;
      await tester.pumpWidget(
        ReActionScope(
          scope: fake,
          child: wrapWithMaterialApp(
            Builder(
              builder: (hostContext) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popResult = await Navigator.of(hostContext).push<String?>(
                        MaterialPageRoute<String?>(
                          builder: (_) => const ClinicalRulesScope(
                            rules: ClinicalRules(),
                            child: RecordingScreen(),
                          ),
                        ),
                      );
                      popped = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // On the recording screen now; tap the trash (new entry, nothing saved).
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        popped,
        isTrue,
        reason: 'route should have popped (no type error)',
      );
      expect(popResult, isNull);
      expect(find.text('open'), findsOneWidget); // back on the host
    });

    // ---------------------------------------------------------------------
    // Overlap.
    // ---------------------------------------------------------------------

    testWidgets(
      'overlap on an explicit save is blocked (snackbar, no submission)',
      (tester) async {
        final base = DateTime.now();
        final today1pm = DateTime(base.year, base.month, base.day, 13);
        final today2pm = DateTime(base.year, base.month, base.day, 14);
        final other = buildEpistaxisView(
          aggregateId: 'agg-overlap-other',
          startTime: today1pm,
          endTime: today2pm,
          endTimeZone: 'UTC',
          intensity: NosebleedIntensity.dripping,
        );

        // Editing entry overlaps the seeded one; lands on the review screen.
        final today130 = DateTime(base.year, base.month, base.day, 13, 30);
        final today145 = DateTime(base.year, base.month, base.day, 13, 45);
        final editing = buildEpistaxisView(
          aggregateId: 'agg-overlap-self',
          startTime: today130,
          endTime: today145,
          endTimeZone: 'UTC',
          intensity: NosebleedIntensity.dripping,
        );

        await pumpScreen(
          tester,
          existing: editing,
          rules: const ClinicalRules(useReviewScreen: true),
        );

        // Seed the overlapping finalized row into the diary_entries view.
        seedDiaryEntries([other]);
        await tester.pumpAndSettle();

        expect(find.text('Overlapping Events Detected'), findsOneWidget);

        // An explicit "Save Changes" is blocked.
        await tester.tap(
          find.widgetWithText(FilledButton, 'Save Changes'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(
          fake.submittedActions.where(
            (a) => a.actionName == 'edit_epistaxis_event',
          ),
          isEmpty,
        );
      },
    );
  });
}
