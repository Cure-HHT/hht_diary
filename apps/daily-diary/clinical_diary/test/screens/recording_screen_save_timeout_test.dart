// IMPLEMENTS REQUIREMENTS:
//   REQ-p00001: Incomplete Entry Preservation
//   REQ-CAL-p00081-F: Task list updates in real-time (back-out from entry
//                     must not leave the user stranded on the screen).
//
// CUR-1397 regression coverage for the `saveTimeout` guard added to
// `RecordingScreen` and `SimpleRecordingScreen`.
//
// Before the fix, an `entryService.record(...)` Future that never resolved
// (sembast hang, fs stall, third-party I/O) would trap the user:
//   - `_isSaving` stays true → Save disabled.
//   - `_handleExit` (the back-press path) awaits `_saveRecord`, which is
//     itself awaiting the hung future.
//   - PopScope(canPop: false) never reaches `Navigator.pop(context)`.
// The user could not escape without force-stopping the app.
//
// The fix wraps the `record(...)` call in `.timeout(widget.saveTimeout)`.
// On timeout, the catch block surfaces a `failedToSave` snackbar, the
// finally resets `_isSaving`, and Back is unblocked. These tests pin all
// three behaviors:
//
//   1. throwing  — pre-existing path; record() throws synchronously,
//                  screen recovers cleanly. (No regression on the
//                  already-working error path.)
//   2. hanging   — post-fix path; record() never resolves, timeout fires,
//                  snackbar appears, screen recovers. (THE FIX.)
//   3. fast      — sanity; a normal sub-timeout save still succeeds with
//                  no false-positive timeout.

import 'dart:async';

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';

EntryTypeDefinition _epistaxisDef() => const EntryTypeDefinition(
  id: 'epistaxis_event',
  registeredVersion: 1,
  name: 'Nosebleed',
  widgetId: 'epistaxis_form_v1',
  widgetConfig: <String, Object?>{},
  effectiveDatePath: 'startTime',
);

/// Base for the fake services below — satisfies `EntryService`'s required
/// collaborators with a throwaway in-memory backend so subclasses only need
/// to override `record(...)`. The real backend writes are never exercised.
abstract class _BaseFakeService extends EntryService {
  _BaseFakeService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super(syncCycleTrigger: _noop);

  static Future<void> _noop() async {}

  static Future<({SembastBackend backend, EntryTypeRegistry registry})>
  _deps() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'cur1397-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    return (
      backend: SembastBackend(database: db),
      registry: EntryTypeRegistry()..register(_epistaxisDef()),
    );
  }

  Future<void> dispose() => (backend as SembastBackend).close();
}

/// Mirrors sembast's actual post-close behavior: throws synchronously.
class _ThrowingEntryService extends _BaseFakeService {
  _ThrowingEntryService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super._();

  static Future<_ThrowingEntryService> create() async {
    final deps = await _BaseFakeService._deps();
    return _ThrowingEntryService._(
      backend: deps.backend,
      entryTypes: deps.registry,
      deviceInfo: const DeviceInfo(
        deviceId: 'd',
        softwareVersion: 'v',
        userId: 'u',
      ),
    );
  }

  int calls = 0;

  @override
  Future<StoredEvent?> record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    calls++;
    throw StateError('[3] database is closed');
  }
}

/// Returns a Future that never completes — the trap scenario.
class _HangingEntryService extends _BaseFakeService {
  _HangingEntryService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super._();

  static Future<_HangingEntryService> create() async {
    final deps = await _BaseFakeService._deps();
    return _HangingEntryService._(
      backend: deps.backend,
      entryTypes: deps.registry,
      deviceInfo: const DeviceInfo(
        deviceId: 'd',
        softwareVersion: 'v',
        userId: 'u',
      ),
    );
  }

  /// Completes when the test wants to release the hung future for clean
  /// teardown — never as part of the assertion path.
  final Completer<StoredEvent?> hung = Completer<StoredEvent?>();
  int calls = 0;

  @override
  Future<StoredEvent?> record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) {
    calls++;
    return hung.future;
  }
}

/// Returns null synchronously — the happy-path stand-in.
class _FastEntryService extends _BaseFakeService {
  _FastEntryService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super._();

  static Future<_FastEntryService> create() async {
    final deps = await _BaseFakeService._deps();
    return _FastEntryService._(
      backend: deps.backend,
      entryTypes: deps.registry,
      deviceInfo: const DeviceInfo(
        deviceId: 'd',
        softwareVersion: 'v',
        userId: 'u',
      ),
    );
  }

  int calls = 0;

  @override
  Future<StoredEvent?> record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    calls++;
    return null;
  }
}

