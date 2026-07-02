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
import 'package:trial_data_types/trial_data_types.dart'
    as tdt
    show QuestionnaireSubmission, QuestionResponse;

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

const _deviceId = 'device-test-001';
const _softwareVersion = 'clinical_diary@0.0.0+test';

/// Boots the native event_sourcing diary scope over an in-memory Sembast
/// backend (no outbound destinations -> no SyncCycle). HomeScreen reads its
/// diary surface through the FakeReaction-backed ReActionScope; this scope only
/// supplies the wedge check / install-date / incomplete-survey reads.
///
/// `nose_hht_survey` is registered as an extra entry type so tests can seed
/// a submitted survey into the native store via `seedNativeSurvey`, which
/// `_hasLocalSurveyRow` queries to determine whether the participant engaged.
Future<DiaryScopeRuntime> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'home-screen-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    localUserId: 'P-test',
    extraEntryTypes: const [
      EntryTypeDefinition(
        id: 'nose_hht_survey',
        registeredVersion: 1,
        name: 'nose_hht',
      ),
    ],
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

    // Verifies: DIARY-GUI-main-screen-layout/A — with nothing requiring
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

    // Verifies: DIARY-PRD-questionnaire-portal-sent-rules/H — a questionnaire
    //   `checkpoint` draft lives in the same diary_incomplete projection as
    //   nosebleed checkpoints, but it is NOT a clinical "incomplete record": it
    //   resumes via the Task List, not the incomplete-records reminder (whose
    //   click path edits epistaxis only). So a survey-only incomplete must not
    //   inflate the "incomplete records" count (CUR-1522 regression guard).
    testWidgets(
      'a questionnaire checkpoint draft does NOT count as an incomplete record',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10);
        await pumpScreen(
          tester,
          incomplete: [
            surveyRow(
              today,
              aggregateId: 'q-draft-1',
              questionnaireType: 'nose_hht',
            ),
          ],
        );

        expect(find.textContaining('incomplete record'), findsNothing);
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
    // uncertainty" are different clinical states (cf. DIARY-PRD-day-disposition/A).
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

    // Verifies: DIARY-GUI-main-screen-layout/A — when more than one important
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

    // Verifies: DIARY-GUI-main-screen-layout/A — the consolidated
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

    // Verifies: DIARY-DEV-inbound-event-on-receipt/C — a recalled questionnaire
    //   is surfaced via the recall dialog / silent ack, NOT as an actionable
    //   task. A status:recalled task must never render in the Task List during
    //   the window before the portal self-cleans and the poll drops it.
    testWidgets(
      'a status:recalled questionnaire task is excluded from the Task List',
      (tester) async {
        tasks.addTask(
          Task(
            id: 'q-recalled-1',
            taskType: TaskType.questionnaire,
            title: 'Questionnaire',
            createdAt: DateTime.now(),
            targetId: 'q-recalled-1',
            status: 'recalled',
          ),
        );
        await pumpScreen(tester);

        // The recalled task is the only task → the whole Task List section is
        // hidden (count == 0) and the task never appears as an attention item.
        expect(find.text('Task List'), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
        expect(find.text('Questionnaire'), findsNothing);
      },
    );

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

    // Verifies: DIARY-GUI-participant-task-list/I — a finalized task (with a
    //   local survey row) is REMOVED from the Task List entirely. It must not
    //   appear in "Needs your attention" AND must not appear as a "— submitted"
    //   completed row. The Task List section is absent (no tasks remain).
    //   Read-only access lives on the survey RECORD in "Your Records", not on
    //   the task list. This replaces the prior CUR-1523 test that asserted the
    //   finalized task stayed as a "completed" row — that behaviour violated
    //   assertion I.
    testWidgets(
      'a finalized task (with local survey row) is absent from the Task List '
      'entirely — not in attention, not as a completed row (assertion I)',
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

        // Finalized task MUST NOT appear in "Needs your attention".
        expect(find.text('Needs your attention'), findsNothing);
        // Finalized task MUST NOT appear as a "— submitted" completed row.
        expect(
          find.byKey(const Key('completed-task-q-finalized-1')),
          findsNothing,
        );
        // With no other tasks, the Task List section collapses entirely.
        expect(find.text('Task List'), findsNothing);
        // The survey RECORD is still visible in "Your Records" (today section).
        expect(find.byKey(const Key('survey-card')), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/H — a submitted questionnaire is
    //   accessible as a record; tapping it opens the flow.
    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/R — re-opening a
    //   SUBMITTED (not finalized) instance from its record opens the EDITABLE
    //   Review Screen seeded with prior answers — the open reflects the
    //   instance's state, not where it was opened from (same as the Task).
    testWidgets(
      'tapping a SUBMITTED (not finalized) survey record opens the EDITABLE '
      'Review prefilled (assertions H + R)',
      (tester) async {
        const instanceId = 'q-record-submitted-1';
        // A submitted survey row in "Your Records" — NOT portal-finalized.
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

        expect(find.byKey(const Key('survey-card')), findsOneWidget);

        await tester.tap(find.byKey(const Key('survey-card')));
        await _settle(tester);

        final flow = flowScreen(tester);
        // Not finalized → editable Review, seeded with the recorded answers.
        expect(flow.isReadOnly, isFalse);
        expect(flow.initialResponses, isNotNull);
        expect(flow.initialResponses, isNotEmpty);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S — opening a
    //   FINALIZED instance from its record presents the read-only state (no edit
    //   or submit), seeded with the recorded answers.
    // Verifies: DIARY-GUI-participant-task-list/H — finalized read-only access
    //   lives on the survey record (the task is removed per assertion I).
    testWidgets(
      'tapping a FINALIZED survey record opens the flow READ-ONLY prefilled '
      '(assertions H + S)',
      (tester) async {
        const instanceId = 'q-record-finalized-1';
        // Mint the finalize into questionnaire_status BEFORE the screen reads it,
        // so the instance is in the read-only set; the survey record remains.
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

        expect(find.byKey(const Key('survey-card')), findsOneWidget);

        await tester.tap(find.byKey(const Key('survey-card')));
        await _settle(tester);

        final flow = flowScreen(tester);
        expect(flow.isReadOnly, isTrue);
        expect(flow.initialResponses, isNotNull);
        expect(flow.initialResponses, isNotEmpty);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S — the read-only
    //   gate keys off a LIVE `questionnaire_status` subscription, so a finalize
    //   recorded AFTER the screen mounts takes effect with no re-read trigger.
    //   Regression: the post-sync reconcile mints questionnaire_finalized AFTER
    //   the sync that drove the (one-shot) read, so a one-shot read missed its
    //   own mint and left the record EDITABLE; the live subscription cannot lag.
    testWidgets(
      'a finalize recorded after mount makes the record read-only live '
      '(no re-read trigger)',
      (tester) async {
        const instanceId = 'q-record-live-finalize-1';
        final now = DateTime.now();
        // Mount with a SUBMITTED (not finalized) survey record → editable.
        await pumpScreen(
          tester,
          finalized: [
            surveyRow(
              DateTime(now.year, now.month, now.day, 9),
              aggregateId: instanceId,
            ),
          ],
        );

        // Mint the finalize into questionnaire_status AFTER mount — no task
        // change, no resume; only the live subscription can deliver it. The
        // append + the view emission run on the real clock (Sembast-memory), so
        // let them settle under runAsync, then pump the setState the live
        // listener schedules.
        await finalizeInstance(tester, instanceId);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester);

        await tester.tap(find.byKey(const Key('survey-card')));
        await _settle(tester);

        expect(flowScreen(tester).isReadOnly, isTrue);
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

    // Verifies: DIARY-PRD-questionnaire-portal-sent-rules/H — answering a
    //   question in an open questionnaire flow preserves the in-progress answers
    //   locally (a diary-local `checkpoint_questionnaire`) without committing a
    //   Submission, so leaving the flow no longer loses them (CUR-1522
    //   progress-loss bug). The per-answer onCheckpoint callback must be wired
    //   (it was null before).
    testWidgets(
      'answering a question dispatches checkpoint_questionnaire (progress saved)',
      (tester) async {
        const instanceId = 'q-checkpoint-1';
        addQuestionnaireTask(instanceId);
        await pumpScreen(tester);

        await tester.tap(find.text('NOSE HHT Survey'));
        await _settle(tester);
        final flow = flowScreen(tester);

        // The per-answer checkpoint callback must be wired (was null → drafts
        // were discarded the moment the flow was left).
        expect(flow.onCheckpoint, isNotNull);

        // Simulate the flow auto-saving a partial (1-of-N) submission after an
        // answer.
        flow.onCheckpoint!(
          tdt.QuestionnaireSubmission(
            instanceId: instanceId,
            questionnaireType: 'nose_hht',
            version: 'v1',
            responses: const [
              tdt.QuestionResponse(
                questionId: 'q1',
                value: 2,
                displayLabel: 'Moderate',
                normalizedLabel: '2',
              ),
            ],
            completedAt: DateTime.now(),
          ),
        );
        await _settle(tester);

        final s = submissionFor('checkpoint_questionnaire');
        expect(s.rawInput['instance_id'], instanceId);
        expect(s.rawInput['questionnaire_type'], 'nose_hht');
        final responses = s.rawInput['responses']! as Map<String, Object?>;
        expect(responses.keys, ['q1']);
        expect((responses['q1']! as Map)['value'], 2);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-session-expiry/G — returning to a
    //   questionnaire whose instance has only an in-progress `checkpoint` draft
    //   (no finalized submission) restores the participant with their saved
    //   partial answers intact, so they resume rather than starting over.
    // Verifies: DIARY-PRD-questionnaire-session-timeout/G+H
    testWidgets(
      'opening a task with a checkpoint draft seeds the flow with saved answers',
      (tester) async {
        const instanceId = 'q-resume-1';
        addQuestionnaireTask(instanceId);
        await pumpScreen(
          tester,
          // A checkpoint draft lives in the diary-LOCAL incomplete view, never
          // the finalized canonical view. CUR-1543: the draft must be RECENT
          // (within the 30-min NOSE HHT session timeout) or the expiry gate
          // discards it instead of seeding the flow.
          incomplete: [
            surveyRow(
              DateTime.now().subtract(const Duration(minutes: 1)),
              aggregateId: instanceId,
            ),
          ],
        );

        // The task is still actionable (no finalized submission yet).
        await tester.tap(find.text('NOSE HHT Survey'));
        await _settle(tester);

        // No Session Expiry Dialog, no discard — the draft is fresh.
        expect(find.text('Session expired'), findsNothing);
        expect(
          fake.submittedActions.where(
            (s) => s.actionName == 'discard_questionnaire_draft',
          ),
          isEmpty,
        );

        final flow = flowScreen(tester);
        expect(flow.isReadOnly, isFalse);
        expect(flow.initialResponses, isNotNull);
        expect(flow.initialResponses, isNotEmpty);
      },
    );

    // ---- CUR-1543: questionnaire session expiry ------------------------------

    // Verifies: DIARY-GUI-questionnaire-session-expiry/B+C+D — opening a
    //   questionnaire whose checkpoint draft has passed sessionTimeoutMinutes
    //   (30 for NOSE HHT) does NOT resume the draft: the draft is discarded in
    //   the event log (diary-local draft_discarded) and the Session Expiry
    //   Dialog is shown with Start Again / Not Now; Start Again dismisses the
    //   dialog and opens the flow FRESH from the Preamble (no seed).
    // Verifies: DIARY-PRD-questionnaire-session-timeout/C+D
    testWidgets(
      'an EXPIRED checkpoint draft is discarded and Start Again opens the '
      'flow fresh from the Preamble',
      (tester) async {
        const instanceId = 'q-expired-1';
        addQuestionnaireTask(instanceId);
        await pumpScreen(
          tester,
          // Draft last touched 31 minutes ago — past the 30-minute timeout.
          incomplete: [
            surveyRow(
              DateTime.now().subtract(const Duration(minutes: 31)),
              aggregateId: instanceId,
            ),
          ],
        );

        await tester.tap(find.text('NOSE HHT Survey'));
        // The dialog is gated behind an awaited discard dispatch whose fake
        // future resolves on the REAL event loop (queued in setUp, outside
        // the fake-async zone) — flush it via runAsync, as the recall tests do.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester);

        // The Session Expiry Dialog is up instead of the resumed flow.
        expect(find.text('Session expired'), findsOneWidget);
        expect(
          find.text(
            'Your session has expired and your previous answers were not '
            'saved.',
          ),
          findsOneWidget,
        );
        expect(find.text('Start Again'), findsOneWidget);
        expect(find.text('Not Now'), findsOneWidget);
        expect(find.byType(QuestionnaireFlowScreen), findsNothing);

        // The expired draft was discarded (diary-local, reason recorded).
        final discard = submissionFor('discard_questionnaire_draft');
        expect(discard.rawInput['instance_id'], instanceId);
        expect(discard.rawInput['questionnaire_type'], 'nose_hht');
        expect(discard.rawInput['reason'], 'session-expired');

        // Start Again → dialog dismissed, flow opens FRESH from the Preamble
        // (readiness gate) with no seeded answers.
        await tester.tap(find.text('Start Again'));
        await _settle(tester);

        final flow = flowScreen(tester);
        expect(flow.initialResponses, isNull);
        expect(flow.isReadOnly, isFalse);
        expect(find.text("I'm ready"), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-session-expiry/B+E — Not Now on the
    //   Session Expiry Dialog returns the participant to the home screen
    //   without opening the questionnaire flow. The expired draft is still
    //   discarded (the answers are gone regardless of the choice).
    testWidgets(
      'an EXPIRED checkpoint draft with Not Now returns to the home screen',
      (tester) async {
        const instanceId = 'q-expired-2';
        addQuestionnaireTask(instanceId);
        await pumpScreen(
          tester,
          incomplete: [
            surveyRow(
              DateTime.now().subtract(const Duration(minutes: 45)),
              aggregateId: instanceId,
            ),
          ],
        );

        await tester.tap(find.text('NOSE HHT Survey'));
        // Flush the awaited discard dispatch (real event loop; see above).
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester);

        expect(find.text('Session expired'), findsOneWidget);
        // The draft discard is unconditional on expiry.
        expect(
          submissionFor('discard_questionnaire_draft').rawInput['instance_id'],
          instanceId,
        );

        await tester.tap(find.text('Not Now'));
        await _settle(tester);

        // Back on the home screen — no flow was pushed.
        expect(find.byType(QuestionnaireFlowScreen), findsNothing);
        expect(find.text('Record Nosebleed'), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/I — a task whose portal status
    //   is 'finalized' (no local survey row) is ABSENT from the Task List
    //   entirely. Neither "Needs your attention" nor any "— submitted" completed
    //   row renders. The Task List section itself collapses (no items at all).
    //   This replaces the prior CUR-1523 test that asserted the finalized task
    //   showed as a completed row — that behaviour violated assertion I.
    testWidgets(
      'a finalized task with no local survey row is absent from the Task List '
      'entirely — Task List section collapses (assertion I)',
      (tester) async {
        const instanceId = 'q-fin-norow-1';
        addFinalizedStatusTask(instanceId);
        // No survey row driven into the diary view for this instance.
        await pumpScreen(tester);

        // The only questionnaire task is finalized → Task List is gone entirely.
        expect(find.text('Task List'), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
        // No "— submitted" completed row either.
        expect(
          find.byKey(const Key('completed-task-q-fin-norow-1')),
          findsNothing,
        );
      },
    );

    // Verifies: DIARY-GUI-participant-task-list/I — after a task is finalized
    //   (portal status='finalized') there is no task row to tap at all, so the
    //   questionnaire flow is unreachable via the task list. The task is fully
    //   removed; read-only access lives on the survey record.
    //   This replaces the prior CUR-1523 test that tapped a now-absent completed
    //   row — that scenario is invalid under assertion I.
    testWidgets(
      'a finalized task with no local survey row has no task row in the UI '
      '(cannot open the flow via the task list) (assertion I)',
      (tester) async {
        const instanceId = 'q-fin-norow-2';
        addFinalizedStatusTask(instanceId);
        await pumpScreen(tester);

        // No task row exists at all — the task has been removed from the list.
        expect(find.text('Task List'), findsNothing);
        expect(
          find.byKey(const Key('completed-task-q-fin-norow-2')),
          findsNothing,
        );
        // The QuestionnaireFlowScreen is NOT pushed.
        expect(find.byType(QuestionnaireFlowScreen), findsNothing);
      },
    );

    // ---- CUR-1522: questionnaire recall reactive notification ----------------

    /// Mints a `questionnaire_recalled` event into the native scope's
    /// questionnaire_recall view (via the `record_questionnaire_recalled` action),
    /// so the home screen's live subscription receives the row.
    ///
    /// The native scope is backed by a real (Sembast-memory) event store; must
    /// run inside [tester.runAsync].
    Future<void> seedRecall(
      WidgetTester tester, {
      required String instanceId,
      String? studyEvent,
    }) async {
      await tester.runAsync(() async {
        await runtime.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'record_questionnaire_recalled',
            rawInput: <String, Object?>{
              'instance_id': instanceId,
              'study_event': studyEvent,
            },
          ),
        );
      });
    }

    /// Writes a submitted `nose_hht_survey` entry for [instanceId] to the
    /// NATIVE event store (the Sembast-memory backend backing [runtime]).
    ///
    /// [_hasLocalSurveyRow] queries this store, so seeding here makes the
    /// home screen treat the instance as "participant had engaged" and show
    /// the recall dialog rather than silently acking.
    ///
    /// Must run inside [tester.runAsync] because the Sembast write is async.
    Future<void> seedNativeSurvey(
      WidgetTester tester, {
      required String instanceId,
    }) async {
      await tester.runAsync(() async {
        await runtime.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'submit_questionnaire',
            rawInput: <String, Object?>{
              'instance_id': instanceId,
              'questionnaire_type': 'nose_hht',
              'schema_version': '1.0.0',
              'content_version': '1.0.0',
              'gui_version': '1.0.0',
              'completed_at': '2026-06-20T08:30:00.000Z',
              'responses': <String, Object?>{
                'q1': <String, Object?>{
                  'value': 1,
                  'display_label': 'Yes',
                  'normalized_label': '1',
                },
              },
            },
          ),
        );
      });
    }

    // Verifies: DIARY-DEV-inbound-event-on-receipt/C — a recall row in the
    //   native questionnaire_recall view causes the home screen to show the
    //   "Questionnaire recalled" acknowledgement dialog with the expected
    //   message, when the participant had previously engaged with the
    //   questionnaire (a local survey row exists).
    testWidgets(
      'recall view row shows the "Questionnaire recalled" dialog on the home '
      'screen (participant had engaged)',
      (tester) async {
        const instanceId = 'QI-9';
        // Seed a native survey row so _hasLocalSurveyRow returns true and
        // the dialog is not suppressed. The FakeReaction survey row drives
        // the visual display.
        await seedNativeSurvey(tester, instanceId: instanceId);
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

        // Mint the recall into the native scope's questionnaire_recall view.
        // The subscription in home_screen fires a Delta; the dialog appears
        // because a local survey row exists for this instance.
        await seedRecall(
          tester,
          instanceId: instanceId,
          studyEvent: 'Cycle 4 Day 1',
        );
        // Allow the real Sembast timer + viewSource emission to propagate.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester);

        // The acknowledgement dialog message must be visible.
        expect(
          find.text('This questionnaire has been recalled by your study team'),
          findsOneWidget,
        );
        // Dismiss by tapping OK — this triggers acknowledgeRecall internally.
        await tester.tap(find.text('OK'));
        // Let acknowledgeRecall's real async writes (ack + clear) complete.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await _settle(tester);

        // The dialog must be gone after dismissal.
        expect(
          find.text('This questionnaire has been recalled by your study team'),
          findsNothing,
        );
      },
    );

    // Verifies: DIARY-DEV-inbound-event-on-receipt/C — a recall row that is
    //   ALREADY present in the questionnaire_recall view BEFORE the home screen
    //   mounts (so it arrives only as a replay-phase Snapshot, never a Delta)
    //   still results in the acknowledgement dialog being shown after the screen
    //   loads, provided the participant had previously engaged with the
    //   questionnaire (a local survey row exists). This is the FDA-critical
    //   re-prompt path: an unacknowledged recall must surface again on every
    //   relaunch until the participant dismisses it.
    testWidgets(
      'a recall row already in the view at mount (replay-phase Snapshot) '
      'shows the dialog after the screen loads (participant had engaged)',
      (tester) async {
        const instanceId = 'QI-replay-1';
        // Mint the recall BEFORE pumping the HomeScreen, so the row exists in
        // the native questionnaire_recall view during the subscription's replay
        // phase and arrives as a Snapshot (not a Delta).
        await seedRecall(
          tester,
          instanceId: instanceId,
          studyEvent: 'Baseline',
        );
        // Seed a native survey row BEFORE mount so _hasLocalSurveyRow returns
        // true when the replay drain calls _maybeShowRecall.
        await seedNativeSurvey(tester, instanceId: instanceId);
        // Allow the recall + survey to be committed to the store before the
        // screen subscribes.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );

        // Now mount the screen. The FakeReaction survey row drives the visual
        // display; the native survey row (seeded above) is what _hasLocalSurveyRow
        // queries to allow the dialog.
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
        // Give the replay drain (EndOfReplay -> Future<void>(() async { ... }))
        // enough time to surface the dialog.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await _settle(tester);

        // The acknowledgement dialog must appear despite arriving as a replay
        // Snapshot (not a live Delta).
        expect(
          find.text('This questionnaire has been recalled by your study team'),
          findsOneWidget,
        );
      },
    );

    // Verifies: DIARY-DEV-inbound-event-on-receipt/C — when a recall row
    //   arrives for an instance the participant NEVER received on this device
    //   (no local survey row exists), the home screen must NOT show the
    //   "Questionnaire recalled" dialog (the participant never saw it, so the
    //   message would be confusing). The recall must still be silently
    //   acknowledged so the portal recall row self-cleans.
    testWidgets('never-delivered recall (no local survey) is silently acked without '
        'showing the dialog', (tester) async {
      // No local survey row for the instance — never delivered to this device.
      await pumpScreen(tester);

      // Mint the recall for an instance with NO local survey.
      await seedRecall(
        tester,
        instanceId: 'QI-never-delivered',
        studyEvent: 'Cycle 1 Day 1',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _settle(tester);

      // Dialog MUST NOT appear — participant never saw this questionnaire.
      expect(
        find.text('This questionnaire has been recalled by your study team'),
        findsNothing,
        reason:
            'never-delivered recall must not surface a dialog '
            'that would confuse the participant',
      );

      // Assert the silent ack actually ran: a questionnaire_recall_acked
      // event must be in the native event store after the recall was processed.
      final ackEvent = await tester.runAsync(() async {
        final events = await runtime.bundle.eventStore.backend.findAllEvents();
        return events
            .where((e) => e.entryType == 'questionnaire_recall_acked')
            .firstOrNull;
      });
      expect(
        ackEvent,
        isNotNull,
        reason:
            'silent ack must emit a questionnaire_recall_acked event to the native store',
      );
    });

    // Verifies: DIARY-DEV-inbound-event-on-receipt/C — when a recall row
    //   arrives for an instance the participant DID engage with (a local
    //   `<id>_survey` row exists), the home screen MUST show the "Questionnaire
    //   recalled" dialog so the participant is informed and can acknowledge.
    //   This is the existing behavior; the test guards regression.
    testWidgets(
      'delivered-and-engaged recall (local survey present) shows the dialog',
      (tester) async {
        const instanceId = 'QI-engaged';
        // Seed a native survey row so _hasLocalSurveyRow returns true.
        // The FakeReaction survey row drives the visual display.
        await seedNativeSurvey(tester, instanceId: instanceId);
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

        // Mint the recall for an instance WITH a local survey (in native store).
        await seedRecall(
          tester,
          instanceId: instanceId,
          studyEvent: 'Cycle 2 Day 1',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await _settle(tester);

        // Dialog MUST appear — participant already engaged with this
        // questionnaire and needs to be informed.
        expect(
          find.text('This questionnaire has been recalled by your study team'),
          findsOneWidget,
          reason:
              'participant engaged with this questionnaire; '
              'the recall dialog must be shown',
        );
      },
    );
  });
}
