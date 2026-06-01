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
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      fake = FakeReaction();
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
    const wedgeText = 'Some data is not syncing — please update the app.';

    testWidgets(
      'native-store FIFO wedge surfaces the sync-wedged banner (legacy clean)',
      (tester) async {
        // Legacy runtime.backend is a fresh in-memory store with no wedged FIFO;
        // only the native store is wedged. The banner must still surface.
        await pumpScreen(tester, nativeFifoWedged: () async => true);
        expect(find.text(wedgeText), findsOneWidget);
      },
    );

    testWidgets(
      'no wedge banner when neither legacy nor native store is wedged',
      (tester) async {
        await pumpScreen(tester, nativeFifoWedged: () async => false);
        expect(find.text(wedgeText), findsNothing);
      },
    );

    testWidgets(
      'renders empty state with the record button and yesterday banner',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Record Nosebleed'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
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

    testWidgets(
      'shows the incomplete-entry reminder for a driven incomplete row',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10);
        await pumpScreen(
          tester,
          incomplete: [epistaxisRow(today, aggregateId: 'agg-incomplete-1')],
        );

        // The orange incomplete-records reminder copy ("Tap to complete") shows.
        expect(find.text('Tap to complete'), findsOneWidget);
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
  });
}
