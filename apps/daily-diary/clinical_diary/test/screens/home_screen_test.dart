// Verifies: DIARY-DEV-reactive-read-path/A — the diary list, incomplete-entry
//   reminder, and yesterday banner are derived from the live DiaryView driven
//   through the scope's diary_entries / diary_incomplete views.
// Verifies: DIARY-GUI-epistaxis-record/A — finalized epistaxis rows in the
//   driven view render as entry cards in the grouped list.
// Verifies: DIARY-PRD-incomplete-entry-preservation/B — a driven incomplete row
//   surfaces the incomplete-entry reminder banner.
// Verifies: DIARY-DEV-action-write-path/A — the yesterday banner's "No" and
//   "Don't remember" choices submit record_no_epistaxis_day / record_unknown_day
//   through the scope's actionSubmitter.
//
// Phase 12.5 (CUR-1169): Screen-level coverage for HomeScreen's diary surface on
// the new event_sourcing read/write path. The diary_entries / diary_incomplete
// views are driven via FakeReaction.emitViewUpdate; writes are asserted via
// FakeReaction.submittedActions. The kept (non-diary) concerns — disconnection
// banner, TaskService/FCM — keep their existing stub/mock seams, with a real
// bootstrapped native DiaryScopeRuntime supplying the still-required
// constructor params (wedge check, install-date, incomplete-survey reads).

import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/incomplete_records_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:diary_design_system/diary_design_system.dart' show AppCard;
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:eq/eq.dart' show QuestionnaireFlowScreen;
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaction/reaction.dart' show Authenticated;
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial_data_types/trial_data_types.dart'
    show QuestionnaireType, Task, TaskType;

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

const _deviceId = 'device-test-001';
const _softwareVersion = 'clinical_diary@0.0.0+test';

/// Boots the native event_sourcing diary scope over an in-memory Sembast
/// backend (no outbound destinations -> no SyncCycle). HomeScreen reads its
/// diary surface through the FakeReaction-backed ReActionScope; this scope only
/// supplies the wedge check / install-date / incomplete-survey reads.
Future<DiaryScopeRuntime> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'home-screen-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    localUserId: 'P-test',
  );
}