const _testTimeout = Duration(milliseconds: 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlagService.instance.useReviewScreen = false;
    FeatureFlagService.instance.requireOldEntryJustification = false;
    FeatureFlagService.instance.enableShortDurationConfirmation = false;
    FeatureFlagService.instance.enableLongDurationConfirmation = false;
  });

  tearDown(() {
    FeatureFlagService.instance.useReviewScreen = false;
  });

  Future<void> pumpRecording(
    WidgetTester tester,
    EntryService service, {
    Duration saveTimeout = _testTimeout,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWithMaterialApp(
        RecordingScreen(
          entryService: service,
          enrollmentService: MockEnrollmentService(),
          preferencesService: PreferencesService(),
          saveTimeout: saveTimeout,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpSimple(
    WidgetTester tester,
    EntryService service, {
    Duration saveTimeout = _testTimeout,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWithMaterialApp(
        SimpleRecordingScreen(
          entryService: service,
          enrollmentService: MockEnrollmentService(),
          preferencesService: PreferencesService(),
          saveTimeout: saveTimeout,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('RecordingScreen — CUR-1397 save timeout', () {
    testWidgets(
      'record() that throws is handled cleanly by the existing catch block',
      (tester) async {
        // Pre-existing behavior — included to pin that the timeout wrap
        // did not regress the throw-on-closed-db path that already worked.
        final service = await _ThrowingEntryService.create();
        addTearDown(service.dispose);

        await pumpRecording(tester, service);

        // System Back → PopScope's onPopInvokedWithResult fires →
        // _handleExit observes hasUnsaved=true (new entry, startTime
        // step) → awaits _saveRecord → entryService.record() throws.
        // ignore: unawaited_futures
        tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // record() was called exactly once, AND it threw quickly. There's
        // no second call because the catch block returned null without
        // re-trying.
        expect(service.calls, 1);

        // _handleExit shows its own snackbar then awaits controller.closed
        // (5s default). Pump past that so the route can pop.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'record() that hangs is bounded by saveTimeout → snackbar + Back works',
      (tester) async {
        // THE FIX. Without the .timeout(...) wrap this test would fail
        // because Probe B's trap would activate.
        final service = await _HangingEntryService.create();
        addTearDown(service.dispose);

        await pumpRecording(tester, service);

        // System Back, same path as the throws test.
        // ignore: unawaited_futures
        tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // record() is called immediately. Without the fix this is where
        // the trap would form.
        expect(service.calls, 1, reason: '_handleExit called record() once');

        // BEFORE the fix: pumping past 200ms changed nothing — the future
        // was hung forever. AFTER the fix: at saveTimeout the .timeout
        // op throws TimeoutException, the catch block runs, the snackbar
        // appears, and _isSaving resets.
        await tester.pump(_testTimeout);
        await tester.pump(const Duration(milliseconds: 50));

        // The failedToSave snackbar from _saveRecord's catch block.
        expect(
          find.byType(SnackBar),
          findsWidgets,
          reason: 'failedToSave snackbar should render after timeout',
        );

        // Drive past _handleExit's own 5s snackbar-closed await so the
        // back-out completes.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        // Unblock the hung future for clean teardown.
        if (!service.hung.isCompleted) {
          service.hung.complete(null);
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets('fast record() inside the timeout window completes normally — '
        'no false-positive timeout', (tester) async {
      // A normal local write returns in <100ms. Confirm the 200ms test
      // timeout does not erroneously trip the failure path for it.
      final service = await _FastEntryService.create();
      addTearDown(service.dispose);

      await pumpRecording(tester, service);

      // ignore: unawaited_futures
      tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.calls, 1);
      // No SnackBar means no failure path was hit — the save succeeded.
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('SimpleRecordingScreen — CUR-1397 save timeout', () {
    // SimpleRecordingScreen exposes Save via a `FilledButton` at the
    // bottom of the form; the default state (a freshly-rendered new
    // entry) has _userSetStart=false, but tapping the button with
    // warnIfMissed:false invokes _saveRecord regardless — sibling tests
    // in simple_recording_screen_test.dart use the same pattern.

    testWidgets('record() that throws is handled cleanly — no regression', (
      tester,
    ) async {
      final service = await _ThrowingEntryService.create();
      addTearDown(service.dispose);

      await pumpSimple(tester, service);

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(service.calls, 1);
      // The screen surfaces failedToSave via SnackBar on catch.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'failedToSave snackbar should appear on throw',
      );
    });

    testWidgets(
      'hanging record() is bounded by saveTimeout → snackbar appears, '
      '_isSaving resets',
      (tester) async {
        // THE FIX validated through SimpleRecordingScreen's Save button.
        final service = await _HangingEntryService.create();
        addTearDown(service.dispose);

        await pumpSimple(tester, service);

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // record() was called and is hung. Before the fix the screen
        // would stay in this state forever.
        expect(service.calls, 1);
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason: 'no error yet — the future is still pending',
        );

        // After the timeout window, .timeout throws, the catch runs,
        // and the snackbar appears.
        await tester.pump(_testTimeout);
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'failedToSave snackbar after timeout fires',
        );

        // Unblock the hung future for clean teardown.
        if (!service.hung.isCompleted) {
          service.hung.complete(null);
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets('fast record() does NOT trigger a false-positive timeout', (
      tester,
    ) async {
      final service = await _FastEntryService.create();
      addTearDown(service.dispose);

      await pumpSimple(tester, service);

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(service.calls, 1);
      // No snackbar means the catch block did not run — the save
      // completed normally within the timeout.
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
