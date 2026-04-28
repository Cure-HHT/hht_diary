// Verifies: REQ-d00155 (destination contract); REQ-d00156 (inbound poll);
//   REQ-d00157 (sync triggers); REQ-d00113-C (questionnaire 409 translation);
//   REQ-d00113-D (tombstone inbound).

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/destinations/portal_inbound_poll.dart';
import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/diary_entry_reader.dart';
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
// Silent test-seam factories (matches clinical_diary_bootstrap_test.dart)
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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _baseUrl = 'https://diary.example.com/';
const _deviceId = 'integration-device-001';
const _softwareVersion = 'clinical_diary@0.0.0+integration';
const _userId = 'integration-user-001';

// ---------------------------------------------------------------------------
// Mutable HTTP handler so individual tests can flip behaviour mid-run
// (e.g. offline -> online in scenario 8).
// ---------------------------------------------------------------------------

class _Handler {
  /// Default: 200 for POST /events, empty `messages` for GET /inbound.
  Future<http.Response> Function(http.Request) impl = (req) async {
    if (req.url.path.endsWith('inbound')) {
      return http.Response('{"messages":[]}', 200);
    }
    return http.Response('', 200);
  };
}

// ---------------------------------------------------------------------------
// Per-test fixture
// ---------------------------------------------------------------------------

class _Fixture {
  _Fixture({
    required this.runtime,
    required this.db,
    required this.handler,
    required this.requests,
  });

  final ClinicalDiaryRuntime runtime;
  final Database db;
  final _Handler handler;
  final List<http.Request> requests;

  Future<void> tearDown() async {
    await runtime.dispose();
    await db.close();
  }
}

Future<_Fixture> _build() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'cutover-flow-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final handler = _Handler();
  final captured = <http.Request>[];

  final client = MockClient((req) async {
    captured.add(req);
    return handler.impl(req);
  });

  final runtime = await bootstrapClinicalDiary(
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

  // The destination starts dormant (no startDate). Tests that need to
  // drain MUST call [_activateAndFill] (or [_fillBatch] for repeat fills)
  // after recording events: setStartDate triggers historical replay, and
  // subsequent calls to [_fillBatch] promote any events recorded since.
  return _Fixture(
    runtime: runtime,
    db: db,
    handler: handler,
    requests: captured,
  );
}

