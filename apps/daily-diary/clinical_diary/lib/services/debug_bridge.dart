// Local-only HTTP debug surface for the clinical_diary runtime. Listens
// on 127.0.0.1 (loopback only) so the bridge is unreachable from any
// other host. Wired into the bootstrap behind a `F.appFlavor ==
// Flavor.local && !kIsWeb` guard so it never ships in dev/qa/uat/prod
// and never compiles into a web bundle (shelf needs dart:io).
//
// All endpoints return application/json (UTF-8). Routes:
//
//   GET  /debug/state                                 — roll-up
//   GET  /debug/destinations                          — registered destination ids
//   GET  /debug/schedule/<destId>                     — DestinationSchedule
//   GET  /debug/cursor/<destId>                       — fill_cursor int
//   GET  /debug/fifo/<destId>?limit=N                 — FIFO entries (newest tail)
//   GET  /debug/events?limit=N&since=N                — StoredEvents
//   GET  /debug/aggregate/<aggId>                     — events for one aggregate
//   POST /debug/sync                                  — fire syncCycle
//   POST /debug/tombstone-and-refill/<destId>/<rowId> — wedge recovery
//
// Cites no REQs — diagnostic surface, not a regulated artifact.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class DebugBridge {
  DebugBridge({
    required this.runtime,
    this.onTaskSync,
    this.host = '127.0.0.1',
    this.port = 9876,
  }) : assert(
         host == '127.0.0.1',
         'DebugBridge must only bind to loopback (127.0.0.1).',
       ) {
    // Asserts are stripped in release/profile builds, so back the loopback
    // invariant with a runtime check too. The Flavor.local + !kIsWeb gate
    // at the call site is the primary guard, this is defense in depth in
    // case the class is ever reused outside that gate.
    if (host != '127.0.0.1') {
      throw ArgumentError.value(
        host,
        'host',
        'DebugBridge must only bind to loopback (127.0.0.1).',
      );
    }
  }

  final ClinicalDiaryRuntime runtime;

  /// Invoked by `POST /debug/task-sync`. Closure should call into the
  /// app's TaskService.syncTasks(enrollmentService) so the test loop
  /// can trigger a server-task poll without hot-restarting the binary.
  /// Optional — when null, the route returns 503 service-unavailable.
  final Future<void> Function()? onTaskSync;

  final String host;
  final int port;
  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    _server = await shelf_io.serve(_router.call, host, port);
    debugPrint('[DebugBridge] listening on http://$host:$port');
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await server.close(force: true);
  }

  // ---------------------------------------------------------------------------
  // Router
  // ---------------------------------------------------------------------------

  Router get _router => Router()
    ..get('/debug/state', _state)
    ..get('/debug/destinations', _destinationsList)
    ..get('/debug/schedule/<destId>', _schedule)
    ..get('/debug/cursor/<destId>', _cursor)
    ..get('/debug/fifo/<destId>', _fifo)
    ..get('/debug/events', _events)
    ..get('/debug/aggregate/<aggId>', _aggregate)
    ..post('/debug/sync', _sync)
    ..post('/debug/task-sync', _taskSync)
    ..post('/debug/tombstone-and-refill/<destId>/<rowId>', _tombstoneAndRefill);

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<Response> _state(Request _) async {
    final destinations = runtime.destinations.all();
    final perDest = <Map<String, Object?>>[];
    for (final d in destinations) {
      final schedule = await runtime.destinations.scheduleOf(d.id);
      final cursor = await runtime.backend.readFillCursor(d.id);
      final fifo = await runtime.backend.listFifoEntries(d.id);
      perDest.add(<String, Object?>{
        'id': d.id,
        'wireFormat': d.wireFormat,
        'schedule': schedule.toJson(),
        'fillCursor': cursor,
        'fifoCount': fifo.length,
        'fifoHead': fifo.isEmpty
            ? null
            : <String, Object?>{
                'entryId': fifo.first.entryId,
                'finalStatus': fifo.first.finalStatus?.toJson(),
                'attempts': fifo.first.attempts.length,
              },
      });
    }
    return _json(<String, Object?>{
      'sequenceCounter': await runtime.backend.readSequenceCounter(),
      'anyFifoWedged': await runtime.backend.anyFifoWedged(),
      'destinations': perDest,
    });
  }

  Response _destinationsList(Request _) => _json(<String, Object?>{
    'ids': runtime.destinations.all().map((d) => d.id).toList(),
  });

  Future<Response> _schedule(Request req) async {
    final destId = req.params['destId']!;
    if (runtime.destinations.byId(destId) == null) return _notFound(destId);
    final schedule = await runtime.destinations.scheduleOf(destId);
    return _json(schedule.toJson());
  }

  Future<Response> _cursor(Request req) async {
    final destId = req.params['destId']!;
    if (runtime.destinations.byId(destId) == null) return _notFound(destId);
    return _json(<String, Object?>{
      'destId': destId,
      'cursor': await runtime.backend.readFillCursor(destId),
    });
  }

  Future<Response> _fifo(Request req) async {
    final destId = req.params['destId']!;
    if (runtime.destinations.byId(destId) == null) return _notFound(destId);
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '');
    var entries = await runtime.backend.listFifoEntries(destId);
    if (limit != null && entries.length > limit) {
      // Keep the newest `limit` rows (tail) — most useful for diagnosis.
      entries = entries.sublist(entries.length - limit);
    }
    return _json(<String, Object?>{
      'destId': destId,
      'count': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<Response> _events(Request req) async {
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '');
    final since = int.tryParse(req.url.queryParameters['since'] ?? '');
    final events = await runtime.backend.findAllEvents(
      afterSequence: since,
      limit: limit,
    );
    return _json(<String, Object?>{
      'count': events.length,
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  Future<Response> _aggregate(Request req) async {
    final aggId = req.params['aggId']!;
    final events = await runtime.backend.findEventsForAggregate(aggId);
    return _json(<String, Object?>{
      'aggregateId': aggId,
      'count': events.length,
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  Future<Response> _sync(Request _) async {
    await runtime.syncCycle();
    return _json(<String, Object?>{'ok': true});
  }

  Future<Response> _taskSync(Request _) async {
    final hook = onTaskSync;
    if (hook == null) {
      return Response(
        503,
        body: jsonEncode(<String, Object?>{
          'error': 'onTaskSync hook was not wired into DebugBridge',
        }),
        headers: const {'content-type': 'application/json'},
      );
    }
    await hook();
    return _json(<String, Object?>{'ok': true});
  }

  Future<Response> _tombstoneAndRefill(Request req) async {
    final destId = req.params['destId']!;
    final rowId = req.params['rowId']!;
    if (runtime.destinations.byId(destId) == null) return _notFound(destId);
    // tombstoneAndRefill throws ArgumentError when the target row is
    // not the current FIFO head; let that propagate to shelf's default
    // 500 handler — the stack identifies the precondition violation
    // and this is a diagnostic surface, not a hardened HTTP API.
    final result = await runtime.destinations.tombstoneAndRefill(
      destId,
      rowId,
      initiator: const AutomationInitiator(service: 'debug-bridge'),
    );
    return _json(<String, Object?>{
      'targetRowId': result.targetRowId,
      'deletedTrailCount': result.deletedTrailCount,
      'rewoundTo': result.rewoundTo,
    });
  }

  // ---------------------------------------------------------------------------
  // Response helpers
  // ---------------------------------------------------------------------------

  Response _json(Object body) => Response.ok(
    const JsonEncoder.withIndent('  ').convert(body),
    headers: const {'content-type': 'application/json'},
  );

  Response _notFound(String id) => Response.notFound(
    jsonEncode(<String, Object?>{'error': 'unknown destination: $id'}),
    headers: const {'content-type': 'application/json'},
  );
}