/// Bounded pumps. Avoids pumpAndSettle infinite-loop on widgets with
/// indefinite animators (e.g., the home-screen scrollbar) while still
/// letting async post-frame work complete via Dart microtasks.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    setUpTestFlavor();
  });

  group('HomeScreen', () {
    late DiaryScopeRuntime runtime;
    late MockEnrollmentService enrollment;
    late TaskService tasks;
    late FakeReaction fake;

    setUp(() async {
      // A FakeReaction provides the ReActionScope the migrated diary surface
      // reads/writes through (DiaryViewBuilder + actionSubmitter) and that the
      // (new-stack) RecordingScreen requires when HomeScreen navigates to it.
      fake = FakeReaction(
        initialAuthStatus: Authenticated(
          principal: Principal.user(
            userId: 'P-test',
            activeRole: 'participant',
            roles: const {'participant'},
          ),
        ),
      );
      // Day-marker submissions return the canonical per-day aggregate id.
      for (var i = 0; i < 10; i++) {
        fake.queueDispatchResult(
          const DispatchSuccess<Object?>('P:day', <String>[]),
        );
      }
      // Fix device timezone to UTC+0 so that toDisplayedDateTime with
      // startTimeZone='UTC' is an identity transform (stored == displayed).
      TimezoneConverter.testDeviceOffsetMinutes = 0;
      TimezoneService.instance.testTimezoneOverride = 'Etc/UTC';
      SharedPreferences.setMockInitialValues({});
      enrollment = MockEnrollmentService();
      tasks = TaskService();
      runtime = await _bootstrap();
    });

    tearDown(() async {
      await fake.dispose();
      await runtime.dispose();
      tasks.dispose();
      TimezoneConverter.testDeviceOffsetMinutes = null;
      TimezoneService.instance.testTimezoneOverride = null;
    });

    /// `yyyy-MM-dd` for [day].
    String dateKey(DateTime day) =>
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    /// Drive the diary_entries (finalized) view with [finalized] rows and the
    /// diary_incomplete view with [incomplete] rows, each terminated by an
    /// EndOfReplay so the DiaryViewBuilder leaves its initial state.
    void seedDiary({
      List<DiaryEntryRow> finalized = const [],
      List<DiaryEntryRow> incomplete = const [],
    }) {
      for (final r in finalized) {
        fake.emitViewUpdate<DiaryEntryRow>(
          diaryEntriesViewName,
          Snapshot<DiaryEntryRow>(value: r, sequence: 0),
        );
      }
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryEntriesViewName,
        const EndOfReplay<DiaryEntryRow>(sequence: 0),
      );
      for (final r in incomplete) {
        fake.emitViewUpdate<DiaryEntryRow>(
          diaryIncompleteViewName,
          Snapshot<DiaryEntryRow>(value: r, sequence: 0),
        );
      }
      fake.emitViewUpdate<DiaryEntryRow>(
        diaryIncompleteViewName,
        const EndOfReplay<DiaryEntryRow>(sequence: 0),
      );
    }

    DiaryEntryRow epistaxisRow(
      DateTime start, {
      required String aggregateId,
      DateTime? end,
    }) {
      final payload = EpistaxisEventPayload(
        startTime: start.toIso8601String(),
        startTimeZone: 'UTC',
        startTimeUtcOffset: '+00:00',
        participantId: 'P-test',
        endTime: end?.toIso8601String(),
        endTimeZone: end == null ? null : 'UTC',
        endTimeUtcOffset: end == null ? null : '+00:00',
        intensity: NosebleedIntensity.dripping,
      );
      return DiaryEntryRow(
        aggregateId: aggregateId,
        entryType: 'epistaxis_event',
        data: payload.toJson(),
      );
    }

    DiaryEntryRow surveyRow(
      DateTime completedAt, {
      required String aggregateId,
      String questionnaireType = 'nose_hht',
    }) {
      final payload = QuestionnaireSubmissionPayload(
        instanceId: aggregateId,
        questionnaireType: questionnaireType,
        schemaVersion: 's1',
        contentVersion: 'c1',
        guiVersion: 'g1',
        completedAt: completedAt.toIso8601String(),
        responses: const {'q1': QuestionResponse(value: 1)},
      );
      return DiaryEntryRow(
        aggregateId: aggregateId,
        entryType: '${questionnaireType}_survey',
        data: payload.toJson(),
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      List<DiaryEntryRow> finalized = const [],
      List<DiaryEntryRow> incomplete = const [],
      Future<bool> Function()? nativeFifoWedged,
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
            HomeScreen(
              diaryScope: runtime,
              deviceId: _deviceId,
              enrollmentService: enrollment,
              taskService: tasks,
              nativeFifoWedged: nativeFifoWedged,
            ),
          ),
        ),
      );
      // Pump a frame so the DiaryViewBuilder subscribes, then feed view rows.
      await tester.pump();
      seedDiary(finalized: finalized, incomplete: incomplete);
      await _settle(tester);
    }

    /// The single submission for [actionName], or fails if none/many.
    ActionSubmission submissionFor(String actionName) {
      final matches = fake.submittedActions
          .where((s) => s.actionName == actionName)
          .toList();
      expect(matches, hasLength(1), reason: 'expected one $actionName');
      return matches.single;
    }

    // Verifies: DIARY-DEV-native-outbound-sync/B — a wedged FIFO on the NEW
    //   event_sourcing store (diary_es.db), where DiaryServerDestination's
    //   outbound FIFO lives, is surfaced to the participant. The legacy
    //   runtime.backend wedge check does not see that store.
    //
    // The wedge banner is now an AppBanner with separate title + message texts.
    const wedgeTitle = 'Some data is not syncing';
    const wedgeMessage = 'Please update the app.';

    testWidgets(
      'native-store FIFO wedge surfaces the sync-wedged banner (legacy clean)',
      (tester) async {
        // Legacy runtime.backend is a fresh in-memory store with no wedged FIFO;
        // only the native store is wedged. The banner must still surface.
        await pumpScreen(tester, nativeFifoWedged: () async => true);
        expect(find.text(wedgeTitle), findsOneWidget);
        expect(find.text(wedgeMessage), findsOneWidget);
      },
    );

    testWidgets(
      'no wedge banner when neither legacy nor native store is wedged',
      (tester) async {
        await pumpScreen(tester, nativeFifoWedged: () async => false);
        expect(find.text(wedgeTitle), findsNothing);
        expect(find.text(wedgeMessage), findsNothing);
      },
    );

    testWidgets(
      'renders empty state with the record button and yesterday banner',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Record Nosebleed'), findsOneWidget);
        // The calendar affordance is now the tertiary "View Calendar" button
        // pinned in the bottom action area.
        expect(find.text('View Calendar'), findsOneWidget);
        // No-yesterday banner is present (no entries → no yesterday records).
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-main-screen-layout-A — with nothing requiring
    //   attention (no incomplete records, no overlaps, no tasks) the whole
    //   Task List section is hidden rather than showing an empty
    //   "Needs your attention (0)" tile (CUR-1519).
    testWidgets(
      'hides the Task List section entirely when there are zero tasks',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Task List'), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
      },
    );

    testWidgets('renders a driven finalized epistaxis_event in the list', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9);
      await pumpScreen(
        tester,
        finalized: [
          epistaxisRow(
            today,
            aggregateId: 'agg-home-1',
            end: today.add(const Duration(minutes: 30)),
          ),
        ],
      );

      // The driven row renders as an entry card with its duration ("30m").
      expect(find.byType(RecordingScreen), findsNothing);
      expect(find.byType(EventListItem), findsWidgets);
      expect(find.text('30m'), findsOneWidget);
    });

    // Verifies: DIARY-PRD-questionnaire-system/B — a finalized `<id>_survey`
    //   dated today renders as a completed-survey card in the today section.
    testWidgets('renders a driven finalized survey in the today list', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 11);
      await pumpScreen(
        tester,
        finalized: [surveyRow(today, aggregateId: 'agg-survey-1')],
      );

      expect(find.byType(EventListItem), findsWidgets);
      // The survey card surfaces with its friendly name + completion affordance.
      expect(find.byKey(const Key('survey-card')), findsOneWidget);
      expect(find.text('NOSE HHT Survey'), findsOneWidget);
    });

    testWidgets(
      'shows the incomplete-entry reminder for a driven incomplete row',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10);
        await pumpScreen(
          tester,
          incomplete: [epistaxisRow(today, aggregateId: 'agg-incomplete-1')],
        );

        // The orange incomplete-records reminder shows its count. As the only
        // active important item it occupies the inline top slot (no collapse).
        expect(find.text('1 incomplete record'), findsOneWidget);
        expect(find.textContaining('more important item'), findsNothing);
      },
    );

    testWidgets(
      'tap "No" on yesterday banner submits record_no_epistaxis_day',
      (tester) async {
        await pumpScreen(tester);

        final noButton = find.text('No');
        expect(noButton, findsOneWidget);
        await tester.tap(noButton, warnIfMissed: false);
        await _settle(tester);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final s = submissionFor('record_no_epistaxis_day');
        expect(s.rawInput['date'], dateKey(yesterday));
      },
    );

    testWidgets(
      'tap "Don\'t remember" on yesterday banner submits record_unknown_day',
      (tester) async {
        await pumpScreen(tester);

        final dontRememberButton = find.text("Don't remember");
        expect(dontRememberButton, findsOneWidget);
        await tester.tap(dontRememberButton, warnIfMissed: false);
        await _settle(tester);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final s = submissionFor('record_unknown_day');
        expect(s.rawInput['date'], dateKey(yesterday));
      },
    );

    testWidgets(
      'a driven finalized day-marker on yesterday hides the yesterday banner',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await pumpScreen(
          tester,
          finalized: [
            DiaryEntryRow(
              aggregateId: 'P:${dateKey(yesterday)}',
              entryType: 'no_epistaxis_event',
              data: <String, Object?>{'date': dateKey(yesterday)},
            ),
          ],
        );

        // With yesterday covered, the confirm banner's choices are gone.
        expect(find.text("Don't remember"), findsNothing);
      },
    );

    // CUR-1491: a recorded "don't remember" (unknown_day_event) marker on
    // yesterday must surface as its own status row — NOT fall through to the
    // bare "No records" empty state. "nothing recorded" and "acknowledged
    // uncertainty" are different clinical states (cf. REQ-CAL-d00012).
    testWidgets(
      'a finalized "don\'t remember" marker on yesterday shows the unknown '
      'status row, not "No records"',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await pumpScreen(
          tester,
          finalized: [
            DiaryEntryRow(
              aggregateId: 'P:${dateKey(yesterday)}',
              entryType: 'unknown_day_event',
              data: <String, Object?>{'date': dateKey(yesterday)},
            ),
          ],
        );

        // The banner is gone and the marker renders its distinct "Don't
        // remember" status (CUR-1491: minimal muted row, label reads
        // "Don't remember" — not "Unknown").
        expect(find.text("Don't remember"), findsOneWidget);
        expect(find.text('Unknown'), findsNothing);

        // The yesterday card must NOT fall through to the "No records" empty
        // placeholder (today's empty card may still show one — scope the
        // check to the Yesterday card via its "Yesterday" header label).
        final yesterdayCard = find.ancestor(
          of: find.text('Yesterday'),
          matching: find.byType(AppCard),
        );
        expect(yesterdayCard, findsOneWidget);
        expect(
          find.descendant(of: yesterdayCard, matching: find.text('No records')),
          findsNothing,
          reason:
              'the yesterday section must reflect the recorded '
              '"don\'t remember" marker, never "No records"',
        );
      },
    );

    // CUR-1491 companion: a "no nosebleeds" marker likewise surfaces as its
    // own row rather than "No records".
    testWidgets(
      'a finalized "no nosebleeds" marker on yesterday shows its status row, '
      'not "No records"',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await pumpScreen(
          tester,
          finalized: [
            DiaryEntryRow(
              aggregateId: 'P:${dateKey(yesterday)}',
              entryType: 'no_epistaxis_event',
              data: <String, Object?>{'date': dateKey(yesterday)},
            ),
          ],
        );

        expect(find.text('No nosebleeds'), findsOneWidget);
        final yesterdayCard = find.ancestor(
          of: find.text('Yesterday'),
          matching: find.byType(AppCard),
        );
        expect(
          find.descendant(of: yesterdayCard, matching: find.text('No records')),
          findsNothing,
        );
      },
    );

    testWidgets('tap "Record Nosebleed" pushes the recording screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      final recordButton = find.widgetWithText(
        FilledButton,
        'Record Nosebleed',
      );
      expect(recordButton, findsOneWidget);
      await tester.tap(recordButton, warnIfMissed: false);
      await _settle(tester);

      expect(
        find.byType(RecordingScreen),
        findsOneWidget,
        reason: 'Tapping the record button should push the recording screen',
      );
    });

    testWidgets('disconnection banner shows when enrollment is disconnected', (
      tester,
    ) async {
      // Kept (non-diary) concern: drive the legacy enrollment stub to
      // disconnected and confirm the banner still renders alongside the diary
      // surface.
      await enrollment.setDisconnected(true);
      await pumpScreen(tester);

      expect(find.byType(DisconnectionBanner), findsOneWidget);
    });

    testWidgets('shows the overlap banner when two finalized entries overlap', (
      tester,
    ) async {
      final base = DateTime.now();
      final day = DateTime(base.year, base.month, base.day);
      await pumpScreen(
        tester,
        finalized: [
          epistaxisRow(
            day.add(const Duration(hours: 13)),
            aggregateId: 'ov-a',
            end: day.add(const Duration(hours: 14)),
          ),
          epistaxisRow(
            day.add(const Duration(hours: 13, minutes: 30)),
            aggregateId: 'ov-b',
            end: day.add(const Duration(hours: 13, minutes: 45)),
          ),
        ],
      );

      expect(find.textContaining('needs resolving'), findsOneWidget);
    });

    // Verifies: DIARY-GUI-main-screen-layout-A — when more than one important
    //   item is active, the disconnection notice keeps its bespoke inline
    //   banner while every actionable item is consolidated as a row inside the
    //   single "Needs your attention" tile (so the alert area stays bounded
    //   regardless of how many fire at once).
    testWidgets(
      'multiple alerts: inline disconnection banner + items consolidated in '
      'the "Needs your attention" tile',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10);
        // Disconnection (highest priority) + an incomplete record = two alerts.
        await enrollment.setDisconnected(true);
        await pumpScreen(
          tester,
          incomplete: [epistaxisRow(today, aggregateId: 'agg-inc-1')],
        );

        // Disconnection keeps its bespoke inline banner above the tile.
        expect(find.byType(DisconnectionBanner), findsOneWidget);
        // The incomplete alert renders as a row inside the consolidated
        // "Needs your attention" tile, not as a free-floating banner.
        expect(find.text('Needs your attention'), findsOneWidget);
        expect(find.text('1 incomplete record'), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-main-screen-layout-A — the consolidated
    //   incomplete-records row in the "Needs your attention" tile opens the
    //   Incomplete Records page listing every incomplete item (the overflow
    //   destination that replaced the legacy Important page).
    // Verifies: DIARY-PRD-incomplete-entry-preservation/B — with more than one
    //   incomplete record, the row opens the dedicated list so the participant
    //   picks which to resume.
    testWidgets(
      'the incomplete-records row opens the Incomplete Records page with all '
      'items',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10);
        final incompleteRows = [
          epistaxisRow(today, aggregateId: 'agg-inc-1'),
          epistaxisRow(
            today.add(const Duration(hours: 2)),
            aggregateId: 'agg-inc-2',
          ),
        ];
        await pumpScreen(tester, incomplete: incompleteRows);

        await tester.tap(find.text('2 incomplete records'));
        await _settle(tester);

        expect(find.byType(IncompleteRecordsScreen), findsOneWidget);
        // The pushed screen's DiaryViewBuilder subscribes fresh and the fake's
        // view stream has no replay buffer — re-drive the incomplete view so
        // the new subscriber receives the rows.
        seedDiary(incomplete: incompleteRows);
        await _settle(tester);

        expect(find.text('Incomplete Records'), findsOneWidget);
        // The full list: both incomplete items that were consolidated behind
        // the single home-screen row.
        expect(find.text('Incomplete Record'), findsNWidgets(2));
      },
    );

    // ---- CUR-1523: questionnaire categorization + re-open + read-only -------

    /// Adds a NOSE HHT questionnaire task whose instance id is [instanceId].
    Task addQuestionnaireTask(String instanceId) {
      final task = Task(
        id: instanceId,
        taskType: TaskType.questionnaire,
        title: QuestionnaireType.noseHht.displayName,
        createdAt: DateTime.now(),
        targetId: instanceId,
        questionnaireType: QuestionnaireType.noseHht,
        status: 'sent',
      );
      tasks.addTask(task);
      return task;
    }

    /// Adds a NOSE HHT questionnaire task whose portal-reported [status] is
    /// 'finalized' (the state after the portal coordinator finalizes the
    /// submission). No local `<id>_survey` row is implied.
    Task addFinalizedStatusTask(String instanceId) {
      final task = Task(
        id: instanceId,
        taskType: TaskType.questionnaire,
        title: QuestionnaireType.noseHht.displayName,
        createdAt: DateTime.now(),
        targetId: instanceId,
        questionnaireType: QuestionnaireType.noseHht,
        status: 'finalized',
      );
      tasks.addTask(task);
      return task;
    }

    /// Mints a `questionnaire_finalized` lifecycle event into the native scope's
    /// questionnaire_status view (the same path QuestionnaireStatusSync uses), so
    /// the one-shot read sees [instanceId] as finalized (read-only).
    ///
    /// The native scope is backed by a real (Sembast-memory) event store whose
    /// appends use real async timers; those don't progress under the widget
    /// test's fake-async clock, so the submit must run in `tester.runAsync`.
    Future<void> finalizeInstance(
      WidgetTester tester,
      String instanceId,
    ) async {
      await tester.runAsync(() async {
        await runtime.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'record_questionnaire_finalized',
            rawInput: {'instance_id': instanceId},
          ),
        );
      });
    }

    /// The single pushed QuestionnaireFlowScreen, or fails if none/many.
    QuestionnaireFlowScreen flowScreen(WidgetTester tester) {
      final matches = find.byType(QuestionnaireFlowScreen);
      expect(matches, findsOneWidget);
      return tester.widget<QuestionnaireFlowScreen>(matches);
    }

    // Verifies: DIARY-GUI-participant-task-list/J — after submission a
    //   questionnaire task whose instance has a local finalized `<id>_survey`
    //   row renders a completed visual state and is no longer an actionable item
    //   inside the "Needs your attention" tile (no removeTask).
    testWidgets(
      'a submitted questionnaire task renders completed and is out of '
      '"Needs your attention"',
      (tester) async {
        const instanceId = 'q-submitted-1';
        addQuestionnaireTask(instanceId);
        final now = DateTime.now();
        await pumpScreen(
          tester,
          finalized: [
            surveyRow(
              DateTime(now.year, now.month, now.day, 9),
              aggregateId: instanceId,
            ),
          ],
        );

        // The Task List section is present (a completed task still surfaces),
        // but the submitted task is NOT counted in "Needs your attention".
        expect(find.text('Task List'), findsOneWidget);
        // With the only questionnaire task submitted and no other actionable
        // items, the "Needs your attention" tile is absent (count == 0).
        expect(find.text('Needs your attention'), findsNothing);
        // The completed row surfaces as its own "submitted, awaiting review"
        // affordance, keyed by the instance id.
        expect(
          find.byKey(const Key('completed-task-q-submitted-1')),
          findsOneWidget,
        );
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/K — while a questionnaire task
    //   is submitted (not finalized) the participant can select it to review and
    //   edit; the flow opens with the prior answers prefilled and editable.
    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/R — re-open a
    //   submitted survey to the editable Review Screen seeded with prior answers.
    testWidgets(
      'selecting a submitted (not finalized) task opens the editable Review '
      'Screen prefilled with prior answers',
      (tester) async {
        const instanceId = 'q-submitted-2';
        addQuestionnaireTask(instanceId);
        final now = DateTime.now();
        await pumpScreen(
          tester,
          finalized: [
            surveyRow(
              DateTime(now.year, now.month, now.day, 9),
              aggregateId: instanceId,
            ),
          ],
        );

        await tester.tap(find.byKey(const Key('completed-task-q-submitted-2')));
        await _settle(tester);

        final flow = flowScreen(tester);
        expect(flow.isReadOnly, isFalse);
        expect(flow.initialResponses, isNotNull);
        expect(flow.initialResponses, isNotEmpty);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S — a task whose
    //   instance is finalized in the questionnaire_status view opens read-only.
    testWidgets(
      'selecting a finalized task opens the questionnaire flow read-only',
      (tester) async {
        const instanceId = 'q-finalized-1';
        addQuestionnaireTask(instanceId);
        await finalizeInstance(tester, instanceId);
        final now = DateTime.now();
        await pumpScreen(
          tester,
          finalized: [
            surveyRow(
              DateTime(now.year, now.month, now.day, 9),
              aggregateId: instanceId,
            ),
          ],
        );

        await tester.tap(find.byKey(const Key('completed-task-q-finalized-1')));
        await _settle(tester);

        final flow = flowScreen(tester);
        expect(flow.isReadOnly, isTrue);
        expect(flow.initialResponses, isNotEmpty);
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/I — the task is removed only when
    //   `/user/tasks` drops it on finalization; submitting a questionnaire does
    //   NOT call removeTask, so the task remains in taskService.tasks (it leaves
    //   "Needs your attention" via categorization, not removal).
    testWidgets(
      'submitting a questionnaire does not remove the task from the task list',
      (tester) async {
        const instanceId = 'q-pending-1';
        addQuestionnaireTask(instanceId);
        await pumpScreen(tester);

        // A pending (not-submitted) task is an actionable item in the tile.
        expect(find.text('Needs your attention'), findsOneWidget);
        expect(find.text('NOSE HHT Survey'), findsOneWidget);

        // Open the fresh flow and drive it to completion via onComplete.
        await tester.tap(find.text('NOSE HHT Survey'));
        await _settle(tester);
        final flow = flowScreen(tester);
        flow.onComplete();
        await _settle(tester);

        // The task is NOT removed — it leaves "needs attention" via
        // categorization only once a finalized survey row exists for it.
        expect(tasks.tasks.map((t) => t.id), contains(instanceId));
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/I+J — a finalized task is
    //   COMPLETED even with no local `<id>_survey` row (reachable after a
    //   diary-reset/reinstall + re-link): it is categorized out of "Needs your
    //   attention" by the portal-reported status alone, not by a local row.
    testWidgets(
      'a finalized task with no local survey row is categorized completed and '
      'absent from "Needs your attention"',
      (tester) async {
        const instanceId = 'q-fin-norow-1';
        addFinalizedStatusTask(instanceId);
        // No survey row driven into the diary view for this instance.
        await pumpScreen(tester);

        expect(find.text('Task List'), findsOneWidget);
        // The only questionnaire task is finalized → no actionable items.
        expect(find.text('Needs your attention'), findsNothing);
        // It surfaces as a completed row keyed by the instance id.
        expect(
          find.byKey(const Key('completed-task-q-fin-norow-1')),
          findsOneWidget,
        );
      },
    );

    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S — a finalized
    //   task with NO local responses must open READ-ONLY (never the editable
    //   flow), so a participant cannot re-fill/submit a finalized questionnaire.
    testWidgets(
      'selecting a finalized task with no local survey row opens read-only and '
      'presents no submittable form',
      (tester) async {
        const instanceId = 'q-fin-norow-2';
        addFinalizedStatusTask(instanceId);
        await pumpScreen(tester);

        await tester.tap(find.byKey(const Key('completed-task-q-fin-norow-2')));
        await _settle(tester);

        final flow = flowScreen(tester);
        expect(flow.isReadOnly, isTrue);
        // Read-only surface: the "Submitted Answers" review, with no Submit
        // button — the editable flow is never reachable.
        expect(find.text('Submitted Answers'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Submit'), findsNothing);
      },
    );
  });
}
