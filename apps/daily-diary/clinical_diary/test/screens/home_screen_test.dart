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
// bootstrapped ClinicalDiaryRuntime supplying the still-required constructor
// params (wedge check, survey/export paths).

import 'dart:async';

import 'package:clinical_diary/read/diary_incomplete_projection.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/incomplete_records_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:diary_design_system/diary_design_system.dart' show AppCard;
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reaction/reaction.dart' show Authenticated;
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

// Silent test seams (mirrors clinical_diary_bootstrap_test.dart).
class _SilentLifecycleObserver extends WidgetsBindingObserver {}

LifecycleObserverFactory get _silentLifecycleFactory =>
    (onResumed, onForegroundChange) => _SilentLifecycleObserver();

class _CancelledTimer implements Timer {
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
  @override
  void cancel() {}
}

PeriodicTimerFactory get _silentTimerFactory =>
    (duration, onTick) => _CancelledTimer();

ConnectivityStreamFactory get _silentConnectivityFactory =>
    () => const Stream<List<ConnectivityResult>>.empty();

FcmOnMessageStreamFactory get _silentFcmMessageFactory =>
    () => const Stream<RemoteMessage>.empty();

FcmOnOpenedStreamFactory get _silentFcmOpenedFactory =>
    () => const Stream<RemoteMessage>.empty();

const _baseUrl = 'https://diary.example.com/';
const _deviceId = 'device-test-001';
const _softwareVersion = 'clinical_diary@0.0.0+test';
const _userId = 'user-test-001';

Future<ClinicalDiaryRuntime> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'home-screen-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final client = MockClient((req) async {
    if (req.url.path.endsWith('inbound')) {
      return http.Response('{"messages":[]}', 200);
    }
    return http.Response('', 200);
  });
  return bootstrapClinicalDiary(
    sembastDatabase: db,
    authToken: () async => 'test-token',
    resolveBaseUrl: () async => Uri.parse(_baseUrl),
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    userId: _userId,
    httpClient: client,
    lifecycleObserverFactory: _silentLifecycleFactory,
    periodicTimerFactory: _silentTimerFactory,
    connectivityStreamFactory: _silentConnectivityFactory,
    fcmOnMessageStreamFactory: _silentFcmMessageFactory,
    fcmOnOpenedStreamFactory: _silentFcmOpenedFactory,
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
    late ClinicalDiaryRuntime runtime;
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
              runtime: runtime,
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
  });
}
