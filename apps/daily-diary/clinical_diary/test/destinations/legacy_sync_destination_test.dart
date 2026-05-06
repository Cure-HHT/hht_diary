import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/destinations/legacy_sync_destination.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _nosebleedTypeIds = <String>[
  'epistaxis_event',
  'no_epistaxis_event',
  'unknown_day_event',
];

StoredEvent _makeEvent({
  String eventId = 'evt-001',
  String aggregateId = '8238a964-4cc6-4e27-8655-9978f31d0975',
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
  Map<String, dynamic>? data,
  Map<String, dynamic> metadata = const {'change_reason': 'initial'},
}) => StoredEvent.synthetic(
  eventId: eventId,
  aggregateId: aggregateId,
  entryType: entryType,
  eventType: eventType,
  // EntryService.record nests the user-supplied map under data['answers'];
  // unit tests synthesize events directly so they reproduce that shape.
  data:
      data ??
      <String, dynamic>{
        'answers': <String, dynamic>{
          'startTime': '2026-04-27T10:00:00.000Z',
          'intensity': 'mild',
        },
      },
  metadata: metadata,
  initiator: const UserInitiator('user-123'),
  clientTimestamp: DateTime.utc(2026, 4, 27, 10, 0, 0),
  eventHash: 'abc123hash',
);

LegacySyncDestination _destination({
  required http.Client client,
  String baseUrl = 'https://diary.example.com/api/v1/user/',
  Future<Uri?> Function()? resolveBaseUrl,
  Future<String?> Function()? authToken,
  List<String>? entryTypeIds,
}) => LegacySyncDestination(
  client: client,
  resolveBaseUrl: resolveBaseUrl ?? () async => Uri.parse(baseUrl),
  authToken: authToken ?? () async => 'test-token',
  entryTypeIds: entryTypeIds ?? _nosebleedTypeIds,
);

