// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry
//
// Phase 12.9 (CUR-1169): Restored from the legacy integration_test/ tree
// against the new event_sourcing_datastore-backed runtime.
//
// The original 2729-line integration test bundled a long catalogue of
// scenarios — most of which now live in narrower, faster suites:
//
//  - Record CRUD over the runtime (add/edit/delete + drain): covered by
//    test/integration/cutover_flow_test.dart scenarios 1-3.
//  - 5-state dayStatus + reader queries: covered by cutover_flow_test.dart
//    scenario 11, plus test/services/diary_entry_reader_test.dart.
//  - HomeScreen empty state, yesterday banner Yes/No/Don't-remember,
//    Record Nosebleed navigation: covered by
//    test/screens/home_screen_test.dart.
//  - Calendar refresh after delete (CUR-586) and past-date creation
//    (CUR-543): covered by test/screens/calendar_screen_test.dart with
//    pre-seeded entries.
//  - Recording-screen save flow / partial-save / overlap detection:
//    covered by test/screens/recording_screen_test.dart and
//    test/screens/simple_recording_screen_test.dart.
//  - Enrollment flow / Active-status banner (CUR-1063): covered by
//    test/screens/clinical_trial_enrollment_screen_test.dart.
//
// What stays here is the truly cross-cutting end-to-end behaviour:
//
//  1. A pre-recorded epistaxis_event flows through bootstrap -> reader ->
//     HomeScreen -> EventListItem and surfaces in the rendered list with the
//     FlashHighlight wrapper applied.
//  2. A pre-recorded incomplete event surfaces both as an EventListItem AND
//     as the orange "Tap to complete" banner.
//  3. The yesterday banner hides once a yesterday-dated entry exists.
//  4. The LogoMenu opens, navigates to the Licenses page, and the legacy
//     "Check for updates" affordance is gone (CUR-990).
//
// All scenarios drive a real ClinicalDiaryRuntime against an in-memory
// Sembast backend (no MockClient HTTP path is exercised — the home screen
// itself doesn't issue HTTP, the destinations layer does, and that's
// covered by cutover_flow_test.dart).

import 'dart:async';

import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';
import '../test_helpers/flavor_setup.dart';

// ---------------------------------------------------------------------------
// Silent test seams (mirrors clinical_diary_bootstrap_test.dart and
// home_screen_test.dart).
// ---------------------------------------------------------------------------

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
const _deviceId = 'home-int-device-001';
const _softwareVersion = 'clinical_diary@0.0.0+integration';
const _userId = 'home-int-user-001';

