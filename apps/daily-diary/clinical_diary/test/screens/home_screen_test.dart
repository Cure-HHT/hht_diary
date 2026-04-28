// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00081: Patient Task System
//
// Phase 12.5 (CUR-1169): Screen-level coverage for HomeScreen against the
// new event_sourcing_datastore-backed runtime. Drives the screen with a
// real bootstrapped ClinicalDiaryRuntime against an in-memory Sembast
// backend and asserts on event side effects.

import 'dart:async';

import 'package:clinical_diary/screens/home_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
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
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    userId: _userId,
    primaryDiaryServerBaseUrl: Uri.parse(_baseUrl),
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

    Future<void> pumpScreen(WidgetTester tester) async {
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

    /// Records an event via the real EntryService inside `runAsync` so
    /// Sembast's internal async (which can use real timers) actually
    /// fires under TestWidgetsFlutterBinding's fake clock.
    Future<void> recordEvent(
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

    /// Wraps a backend query in `runAsync` for the same reason as
    /// [recordEvent].
    Future<List<StoredEvent>> findEventsByType(
      WidgetTester tester, {
      required String entryType,
    }) async {
      List<StoredEvent>? all;
      await tester.runAsync(() async {
        all = await runtime.backend.findAllEvents();
      });
      return all!.where((e) => e.entryType == entryType).toList();
    }

    testWidgets(
      'renders empty state with the record button and yesterday banner',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Record Nosebleed'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
        // No-yesterday banner is present (no entries → hasYesterdayRecords=false).
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      },
    );

    testWidgets(
      'with a finalized epistaxis_event today, the reader returns it',
      (tester) async {
        await recordEvent(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-home-1',
          eventType: 'finalized',
          answers: <String, Object?>{
            'startTime': DateTime.now().toUtc().toIso8601String(),
            'endTime': DateTime.now().toUtc().toIso8601String(),
            'intensity': 'dripping',
          },
        );

        await pumpScreen(tester);

        // Verify the seeded entry is queryable via the reader (the home
        // screen pipes this same path into its grouped record view).
        List<DiaryEntry>? entries;
        await tester.runAsync(() async {
          entries = await runtime.reader.entriesForDate(DateTime.now());
        });
        expect(
          entries!.where((e) => e.entryType == 'epistaxis_event'),
          hasLength(1),
        );
      },
    );

    testWidgets('tap "No" on yesterday banner records a no_epistaxis_event', (
      tester,
    ) async {
      await pumpScreen(tester);

      final noButton = find.text('No');
      expect(noButton, findsOneWidget);
      await tester.tap(noButton, warnIfMissed: false);
      await _settle(tester);

      final events = await findEventsByType(
        tester,
        entryType: 'no_epistaxis_event',
      );
      final finalized = events
          .where((e) => e.eventType == 'finalized')
          .toList();
      expect(finalized, hasLength(1));
    });

    testWidgets(
      'tap "Don\'t remember" on yesterday banner records an unknown_day_event',
      (tester) async {
        await pumpScreen(tester);

        final dontRememberButton = find.text("Don't remember");
        expect(dontRememberButton, findsOneWidget);
        await tester.tap(dontRememberButton, warnIfMissed: false);
        await _settle(tester);

        final events = await findEventsByType(
          tester,
          entryType: 'unknown_day_event',
        );
        final finalized = events
            .where((e) => e.eventType == 'finalized')
            .toList();
        expect(finalized, hasLength(1));
      },
    );

    testWidgets(
      'tap "Record Nosebleed" pushes the appropriate recording screen',
      (tester) async {
        await pumpScreen(tester);

        final recordButton = find.widgetWithText(
          FilledButton,
          'Record Nosebleed',
        );
        expect(recordButton, findsOneWidget);
        await tester.tap(recordButton, warnIfMissed: false);
        await _settle(tester);

        // Default feature flag uses the multi-page RecordingScreen, but
        // the simple-page variant is also acceptable under different
        // sponsor configurations.
        final found =
            find.byType(RecordingScreen).evaluate().isNotEmpty ||
            find.byType(SimpleRecordingScreen).evaluate().isNotEmpty;
        expect(
          found,
          isTrue,
          reason: 'Tapping the record button should push a recording screen',
        );
      },
    );
  });
}