void main() {
  group('LegacySyncDestination', () {
    // -----------------------------------------------------------------------
    // Static properties
    // -----------------------------------------------------------------------

    test('id is legacy_sync', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.id, 'legacy_sync');
    });

    test('wireFormat is legacy-sync-v1', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.wireFormat, 'legacy-sync-v1');
    });

    test('maxAccumulateTime is Duration.zero', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.maxAccumulateTime, Duration.zero);
    });

    test('canAddToBatch always returns false', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final event = _makeEvent();
      expect(dest.canAddToBatch([], event), isFalse);
      expect(dest.canAddToBatch([event], event), isFalse);
    });

    // -----------------------------------------------------------------------
    // Filter
    // -----------------------------------------------------------------------

    group('filter', () {
      test('admits nosebleed entry types with default change_reason', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        for (final id in _nosebleedTypeIds) {
          expect(
            dest.filter.matches(_makeEvent(entryType: id)),
            isTrue,
            reason: '$id should be admitted',
          );
        }
      });

      test('rejects entry types outside the configured list', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        expect(
          dest.filter.matches(_makeEvent(entryType: 'nose_hht_survey')),
          isFalse,
        );
      });

      test('rejects events with change_reason == portal-withdrawn', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(
          eventType: 'tombstone',
          metadata: const {'change_reason': 'portal-withdrawn'},
        );
        expect(
          dest.filter.matches(event),
          isFalse,
          reason:
              'Portal-withdrawn tombstones already came from the server; '
              'shipping them back would be a wasted echo.',
        );
      });

      test(
        'admits user-initiated tombstones (change_reason != portal-withdrawn)',
        () {
          final dest = _destination(
            client: MockClient((_) async => http.Response('', 200)),
          );
          final event = _makeEvent(
            eventType: 'tombstone',
            metadata: const {'change_reason': 'user-deleted'},
          );
          expect(dest.filter.matches(event), isTrue);
        },
      );
    });

    // -----------------------------------------------------------------------
    // transform — event-type translation + body shape
    // -----------------------------------------------------------------------

    group('transform', () {
      test('throws ArgumentError on empty batch', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        expect(() => dest.transform([]), throwsArgumentError);
      });

      test('produces application/json with transformVersion v1', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final payload = await dest.transform([_makeEvent()]);
        expect(payload.contentType, 'application/json');
        expect(payload.transformVersion, 'v1');
      });

      test('wraps the event in {events: [event]}', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent();
        final payload = await dest.transform([event]);
        final decoded =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        expect(decoded.keys, contains('events'));
        final events = decoded['events'] as List<dynamic>;
        expect(events, hasLength(1));
        expect((events.single as Map<String, dynamic>)['event_id'], 'evt-001');
      });

      test('translates finalized -> nosebleedupdated on the wire', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(eventType: 'finalized');
        final payload = await dest.transform([event]);
        final decoded =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        final wireEvent =
            (decoded['events'] as List).single as Map<String, dynamic>;
        expect(wireEvent['event_type'], 'nosebleedupdated');
      });

      test('translates tombstone -> nosebleeddeleted on the wire', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(eventType: 'tombstone');
        final payload = await dest.transform([event]);
        final decoded =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        final wireEvent =
            (decoded['events'] as List).single as Map<String, dynamic>;
        expect(wireEvent['event_type'], 'nosebleeddeleted');
      });

      test('passes through unknown event_types unchanged', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(eventType: 'somethingNew');
        final payload = await dest.transform([event]);
        final decoded =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        final wireEvent =
            (decoded['events'] as List).single as Map<String, dynamic>;
        expect(wireEvent['event_type'], 'somethingNew');
      });

      // -----------------------------------------------------------------
      // Data-payload projection — legacy EventRecord shape.
      // The server's record_audit validate_diary_data trigger requires
      // {id, versioned_type, event_data} at the top level of `data`.
      // -----------------------------------------------------------------

      test('projects data into {id, versioned_type, event_data}', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(aggregateId: 'agg-uuid-XYZ');
        final payload = await dest.transform([event]);
        final wireEvent =
            ((jsonDecode(utf8.decode(payload.bytes)) as Map)['events'] as List)
                    .single
                as Map<String, dynamic>;
        final data = wireEvent['data'] as Map<String, dynamic>;
        expect(data['id'], 'agg-uuid-XYZ');
        expect(data['versioned_type'], 'epistaxis-v1.0');
        expect(data['event_data'], isA<Map<String, dynamic>>());
      });

      test('epistaxis_event: event_data carries id, startTime, lastModified, '
          'intensity passes through, no sub-type flag set', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(
          entryType: 'epistaxis_event',
          data: <String, dynamic>{
            'answers': <String, dynamic>{
              'startTime': '2026-04-27T09:00:00.000Z',
              'endTime': '2026-04-27T09:05:00.000Z',
              'intensity': 'spotting',
            },
          },
        );
        final payload = await dest.transform([event]);
        final wireEvent =
            ((jsonDecode(utf8.decode(payload.bytes)) as Map)['events'] as List)
                    .single
                as Map<String, dynamic>;
        final eventData =
            (wireEvent['data'] as Map)['event_data'] as Map<String, dynamic>;
        expect(eventData['id'], '8238a964-4cc6-4e27-8655-9978f31d0975');
        expect(eventData['startTime'], '2026-04-27T09:00:00.000Z');
        expect(eventData['lastModified'], '2026-04-27T10:00:00.000Z');
        expect(eventData['endTime'], '2026-04-27T09:05:00.000Z');
        expect(eventData['intensity'], 'spotting');
        expect(eventData.containsKey('isNoNosebleedsEvent'), isFalse);
        expect(eventData.containsKey('isUnknownNosebleedsEvent'), isFalse);
      });

      test('no_epistaxis_event: isNoNosebleedsEvent=true; startTime resolves '
          "from answers['date']; intensity dropped", () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(
          entryType: 'no_epistaxis_event',
          data: <String, dynamic>{
            'answers': <String, dynamic>{'date': '2026-04-26T00:00:00.000Z'},
          },
        );
        final payload = await dest.transform([event]);
        final wireEvent =
            ((jsonDecode(utf8.decode(payload.bytes)) as Map)['events'] as List)
                    .single
                as Map<String, dynamic>;
        final eventData =
            (wireEvent['data'] as Map)['event_data'] as Map<String, dynamic>;
        expect(eventData['isNoNosebleedsEvent'], isTrue);
        expect(eventData['startTime'], '2026-04-26T00:00:00.000Z');
        expect(eventData['lastModified'], '2026-04-27T10:00:00.000Z');
        // Special events must NOT carry intensity / endTime — the
        // validator rejects severity / endTime when the flag is set.
        expect(eventData.containsKey('intensity'), isFalse);
        expect(eventData.containsKey('endTime'), isFalse);
      });

      test(
        'unknown_day_event: isUnknownNosebleedsEvent=true; startTime resolves '
        "from answers['date']",
        () async {
          final dest = _destination(
            client: MockClient((_) async => http.Response('', 200)),
          );
          final event = _makeEvent(
            entryType: 'unknown_day_event',
            data: <String, dynamic>{
              'answers': <String, dynamic>{'date': '2026-04-25T00:00:00.000Z'},
            },
          );
          final payload = await dest.transform([event]);
          final wireEvent =
              ((jsonDecode(utf8.decode(payload.bytes)) as Map)['events']
                          as List)
                      .single
                  as Map<String, dynamic>;
          final eventData =
              (wireEvent['data'] as Map)['event_data'] as Map<String, dynamic>;
          expect(eventData['isUnknownNosebleedsEvent'], isTrue);
          expect(eventData['startTime'], '2026-04-25T00:00:00.000Z');
        },
      );

      test('tombstone with empty answers: startTime falls back to '
          'client_timestamp so the validator still passes', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(
          entryType: 'epistaxis_event',
          eventType: 'tombstone',
          data: const <String, dynamic>{'answers': <String, dynamic>{}},
        );
        final payload = await dest.transform([event]);
        final wireEvent =
            ((jsonDecode(utf8.decode(payload.bytes)) as Map)['events'] as List)
                    .single
                as Map<String, dynamic>;
        final eventData =
            (wireEvent['data'] as Map)['event_data'] as Map<String, dynamic>;
        expect(eventData['startTime'], '2026-04-27T10:00:00.000Z');
        expect(eventData['lastModified'], '2026-04-27T10:00:00.000Z');
      });
    });

    // -----------------------------------------------------------------------
    // send — HTTP classification
    // -----------------------------------------------------------------------

    group('send', () {
      test('200 response returns SendOk', () async {
        final client = MockClient(
          (_) async => http.Response('{"ok": true}', 200),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendOk>());
      });

      test('500 response returns SendTransient with httpStatus', () async {
        final client = MockClient(
          (_) async => http.Response('internal error', 500),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendTransient;
        expect(result.httpStatus, 500);
        expect(result.error, contains('500'));
      });

      test('400 response returns SendPermanent', () async {
        final client = MockClient(
          (_) async => http.Response('bad request', 400),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendPermanent;
        expect(result.error, contains('400'));
      });

      test('http.ClientException returns SendTransient', () async {
        final client = MockClient((_) async {
          throw http.ClientException('connection refused');
        });
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendTransient;
        expect(result.error, contains('connection refused'));
        expect(result.httpStatus, isNull);
      });

      test('TimeoutException returns SendTransient', () async {
        final client = MockClient((_) async {
          throw TimeoutException('request timed out');
        });
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendTransient;
        expect(result.error, startsWith('timeout:'));
      });

      test(
        'resolveBaseUrl returns null -> SendTransient, no HTTP call',
        () async {
          var clientCalled = false;
          final client = MockClient((_) async {
            clientCalled = true;
            return http.Response('', 200);
          });
          final dest = _destination(
            client: client,
            resolveBaseUrl: () async => null,
          );
          final payload = await dest.transform([_makeEvent()]);
          expect(await dest.send(payload), isA<SendTransient>());
          expect(clientCalled, isFalse);
        },
      );

      test('POSTs to <baseUrl>/sync', () async {
        Uri? capturedUrl;
        final client = MockClient((request) async {
          capturedUrl = request.url;
          return http.Response('', 200);
        });
        final dest = _destination(
          client: client,
          baseUrl: 'https://diary.example.com/api/v1/user/',
        );
        final payload = await dest.transform([_makeEvent()]);
        await dest.send(payload);
        expect(
          capturedUrl.toString(),
          'https://diary.example.com/api/v1/user/sync',
        );
      });

      test(
        'Authorization: Bearer <token> when authToken returns a token',
        () async {
          String? capturedAuth;
          final client = MockClient((request) async {
            capturedAuth = request.headers['authorization'];
            return http.Response('', 200);
          });
          final dest = _destination(
            client: client,
            authToken: () async => 'my-jwt-token',
          );
          final payload = await dest.transform([_makeEvent()]);
          await dest.send(payload);
          expect(capturedAuth, 'Bearer my-jwt-token');
        },
      );

      test('no Authorization header when authToken returns null', () async {
        var hadAuthHeader = false;
        final client = MockClient((request) async {
          hadAuthHeader = request.headers.containsKey('authorization');
          return http.Response('', 200);
        });
        final dest = _destination(client: client, authToken: () async => null);
        final payload = await dest.transform([_makeEvent()]);
        await dest.send(payload);
        expect(hadAuthHeader, isFalse);
      });
    });
  });
}
