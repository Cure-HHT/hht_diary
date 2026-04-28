// Verifies: REQ-d00113-D, REQ-d00156-A+B+C+D.

import 'dart:convert';

import 'package:clinical_diary/destinations/portal_inbound_poll.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

/// Bundles the collaborators needed to exercise [portalInboundPoll].
class _Fixture {
  _Fixture({required this.service, required this.backend});

  final EntryService service;
  final SembastBackend backend;
}

EntryTypeDefinition _defFor(String id) => EntryTypeDefinition(
  id: id,
  registeredVersion: 1,
  name: id,
  widgetId: 'widget-$id',
  widgetConfig: const <String, Object?>{},
  effectiveDatePath: null,
);

/// Creates a real [EntryService] backed by an in-memory [SembastBackend].
///
/// [entryTypeIds] pre-registers the given entry types so that tombstone
/// messages for those types are accepted by [EntryService.record].
Future<_Fixture> _setupFixture({
  List<String> entryTypeIds = const ['epistaxis_event'],
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'portal-inbound-poll-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();
  for (final id in entryTypeIds) {
    registry.register(_defFor(id));
  }
  final service = EntryService(
    backend: backend,
    entryTypes: registry,
    // Fire-and-forget trigger — no-op in tests.
    syncCycleTrigger: () async {},
    deviceInfo: const DeviceInfo(
      deviceId: 'device-test',
      softwareVersion: 'clinical_diary@0.0.0',
      userId: 'user-test',
    ),
  );
  return _Fixture(service: service, backend: backend);
}

/// Wraps [messages] in the expected server envelope.
String _envelope(List<Map<String, Object?>> messages) =>
    jsonEncode({'messages': messages});

/// Returns an [http.Response] with a 200 status and JSON [body].
http.Response _ok(String body) => http.Response(body, 200);

/// Returns a 500 response.
http.Response _serverError() => http.Response('Internal Server Error', 500);

const _baseUrl = 'https://diary.example.com/';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('portalInboundPoll', () {
    // -------------------------------------------------------------------------
    // Test 1: empty messages list -> no record calls
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-A — empty messages list produces no record calls.
    test('empty messages: [] produces no record calls', () async {
      final fx = await _setupFixture();

      final client = MockClient((_) async => _ok(_envelope([])));

      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
      );

      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 2: one tombstone message -> exactly one record call
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00113-D, REQ-d00156-A — a single tombstone message
    // materialises exactly one tombstone event via EntryService.record with
    // the correct fields.
    test(
      'one tombstone message -> exactly one tombstone record call',
      () async {
        final fx = await _setupFixture();

        final client = MockClient(
          (_) async => _ok(
            _envelope([
              {
                'type': 'tombstone',
                'entry_id': 'agg-abc',
                'entry_type': 'epistaxis_event',
              },
            ]),
          ),
        );

        await portalInboundPoll(
          entryService: fx.service,
          client: client,
          baseUrl: Uri.parse(_baseUrl),
        );

        final events = await fx.backend.findAllEvents();
        expect(events, hasLength(1));

        final evt = events.single;
        expect(evt.aggregateId, 'agg-abc');
        expect(evt.entryType, 'epistaxis_event');
        expect(evt.eventType, 'tombstone');
        expect(evt.data['answers'], <String, Object?>{});
        expect(evt.metadata['change_reason'], 'portal-withdrawn');

        await fx.backend.close();
      },
    );

    // -------------------------------------------------------------------------
    // Test 3: multiple tombstones -> one record per message, order preserved
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-A — multiple tombstone messages each produce one
    // record call; order matches message order.
    test(
      'multiple tombstones -> one record per message, order preserved',
      () async {
        final fx = await _setupFixture(
          entryTypeIds: ['epistaxis_event', 'daily_vitals'],
        );

        final client = MockClient(
          (_) async => _ok(
            _envelope([
              {
                'type': 'tombstone',
                'entry_id': 'agg-1',
                'entry_type': 'epistaxis_event',
              },
              {
                'type': 'tombstone',
                'entry_id': 'agg-2',
                'entry_type': 'daily_vitals',
              },
              {
                'type': 'tombstone',
                'entry_id': 'agg-3',
                'entry_type': 'epistaxis_event',
              },
            ]),
          ),
        );

        await portalInboundPoll(
          entryService: fx.service,
          client: client,
          baseUrl: Uri.parse(_baseUrl),
        );

        final events = await fx.backend.findAllEvents();
        expect(events, hasLength(3));
        expect(events[0].aggregateId, 'agg-1');
        expect(events[1].aggregateId, 'agg-2');
        expect(events[2].aggregateId, 'agg-3');
        for (final evt in events) {
          expect(evt.eventType, 'tombstone');
        }

        await fx.backend.close();
      },
    );

    // -------------------------------------------------------------------------
    // Test 4: 5xx response -> no calls, no exception
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-C — non-200 HTTP response is swallowed; no record
    // calls are made and no exception propagates to the caller.
    test('5xx response -> no record calls and no exception thrown', () async {
      final fx = await _setupFixture();

      final client = MockClient((_) async => _serverError());

      await expectLater(
        portalInboundPoll(
          entryService: fx.service,
          client: client,
          baseUrl: Uri.parse(_baseUrl),
        ),
        completes,
      );

      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 5: network exception -> no calls, no exception
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-C — a ClientException from the HTTP layer is
    // swallowed at the top level; no record calls and no exception propagates.
    test(
      'network ClientException -> no record calls and no exception thrown',
      () async {
        final fx = await _setupFixture();

        final client = MockClient((_) async {
          throw http.ClientException('Connection refused');
        });

        await expectLater(
          portalInboundPoll(
            entryService: fx.service,
            client: client,
            baseUrl: Uri.parse(_baseUrl),
          ),
          completes,
        );

        final events = await fx.backend.findAllEvents();
        expect(events, isEmpty);
        await fx.backend.close();
      },
    );

    // -------------------------------------------------------------------------
    // Test 6: unknown message type -> skipped
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-B — messages with unknown type are skipped;
    // no record call is made.
    test(
      'unknown message type "announce" -> skipped, no record call',
      () async {
        final fx = await _setupFixture();

        final client = MockClient(
          (_) async => _ok(
            _envelope([
              {
                'type': 'announce',
                'entry_id': 'agg-x',
                'entry_type': 'epistaxis_event',
              },
            ]),
          ),
        );

        await portalInboundPoll(
          entryService: fx.service,
          client: client,
          baseUrl: Uri.parse(_baseUrl),
        );

        final events = await fx.backend.findAllEvents();
        expect(events, isEmpty);
        await fx.backend.close();
      },
    );

    // -------------------------------------------------------------------------
    // Test 7: tombstone missing entry_id -> skipped
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-B — tombstone messages missing entry_id are
    // skipped without raising.
    test('tombstone missing entry_id -> skipped', () async {
      final fx = await _setupFixture();

      final client = MockClient(
        (_) async => _ok(
          _envelope([
            {
              'type': 'tombstone',
              // no entry_id
              'entry_type': 'epistaxis_event',
            },
          ]),
        ),
      );

      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
      );

      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 8: tombstone missing entry_type -> skipped
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-B — tombstone messages missing entry_type are
    // skipped without raising.
    test('tombstone missing entry_type -> skipped', () async {
      final fx = await _setupFixture();

      final client = MockClient(
        (_) async => _ok(
          _envelope([
            {
              'type': 'tombstone',
              'entry_id': 'agg-y',
              // no entry_type
            },
          ]),
        ),
      );

      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
      );

      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 9: auth header included when token non-null; absent when null/omitted
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-A — the Authorization: Bearer header is attached
    // when authToken() returns a non-null token, and is absent when authToken
    // is omitted or returns null.
    test('auth header present when authToken returns token', () async {
      final fx = await _setupFixture();

      http.Request? capturedRequest;
      final client = MockClient((req) async {
        capturedRequest = req;
        return _ok(_envelope([]));
      });

      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
        authToken: () async => 'my-secret-token',
      );

      expect(
        capturedRequest?.headers['authorization'],
        'Bearer my-secret-token',
      );
      await fx.backend.close();
    });

    test('auth header absent when authToken is omitted', () async {
      final fx = await _setupFixture();

      http.Request? capturedRequest;
      final client = MockClient((req) async {
        capturedRequest = req;
        return _ok(_envelope([]));
      });

      // authToken not provided (defaults to null)
      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
      );

      expect(capturedRequest?.headers.containsKey('authorization'), isFalse);
      await fx.backend.close();
    });

    test('auth header absent when authToken returns null', () async {
      final fx = await _setupFixture();

      http.Request? capturedRequest;
      final client = MockClient((req) async {
        capturedRequest = req;
        return _ok(_envelope([]));
      });

      await portalInboundPoll(
        entryService: fx.service,
        client: client,
        baseUrl: Uri.parse(_baseUrl),
        authToken: () async => null,
      );

      expect(capturedRequest?.headers.containsKey('authorization'), isFalse);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 10: non-JSON body -> no calls, no exception
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-C — a 200 response with a non-JSON body is
    // swallowed; no record calls and no exception propagates.
    test('non-JSON body -> no record calls and no exception thrown', () async {
      final fx = await _setupFixture();

      final client = MockClient((_) async => http.Response('not json!!', 200));

      await expectLater(
        portalInboundPoll(
          entryService: fx.service,
          client: client,
          baseUrl: Uri.parse(_baseUrl),
        ),
        completes,
      );

      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      await fx.backend.close();
    });

    // -------------------------------------------------------------------------
    // Test 11: per-message exception swallowed, loop continues
    // -------------------------------------------------------------------------

    // Verifies: REQ-d00156-D — a per-message exception (e.g. unregistered
    // entry_type causing ArgumentError) is swallowed and the loop continues
    // to process subsequent messages.
    test(
      'per-message exception swallowed; loop continues to next message',
      () async {
        // 'unknown_type' is NOT registered; 'epistaxis_event' is.
        // The first tombstone will throw ArgumentError (unregistered entryType),
        // but the second must still be recorded.
        final fx = await _setupFixture(entryTypeIds: ['epistaxis_event']);

        final client = MockClient(
          (_) async => _ok(
            _envelope([
              {
                'type': 'tombstone',
                'entry_id': 'agg-bad',
                'entry_type': 'unknown_type', // will throw ArgumentError
              },
              {
                'type': 'tombstone',
                'entry_id': 'agg-good',
                'entry_type': 'epistaxis_event',
              },
            ]),
          ),
        );

        await expectLater(
          portalInboundPoll(
            entryService: fx.service,
            client: client,
            baseUrl: Uri.parse(_baseUrl),
          ),
          completes,
        );

        final events = await fx.backend.findAllEvents();
        expect(events, hasLength(1));
        expect(events.single.aggregateId, 'agg-good');
        await fx.backend.close();
      },
    );
  });
}