/// One-shot: activate the destination. setStartDate's historical replay
/// promotes every event already in the log into the FIFO, exactly as
/// fillBatch would during live operation. (Tests record events FIRST,
/// then activate, then drain — matching the bootstrap test pattern.)
Future<void> _activate(_Fixture fx) async {
  await fx.runtime.destinations.setStartDate(
    'primary_diary_server',
    DateTime.utc(2020, 1, 1),
    initiator: const AutomationInitiator(service: 'integration-test'),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Required because installTriggers calls
  // WidgetsBinding.instance.addObserver, even with a silent lifecycle factory.
  setUpAll(WidgetsFlutterBinding.ensureInitialized);

  // -------------------------------------------------------------------------
  // Scenario 1: Nosebleed add -> record + drain
  // -------------------------------------------------------------------------
  test('scenario 1: record one nosebleed -> 1 event in log, view row '
      'exists, syncCycle POSTs to /events', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    final now = DateTime.now().toUtc();
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s1',
      eventType: 'finalized',
      answers: <String, Object?>{
        'startTime': now.toIso8601String(),
        'intensity': 'spotting',
      },
    );

    final events = await fx.runtime.backend.findEventsForAggregate('agg-s1');
    expect(events, hasLength(1));
    expect(events.single.entryType, 'epistaxis_event');
    expect(events.single.eventType, 'finalized');

    final viewRow = await fx.runtime.backend.findEntries(
      entryType: 'epistaxis_event',
    );
    expect(viewRow, hasLength(1));
    expect(viewRow.single.entryId, 'agg-s1');

    // Activate -> historical replay promotes the event into the FIFO,
    // then drain delivers it.
    await _activate(fx);
    await fx.runtime.syncCycle();

    final posts = fx.requests.where((r) => r.method == 'POST').toList();
    expect(posts, isNotEmpty);
    expect(posts.first.url.toString(), '${_baseUrl}events');

    // The FIFO row for this batch should now be in `sent` state.
    final fifo = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifo, isNotEmpty);
    expect(fifo.last.finalStatus, FinalStatus.sent);
  });

  // -------------------------------------------------------------------------
  // Scenario 2: Nosebleed edit -> 2 events on same aggregate, view shows
  // latest, sync POSTs both events in FIFO order.
  // -------------------------------------------------------------------------
  test('scenario 2: edit nosebleed -> 2 events on aggregate, view reflects '
      'latest, both drained', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    final now = DateTime.now().toUtc();
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s2',
      eventType: 'finalized',
      answers: <String, Object?>{
        'startTime': now.toIso8601String(),
        'intensity': 'spotting',
      },
    );
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s2',
      eventType: 'finalized',
      answers: <String, Object?>{
        'startTime': now.toIso8601String(),
        'intensity': 'pouring',
      },
      changeReason: 'patient correction',
    );

    final events = await fx.runtime.backend.findEventsForAggregate('agg-s2');
    expect(events, hasLength(2));

    final viewRow = (await fx.runtime.backend.findEntries(
      entryType: 'epistaxis_event',
    )).singleWhere((e) => e.entryId == 'agg-s2');
    expect(viewRow.currentAnswers['intensity'], 'pouring');
    expect(viewRow.isComplete, isTrue);
    expect(viewRow.isDeleted, isFalse);

    await _activate(fx);
    await fx.runtime.syncCycle();

    final posts = fx.requests.where((r) => r.method == 'POST').toList();
    expect(posts.length, greaterThanOrEqualTo(2));

    // FIFO drain order is sequence_in_queue ascending; both rows must be
    // sent (REQ-d00155 — destination contract drains in order).
    final fifo = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifo, hasLength(greaterThanOrEqualTo(2)));
    for (final row in fifo) {
      expect(row.finalStatus, FinalStatus.sent);
    }
  });

  // -------------------------------------------------------------------------
  // Scenario 3: Nosebleed delete -> tombstone, view marks deleted.
  // -------------------------------------------------------------------------
  test(
    'scenario 3: tombstone after finalized -> view row.isDeleted=true; '
    'entriesForDate still surfaces it (reader does not filter deletes)',
    () async {
      final fx = await _build();
      addTearDown(fx.tearDown);

      final now = DateTime.now().toUtc();
      await fx.runtime.entryService.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-s3',
        eventType: 'finalized',
        answers: <String, Object?>{'startTime': now.toIso8601String()},
      );
      await fx.runtime.entryService.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-s3',
        eventType: 'tombstone',
        answers: const <String, Object?>{},
        changeReason: 'patient retracted',
      );

      final events = await fx.runtime.backend.findEventsForAggregate('agg-s3');
      expect(events, hasLength(2));
      expect(events.last.eventType, 'tombstone');

      final viewRow = (await fx.runtime.backend.findEntries(
        entryType: 'epistaxis_event',
      )).singleWhere((e) => e.entryId == 'agg-s3');
      expect(viewRow.isDeleted, isTrue);

      // The reader does not currently filter tombstoned rows out of
      // entriesForDate (see DiaryEntryReader.entriesForDate); the row is
      // returned with isDeleted=true so callers can branch as needed.
      final today = DateTime.now();
      final entries = await fx.runtime.reader.entriesForDate(
        today,
        entryType: 'epistaxis_event',
      );
      final s3 = entries.where((e) => e.entryId == 'agg-s3').toList();
      expect(s3, hasLength(1));
      expect(s3.single.isDeleted, isTrue);

      // dayStatus, however, must IGNORE tombstoned entries: with only this
      // tombstoned epistaxis the day is notRecorded, not nosebleed.
      final status = await fx.runtime.reader.dayStatus(today);
      expect(status, DayStatus.notRecorded);
    },
  );

  // -------------------------------------------------------------------------
  // Scenario 4: Questionnaire submit -> finalized event, drained.
  // -------------------------------------------------------------------------
  test('scenario 4: survey finalized -> 1 event, view is_complete=true, '
      'drained to /events', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    // The survey type id comes from the loader (questionnaire id +
    // "_survey"). nose_hht is one of the bundled questionnaires, so
    // 'nose_hht_survey' is registered.
    expect(
      fx.runtime.entryService.entryTypes.byId('nose_hht_survey'),
      isNotNull,
    );

    await fx.runtime.entryService.record(
      entryType: 'nose_hht_survey',
      aggregateId: 'agg-s4',
      eventType: 'finalized',
      answers: const <String, Object?>{'q1': 0, 'q2': 1, 'cycle': 'week-3'},
    );

    final events = await fx.runtime.backend.findEventsForAggregate('agg-s4');
    expect(events, hasLength(1));

    final viewRow = (await fx.runtime.backend.findEntries(
      entryType: 'nose_hht_survey',
    )).singleWhere((e) => e.entryId == 'agg-s4');
    expect(viewRow.isComplete, isTrue);
    expect(viewRow.isDeleted, isFalse);

    await _activate(fx);
    await fx.runtime.syncCycle();

    final posts = fx.requests.where((r) => r.method == 'POST').toList();
    expect(posts, isNotEmpty);
    expect(posts.any((r) => r.url.toString() == '${_baseUrl}events'), isTrue);
  });

  // -------------------------------------------------------------------------
  // Scenario 5: REQ-d00113-D — tombstone inbound materializes a tombstone.
  // -------------------------------------------------------------------------
  test('scenario 5: portalInboundPoll receives tombstone for survey -> '
      'tombstone event recorded, view row is_deleted=true', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    // Pre-record a finalized survey so the tombstone has something to mark
    // deleted in the view layer.
    await fx.runtime.entryService.record(
      entryType: 'nose_hht_survey',
      aggregateId: 'agg-s5',
      eventType: 'finalized',
      answers: const <String, Object?>{'q1': 1},
    );

    // Configure the GET /inbound response to return one tombstone.
    fx.handler.impl = (req) async {
      if (req.method == 'GET' && req.url.path.endsWith('inbound')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {
                'type': 'tombstone',
                'entry_id': 'agg-s5',
                'entry_type': 'nose_hht_survey',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('', 200);
    };

    // Drive inbound directly. (Triggers wire this in production; calling
    // the function here is a unit-level shortcut at the integration scope.)
    await portalInboundPoll(
      entryService: fx.runtime.entryService,
      client: MockClient((req) async => fx.handler.impl(req)),
      resolveBaseUrl: () async => Uri.parse(_baseUrl),
    );

    final events = await fx.runtime.backend.findEventsForAggregate('agg-s5');
    expect(events, hasLength(2));
    expect(events.last.eventType, 'tombstone');

    final viewRow = (await fx.runtime.backend.findEntries(
      entryType: 'nose_hht_survey',
    )).singleWhere((e) => e.entryId == 'agg-s5');
    expect(viewRow.isDeleted, isTrue);
  });

  // -------------------------------------------------------------------------
  // Scenario 6: REQ-d00113-C — 409 questionnaire_deleted drains the FIFO.
  // -------------------------------------------------------------------------
  test('scenario 6: 409 {error: questionnaire_deleted} -> FIFO drains '
      '(SendOk), no wedge', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    fx.handler.impl = (req) async {
      if (req.method == 'POST' && req.url.path.endsWith('events')) {
        return http.Response(
          jsonEncode({'error': 'questionnaire_deleted'}),
          409,
        );
      }
      if (req.url.path.endsWith('inbound')) {
        return http.Response('{"messages":[]}', 200);
      }
      return http.Response('', 200);
    };

    await fx.runtime.entryService.record(
      entryType: 'nose_hht_survey',
      aggregateId: 'agg-s6',
      eventType: 'finalized',
      answers: const <String, Object?>{'q1': 0},
    );

    await _activate(fx);
    await fx.runtime.syncCycle();

    expect(await fx.runtime.backend.anyFifoWedged(), isFalse);
    final fifo = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifo, isNotEmpty);
    expect(fifo.last.finalStatus, FinalStatus.sent);
  });

  // -------------------------------------------------------------------------
  // Scenario 7: 4xx other than 409+questionnaire_deleted -> FIFO wedges.
  // -------------------------------------------------------------------------
  test('scenario 7: server returns 400 -> SendPermanent, FIFO row wedged, '
      'anyFifoWedged=true', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    fx.handler.impl = (req) async {
      if (req.method == 'POST' && req.url.path.endsWith('events')) {
        return http.Response('bad request', 400);
      }
      if (req.url.path.endsWith('inbound')) {
        return http.Response('{"messages":[]}', 200);
      }
      return http.Response('', 200);
    };

    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s7',
      eventType: 'finalized',
      answers: <String, Object?>{
        'startTime': DateTime.now().toUtc().toIso8601String(),
      },
    );

    await _activate(fx);
    await fx.runtime.syncCycle();

    expect(await fx.runtime.backend.anyFifoWedged(), isTrue);
    final fifo = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifo, isNotEmpty);
    expect(fifo.last.finalStatus, FinalStatus.wedged);
  });

  // -------------------------------------------------------------------------
  // Scenario 8: Offline -> online -> queued events drain.
  // -------------------------------------------------------------------------
  test('scenario 8: ClientException then 200 -> events queue while offline, '
      'drain when online', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    // Phase 1: simulate offline. POST throws ClientException.
    fx.handler.impl = (req) async {
      if (req.method == 'POST' && req.url.path.endsWith('events')) {
        throw http.ClientException('Connection refused');
      }
      if (req.url.path.endsWith('inbound')) {
        return http.Response('{"messages":[]}', 200);
      }
      return http.Response('', 200);
    };

    final now = DateTime.now().toUtc();
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s8-1',
      eventType: 'finalized',
      answers: <String, Object?>{'startTime': now.toIso8601String()},
    );
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s8-2',
      eventType: 'finalized',
      answers: <String, Object?>{'startTime': now.toIso8601String()},
    );

    // Activate so historical replay populates the FIFO with both events.
    await _activate(fx);
    await fx.runtime.syncCycle();

    // Both events landed in the log.
    final eventsAfterOffline = await fx.runtime.backend.findAllEvents();
    expect(
      eventsAfterOffline.where((e) => e.aggregateId.startsWith('agg-s8-')),
      hasLength(2),
    );

    // FIFO rows exist but neither is sent (transient -> still drainable).
    final fifoOffline = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifoOffline, hasLength(greaterThanOrEqualTo(2)));
    for (final row in fifoOffline) {
      expect(row.finalStatus, isNot(FinalStatus.sent));
      expect(row.finalStatus, isNot(FinalStatus.wedged));
    }
    expect(await fx.runtime.backend.anyFifoWedged(), isFalse);

    // Phase 2: come back online — POST returns 200.
    fx.handler.impl = (req) async {
      if (req.url.path.endsWith('inbound')) {
        return http.Response('{"messages":[]}', 200);
      }
      return http.Response('', 200);
    };

    // The offline attempt scheduled an exponential backoff (initialBackoff
    // = 60s under SyncPolicy.defaults). Bypass the backoff by calling drain
    // directly with a clock advanced past the backoff window — this matches
    // the lib's own time-sensitive drain tests. SyncCycle.call() is the
    // production trigger; here we exercise the same drain primitive
    // SyncCycle invokes, with a non-default clock.
    final destination = fx.runtime.destinations.byId('primary_diary_server')!;
    await drain(
      destination,
      backend: fx.runtime.backend,
      clock: () => DateTime.now().toUtc().add(const Duration(hours: 4)),
    );

    final fifoOnline = await fx.runtime.backend.listFifoEntries(
      'primary_diary_server',
    );
    expect(fifoOnline.length, greaterThanOrEqualTo(2));
    // Every previously-pending row must now be sent.
    for (final row in fifoOnline) {
      expect(row.finalStatus, FinalStatus.sent);
    }
  });

  // -------------------------------------------------------------------------
  // Scenario 9: Cycle stamping survives across events on same aggregate.
  // -------------------------------------------------------------------------
  test('scenario 9: cycle answer is preserved on the recorded event', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    await fx.runtime.entryService.record(
      entryType: 'nose_hht_survey',
      aggregateId: 'agg-s9',
      eventType: 'finalized',
      answers: const <String, Object?>{'q1': 0, 'cycle': 'week-3'},
    );

    final events = await fx.runtime.backend.findEventsForAggregate('agg-s9');
    expect(events, hasLength(1));
    final answers = events.single.data['answers'] as Map<String, Object?>;
    expect(answers['cycle'], 'week-3');

    final viewRow = (await fx.runtime.backend.findEntries(
      entryType: 'nose_hht_survey',
    )).singleWhere((e) => e.entryId == 'agg-s9');
    expect(viewRow.currentAnswers['cycle'], 'week-3');
  });

  // -------------------------------------------------------------------------
  // Scenario 10: New questionnaire JSON -> loader includes a survey entry
  // type for it. Confirms loader is data-driven.
  // -------------------------------------------------------------------------
  test(
    'scenario 10: loadClinicalDiaryEntryTypes maps each questionnaire JSON '
    'entry to a "<id>_survey" entry type with widgetId survey_renderer_v1',
    () async {
      // Inject a fixture JSON containing one new questionnaire alongside an
      // existing-shaped one. The id-to-entry-type mapping is `${id}_survey`,
      // so id "extra_survey" yields entry-type id "extra_survey_survey".
      const fixtureJson = '''
    {
      "questionnaires": [
        {
          "id": "nose_hht",
          "name": "Nose HHT",
          "categories": [],
          "questions": []
        },
        {
          "id": "extra_survey",
          "name": "Extra",
          "categories": [],
          "questions": []
        }
      ]
    }
    ''';

      final entryTypes = await loadClinicalDiaryEntryTypes(
        jsonLoader: () async => fixtureJson,
      );

      final byId = {for (final t in entryTypes) t.id: t};

      // Three static nosebleed types are always present.
      expect(byId.containsKey('epistaxis_event'), isTrue);
      expect(byId.containsKey('no_epistaxis_event'), isTrue);
      expect(byId.containsKey('unknown_day_event'), isTrue);

      // The survey types come straight from the JSON. The new "extra_survey"
      // questionnaire flows through with no Dart change.
      expect(byId.containsKey('nose_hht_survey'), isTrue);
      expect(byId.containsKey('extra_survey_survey'), isTrue);
      expect(byId['extra_survey_survey']!.widgetId, 'survey_renderer_v1');
      expect(byId['nose_hht_survey']!.widgetId, 'survey_renderer_v1');
    },
  );

  // -------------------------------------------------------------------------
  // Scenario 11: dayStatus over a range -> 5-value enum mapping.
  // -------------------------------------------------------------------------
  test('scenario 11: dayStatus returns nosebleed / noNosebleed / unknown / '
      'incomplete / notRecorded across distinct days', () async {
    final fx = await _build();
    addTearDown(fx.tearDown);

    // Use deterministic local-midnight days well in the past so each
    // entry's effective date lands on a distinct local calendar day.
    DateTime localDay(int offset) {
      final base = DateTime(2024, 1, 10);
      return base.add(Duration(days: offset));
    }

    final dayX = localDay(0); // nosebleed
    final dayX1 = localDay(1); // noNosebleed
    final dayX2 = localDay(2); // unknown
    final dayX3 = localDay(3); // incomplete (checkpoint, never finalized)
    final dayX4 = localDay(4); // notRecorded

    // epistaxis_event uses effectiveDatePath: 'startTime'.
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s11-x',
      eventType: 'finalized',
      answers: <String, Object?>{'startTime': dayX.toIso8601String()},
    );
    // no_epistaxis_event uses effectiveDatePath: 'date'.
    await fx.runtime.entryService.record(
      entryType: 'no_epistaxis_event',
      aggregateId: 'agg-s11-x1',
      eventType: 'finalized',
      answers: <String, Object?>{'date': dayX1.toIso8601String()},
    );
    // unknown_day_event uses effectiveDatePath: 'date'.
    await fx.runtime.entryService.record(
      entryType: 'unknown_day_event',
      aggregateId: 'agg-s11-x2',
      eventType: 'finalized',
      answers: <String, Object?>{'date': dayX2.toIso8601String()},
    );
    // Checkpoint (incomplete) on dayX3 — epistaxis_event with startTime.
    await fx.runtime.entryService.record(
      entryType: 'epistaxis_event',
      aggregateId: 'agg-s11-x3',
      eventType: 'checkpoint',
      answers: <String, Object?>{'startTime': dayX3.toIso8601String()},
    );

    expect(await fx.runtime.reader.dayStatus(dayX), DayStatus.nosebleed);
    expect(await fx.runtime.reader.dayStatus(dayX1), DayStatus.noNosebleed);
    expect(await fx.runtime.reader.dayStatus(dayX2), DayStatus.unknown);
    expect(await fx.runtime.reader.dayStatus(dayX3), DayStatus.incomplete);
    expect(await fx.runtime.reader.dayStatus(dayX4), DayStatus.notRecorded);
  });
}
