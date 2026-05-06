import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/destinations/legacy_questionnaire_submit_destination.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _surveyTypeIds = <String>['nose_hht_survey', 'qol_survey'];

const _validResponses = <Map<String, Object?>>[
  {
    'question_id': 'q1',
    'value': 2,
    'display_label': 'Sometimes',
    'normalized_label': '2',
  },
  {
    'question_id': 'q2',
    'value': 0,
    'display_label': 'Never',
    'normalized_label': '0',
  },
];

Map<String, dynamic> _validData({
  String questionnaireType = 'nose_hht',
  String version = '1.0.0',
  String completedAt = '2026-04-27T10:00:00.000Z',
  List<Map<String, Object?>> responses = _validResponses,
}) => <String, dynamic>{
  // EntryService.record wraps caller-supplied maps under data['answers'].
  // Unit tests synthesize events directly, so they reproduce that
  // wrapping here.
  'answers': <String, Object?>{
    'instance_id': 'agg-uuid-001',
    'questionnaire_type': questionnaireType,
    'version': version,
    'completed_at': completedAt,
    'responses': responses,
  },
};

StoredEvent _makeEvent({
  String eventId = 'evt-001',
  String aggregateId = 'agg-uuid-001',
  String entryType = 'nose_hht_survey',
  String eventType = 'finalized',
  Map<String, dynamic>? data,
  Map<String, dynamic> metadata = const {'change_reason': 'initial'},
}) => StoredEvent.synthetic(
  eventId: eventId,
  aggregateId: aggregateId,
  entryType: entryType,
  eventType: eventType,
  data: data ?? _validData(),
  metadata: metadata,
  initiator: const UserInitiator('user-123'),
  clientTimestamp: DateTime.utc(2026, 4, 27, 10, 0, 0),
  eventHash: 'abc123hash',
);

LegacyQuestionnaireSubmitDestination _destination({
  required http.Client client,
  String baseUrl = 'https://diary.example.com/api/v1/user/',
  Future<Uri?> Function()? resolveBaseUrl,
  Future<String?> Function()? authToken,
  List<String>? entryTypeIds,
}) => LegacyQuestionnaireSubmitDestination(
  client: client,
  resolveBaseUrl: resolveBaseUrl ?? () async => Uri.parse(baseUrl),
  authToken: authToken ?? () async => 'test-token',
  entryTypeIds: entryTypeIds ?? _surveyTypeIds,
);

