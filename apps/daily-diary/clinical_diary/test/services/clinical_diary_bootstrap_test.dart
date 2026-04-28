// Verifies: REQ-d00134-A.

import 'dart:async';

import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/triggers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Silent test-seam factories
//
// These produce factories that inject inert/empty behaviour so that
// installTriggers inside bootstrapClinicalDiary never touches Firebase,
// connectivity plugins, or a real periodic timer.
// ---------------------------------------------------------------------------

/// A no-op lifecycle observer that never fires the callbacks.
class _SilentLifecycleObserver extends WidgetsBindingObserver {}

LifecycleObserverFactory get _silentLifecycleFactory =>
    (onResumed, onForegroundChange) => _SilentLifecycleObserver();

/// A fake Timer that is immediately cancelled and never ticks.
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

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

/// Opens a fresh in-memory Sembast database with a unique name per call.
Future<Database> _openDb() => newDatabaseFactoryMemory().openDatabase(
  'bootstrap-test-${DateTime.now().microsecondsSinceEpoch}.db',
);

const _baseUrl = 'https://diary.example.com/';
const _deviceId = 'device-test-001';
const _softwareVersion = 'clinical_diary@0.0.0+test';
const _userId = 'user-test-001';

/// Bootstraps a [ClinicalDiaryRuntime] with:
/// - An in-memory Sembast database.
/// - A [MockClient] that returns 200 for all requests.
/// - Silent trigger factories (no Firebase / connectivity / timer activity).
///
/// Returns the runtime and the MockClient's captured request list so
/// tests can assert on outbound HTTP.
Future<({ClinicalDiaryRuntime runtime, List<http.Request> requests})>
_buildRuntime({
  http.Client? httpClient,
  Future<String?> Function()? authToken,
}) async {
  final db = await _openDb();
  final captured = <http.Request>[];

  final client =
      httpClient ??
      MockClient((req) async {
        captured.add(req);
        // 200 for both POST /events and GET /inbound (returns empty messages).
        if (req.url.path.endsWith('inbound')) {
          return http.Response('{"messages":[]}', 200);
        }
        return http.Response('', 200);
      });

  final runtime = await bootstrapClinicalDiary(
    sembastDatabase: db,
    authToken: authToken ?? () async => 'test-token',
    deviceId: _deviceId,
    softwareVersion: _softwareVersion,
    userId: _userId,
    primaryDiaryServerBaseUrl: Uri.parse(_baseUrl),
    httpClient: client,
    // Inject silent factories so installTriggers never touches the
    // production Firebase and connectivity stacks.
    lifecycleObserverFactory: _silentLifecycleFactory,
    periodicTimerFactory: _silentTimerFactory,
    connectivityStreamFactory: _silentConnectivityFactory,
    fcmOnMessageStreamFactory: _silentFcmMessageFactory,
    fcmOnOpenedStreamFactory: _silentFcmOpenedFactory,
  );

  return (runtime: runtime, requests: captured);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Flutter binding is required because installTriggers calls
  // WidgetsBinding.instance.addObserver (even with a silent lifecycle factory,
  // the factory result is still passed to WidgetsBinding).
  setUpAll(WidgetsFlutterBinding.ensureInitialized);

  // -----------------------------------------------------------------------
  // Test 1: composition smoke test
  // Verifies: REQ-d00134-A — bootstrap returns a ClinicalDiaryRuntime with
  // non-null entryService, reader, syncCycle, and triggerHandles.
  // -----------------------------------------------------------------------
  test('bootstrapClinicalDiary returns a ClinicalDiaryRuntime with all '
      'collaborators non-null', () async {
    final (:runtime, :requests) = await _buildRuntime();

    expect(runtime.entryService, isNotNull);
    expect(runtime.reader, isNotNull);
    expect(runtime.syncCycle, isNotNull);
    expect(runtime.triggerHandles, isNotNull);
    expect(runtime.destinations, isNotNull);

    await runtime.dispose();
  });

  // -----------------------------------------------------------------------
  // Test 2: end-to-end record + read
  // Verifies: REQ-d00134-A — EntryService.record writes an event that
  // DiaryEntryReader.entriesForDate can subsequently read back.
  // -----------------------------------------------------------------------
  test(
    'record via entryService is readable via reader.entriesForDate',
    () async {
      final (:runtime, :requests) = await _buildRuntime();

      // Record a finalized epistaxis_event with a known startTime so the
      // effective date resolves to today.
      final now = DateTime.now().toUtc();
      await runtime.entryService.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-bootstrap-e2e-1',
        eventType: 'finalized',
        answers: {'startTime': now.toIso8601String()},
      );

      // The effectiveDatePath for epistaxis_event is 'startTime', so
      // effectiveDate == now (UTC). Query using local date — today.
      final entries = await runtime.reader.entriesForDate(DateTime.now());

      expect(entries, hasLength(1));
      expect(entries.single.entryId, 'agg-bootstrap-e2e-1');
      expect(entries.single.entryType, 'epistaxis_event');

      await runtime.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // Test 3: syncCycle drains the FIFO to the HTTP destination
  // Verifies: REQ-d00134-A — syncCycle() sends a POST to {baseUrl}/events
  // after an event has been recorded and the destination is active.
  //
  // Architecture note: destinations start dormant (no startDate). Events
  // recorded via EntryService flow into the event log; `fillBatch` promotes
  // them to the destination's FIFO only once a startDate is set. Calling
  // `setStartDate` with a past timestamp triggers historical replay (which
  // acts as fillBatch for events already in the log), populating the FIFO
  // so the subsequent `syncCycle` drain can send them.
  // -----------------------------------------------------------------------
  test(
    'runtime.syncCycle() drains the FIFO and POSTs to {baseUrl}/events',
    () async {
      final db = await _openDb();
      final captured = <http.Request>[];

      final client = MockClient((req) async {
        captured.add(req);
        if (req.url.path.endsWith('inbound')) {
          return http.Response('{"messages":[]}', 200);
        }
        return http.Response('', 200);
      });

      final runtime = await bootstrapClinicalDiary(
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

      // Record one event BEFORE activating the destination. The event lands
      // in the event log; at this point the destination is dormant so
      // nothing is enqueued to its FIFO yet.
      final now = DateTime.now().toUtc();
      await runtime.entryService.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-drain-2',
        eventType: 'finalized',
        answers: {'startTime': now.toIso8601String()},
      );

      // Activate the destination with a past startDate. This triggers
      // historical replay synchronously, which walks the event log and
      // enqueues any matching events (including the one above) into the
      // destination's FIFO, exactly as fillBatch would during live operation.
      await runtime.destinations.setStartDate(
        'primary_diary_server',
        DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        initiator: const AutomationInitiator(service: 'test'),
      );

      // Drain the FIFO: syncCycle runs drain() for each registered
      // destination. The historical-replay-populated FIFO entry is sent,
      // producing a POST to {baseUrl}/events.
      await runtime.syncCycle();

      final postRequests = captured.where((r) => r.method == 'POST').toList();
      expect(postRequests, isNotEmpty);
      expect(
        postRequests.any((r) => r.url.toString().contains('events')),
        isTrue,
      );

      await runtime.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // Test 4: dispose() completes without error
  // Verifies: REQ-d00134-A — dispose() cancels triggers cleanly.
  // -----------------------------------------------------------------------
  test('runtime.dispose() completes without error', () async {
    final (:runtime, :requests) = await _buildRuntime();

    // dispose() should complete without throwing.
    await expectLater(runtime.dispose(), completes);
  });
}