Future<ClinicalDiaryRuntime> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'home-screen-int-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final client = MockClient((req) async {
    if (req.url.path.endsWith('inbound')) {
      return http.Response('{"messages":[]}', 200);
    }
    return http.Response('', 200);
  });
  return bootstrapClinicalDiary(
    sembastDatabase: db,
    authToken: () async => 'integration-token',
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
/// indefinite animators (Scrollbar, FlashHighlight) while still letting
/// async post-frame work complete via Dart microtasks. Mirrors the
/// `_settle` helper in test/screens/home_screen_test.dart.
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

  group('HomeScreen Integration', () {
    late ClinicalDiaryRuntime runtime;
    late MockEnrollmentService enrollment;
    late PreferencesService preferences;
    late TaskService tasks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = PreferencesService();
      enrollment = MockEnrollmentService();
      tasks = TaskService();
      runtime = await _bootstrap();
    });

    tearDown(() async {
      await runtime.dispose();
      tasks.dispose();
    });

    Future<void> pumpHomeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialApp(
          HomeScreen(
            runtime: runtime,
            deviceId: _deviceId,
            enrollmentService: enrollment,
            taskService: tasks,
            preferencesService: preferences,
            onLocaleChanged: (_) {},
            onThemeModeChanged: (_) {},
            onLargerTextChanged: (_) {},
          ),
        ),
      );
      await _settle(tester);
    }

    /// Seed an event via the real EntryService inside `runAsync` so
    /// Sembast's internal real-timer async actually fires under
    /// TestWidgetsFlutterBinding's fake clock. Mirrors the pattern from
    /// home_screen_test.dart (Task 12.5).
    Future<void> seedEvent(
      WidgetTester tester, {
      required String entryType,
      required String aggregateId,
      required String eventType,
      required Map<String, Object?> answers,
    }) async {
      await tester.runAsync(() async {
        await runtime.entryService.record(
          entryType: entryType,
          aggregateId: aggregateId,
          eventType: eventType,
          answers: answers,
        );
      });
    }

    // -----------------------------------------------------------------------
    // 1. End-to-end: a finalized epistaxis_event recorded via the real
    //    EntryService surfaces on the HomeScreen as an EventListItem,
    //    wrapped in a FlashHighlight (CUR-464).
    // -----------------------------------------------------------------------
    testWidgets(
      'seeded finalized event renders as an EventListItem inside FlashHighlight',
      (tester) async {
        final now = DateTime.now();
        await seedEvent(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-home-int-1',
          eventType: 'finalized',
          answers: <String, Object?>{
            'startTime': DateTime(
              now.year,
              now.month,
              now.day,
              10,
              0,
            ).toIso8601String(),
            'endTime': DateTime(
              now.year,
              now.month,
              now.day,
              10,
              30,
            ).toIso8601String(),
            'intensity': 'dripping',
          },
        );

        await pumpHomeScreen(tester);

        // The event surfaces as exactly one list item.
        expect(find.byType(EventListItem), findsOneWidget);
        // CUR-464: the list item is wrapped in FlashHighlight so newly
        // created entries can flash on the home page.
        expect(find.byType(FlashHighlight), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 2. End-to-end: a checkpointed (incomplete) event renders both as a
    //    list item AND as the orange "Tap to complete" banner above the list.
    // -----------------------------------------------------------------------
    testWidgets(
      'incomplete (checkpoint) event surfaces in list and incomplete banner',
      (tester) async {
        final now = DateTime.now();
        await seedEvent(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-home-int-incomplete',
          eventType: 'checkpoint',
          answers: <String, Object?>{
            'startTime': DateTime(
              now.year,
              now.month,
              now.day,
              9,
              0,
            ).toIso8601String(),
            // No endTime / no intensity — checkpoint is incomplete.
          },
        );

        await pumpHomeScreen(tester);

        // Surfaces as one list item.
        expect(find.byType(EventListItem), findsOneWidget);
        // The "Tap to complete" affordance on the orange incomplete banner.
        expect(find.text('Tap to complete'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Yesterday banner hides when yesterday has at least one entry.
    //    The empty-state path (banner visible, Yes/No/Don't remember
    //    buttons reachable) is asserted in home_screen_test.dart; this is
    //    the inverse claim.
    // -----------------------------------------------------------------------
    testWidgets(
      'yesterday banner is hidden when a yesterday-dated entry exists',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await seedEvent(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-home-int-yesterday',
          eventType: 'finalized',
          answers: <String, Object?>{
            'startTime': DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              10,
              0,
            ).toIso8601String(),
            'endTime': DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              10,
              30,
            ).toIso8601String(),
            'intensity': 'dripping',
          },
        );

        await pumpHomeScreen(tester);

        // YesterdayBanner widget is gone — hasYesterdayRecords=true short-
        // circuits the conditional in HomeScreen.build.
        expect(find.byType(YesterdayBanner), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 4. Logo menu navigation: tap the logo, choose Licenses, see the
    //    LicensesPage. The legacy "Check for updates" affordance is gone
    //    (CUR-990).
    // -----------------------------------------------------------------------
    testWidgets(
      'logo menu navigates to LicensesPage and omits "Check for updates"',
      (tester) async {
        await pumpHomeScreen(tester);

        // Open the LogoMenu (PopupMenuButton).
        await tester.tap(find.byType(LogoMenu));
        await _settle(tester);

        // CUR-990: the legacy "Check for updates" option is gone.
        expect(find.text('Check for updates'), findsNothing);

        // Tap the Licenses menu item.
        final licensesEntry = find.text('Licenses');
        expect(licensesEntry, findsWidgets);
        await tester.tap(licensesEntry.first);
        await _settle(tester);

        // The LicensesPage (Flutter's built-in license screen) is now on top.
        expect(find.byType(LicensesPage), findsOneWidget);
      },
    );
  });
}