void main() {
  group('LegacyQuestionnaireSubmitDestination', () {
    // -----------------------------------------------------------------------
    // Static properties
    // -----------------------------------------------------------------------

    test('id is legacy_questionnaire_submit', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.id, 'legacy_questionnaire_submit');
    });

    test('wireFormat is legacy-questionnaire-submit-v1', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.wireFormat, 'legacy-questionnaire-submit-v1');
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
      test('admits finalized survey events', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        for (final id in _surveyTypeIds) {
          expect(
            dest.filter.matches(_makeEvent(entryType: id)),
            isTrue,
            reason: '$id finalized should be admitted',
          );
        }
      });

      test('rejects entry types outside the survey list', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        expect(
          dest.filter.matches(_makeEvent(entryType: 'epistaxis_event')),
          isFalse,
        );
      });

      test('rejects non-finalized event types (e.g. tombstone)', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        expect(
          dest.filter.matches(_makeEvent(eventType: 'tombstone')),
          isFalse,
          reason: 'survey tombstones are inbound from server, never outbound',
        );
      });

      test('rejects events with change_reason == portal-withdrawn', () {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        // Defense-in-depth: even if a finalized event somehow carried
        // portal-withdrawn change_reason, the predicate rejects it.
        final event = _makeEvent(
          metadata: const {'change_reason': 'portal-withdrawn'},
        );
        expect(dest.filter.matches(event), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // transform
    // -----------------------------------------------------------------------

    group('transform', () {
      test('throws ArgumentError on empty batch', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        expect(() => dest.transform([]), throwsArgumentError);
      });

      test('throws FormatException when data has no answers map', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final event = _makeEvent(
          data: <String, dynamic>{
            // 'answers' deliberately missing
            'something_else': 1,
          },
        );
        expect(() => dest.transform([event]), throwsA(isA<FormatException>()));
      });

      test(
        'throws FormatException when data.answers has no responses list',
        () async {
          final dest = _destination(
            client: MockClient((_) async => http.Response('', 200)),
          );
          final event = _makeEvent(
            data: <String, dynamic>{
              'answers': <String, Object?>{
                'instance_id': 'agg-uuid-001',
                'questionnaire_type': 'nose_hht',
                'version': '1.0.0',
                'completed_at': '2026-04-27T10:00:00.000Z',
                // 'responses' deliberately missing
              },
            },
          );
          expect(
            () => dest.transform([event]),
            throwsA(isA<FormatException>()),
          );
        },
      );

      test('produces application/json with transformVersion v1', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final payload = await dest.transform([_makeEvent()]);
        expect(payload.contentType, 'application/json');
        expect(payload.transformVersion, 'v1');
      });

      test('body shape: instance_id (from aggregateId) + responses + '
          'questionnaire_type + version + completed_at', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final payload = await dest.transform([_makeEvent()]);
        final body =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        expect(body['instance_id'], 'agg-uuid-001');
        expect(body['questionnaire_type'], 'nose_hht');
        expect(body['version'], '1.0.0');
        expect(body['completed_at'], '2026-04-27T10:00:00.000Z');
        final responses = body['responses'] as List<dynamic>;
        expect(responses, hasLength(2));
        final first = responses.first as Map<String, dynamic>;
        expect(first['question_id'], 'q1');
        expect(first['display_label'], 'Sometimes');
        expect(first['normalized_label'], '2');
      });

      test('uses event.aggregateId as the instance_id', () async {
        final dest = _destination(
          client: MockClient((_) async => http.Response('', 200)),
        );
        final payload = await dest.transform([
          _makeEvent(aggregateId: 'agg-uuid-XYZ'),
        ]);
        final body =
            jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
        expect(body['instance_id'], 'agg-uuid-XYZ');
      });
    });

    // -----------------------------------------------------------------------
    // send — URL construction + classification
    // -----------------------------------------------------------------------

    group('send', () {
      test('POSTs to <baseUrl>/questionnaires/<instanceId>/submit', () async {
        Uri? capturedUrl;
        final client = MockClient((request) async {
          capturedUrl = request.url;
          return http.Response('', 200);
        });
        final dest = _destination(
          client: client,
          baseUrl: 'https://diary.example.com/api/v1/user/',
        );
        final payload = await dest.transform([
          _makeEvent(aggregateId: 'inst-AAA'),
        ]);
        await dest.send(payload);
        expect(
          capturedUrl.toString(),
          'https://diary.example.com/api/v1/user/questionnaires/inst-AAA/submit',
        );
      });

      test('strips instance_id from the wire body', () async {
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 200);
        });
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        await dest.send(payload);
        expect(capturedBody, isNotNull);
        expect(
          capturedBody!.keys,
          isNot(contains('instance_id')),
          reason: 'instance_id is in the URL path, not the body',
        );
        expect(
          capturedBody!.keys,
          containsAll(<String>[
            'responses',
            'questionnaire_type',
            'version',
            'completed_at',
          ]),
        );
      });

      test('200 response returns SendOk', () async {
        final client = MockClient(
          (_) async => http.Response('{"success": true}', 200),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendOk>());
      });

      test('409 with {"error": "questionnaire_deleted"} returns SendOk so the '
          'FIFO drains', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'questionnaire_deleted'}),
            409,
          ),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendOk>());
      });

      test('409 with other error body returns SendPermanent', () async {
        final client = MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'invalid_status'}), 409),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendPermanent;
        expect(result.error, contains('409'));
      });

      test('409 with non-JSON body returns SendPermanent', () async {
        final client = MockClient(
          (_) async => http.Response('plain text 409', 409),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendPermanent>());
      });

      test('400 returns SendPermanent', () async {
        final client = MockClient(
          (_) async => http.Response('bad request', 400),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendPermanent>());
      });

      test('500 returns SendTransient with httpStatus 500', () async {
        final client = MockClient(
          (_) async => http.Response('internal error', 500),
        );
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        final result = await dest.send(payload) as SendTransient;
        expect(result.httpStatus, 500);
      });

      test('http.ClientException returns SendTransient', () async {
        final client = MockClient((_) async {
          throw http.ClientException('connection refused');
        });
        final dest = _destination(client: client);
        final payload = await dest.transform([_makeEvent()]);
        expect(await dest.send(payload), isA<SendTransient>());
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
