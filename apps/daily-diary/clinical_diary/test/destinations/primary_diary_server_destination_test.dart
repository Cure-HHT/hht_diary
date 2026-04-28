// Verifies: REQ-d00155 (destination contract); REQ-d00113-C (409 translation).

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/destinations/primary_diary_server_destination.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

StoredEvent _makeEvent({
  String eventId = 'evt-001',
  String aggregateId = 'agg-001',
  String entryType = 'epistaxis_event',
}) => StoredEvent.synthetic(
  eventId: eventId,
  aggregateId: aggregateId,
  entryType: entryType,
  initiator: const UserInitiator('user-123'),
  clientTimestamp: DateTime.utc(2026, 4, 27, 10, 0, 0),
  eventHash: 'abc123hash',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PrimaryDiaryServerDestination _destination({
  required http.Client client,
  String baseUrl = 'https://diary.example.com/',
  Future<String?> Function()? authToken,
}) => PrimaryDiaryServerDestination(
  client: client,
  baseUrl: Uri.parse(baseUrl),
  authToken: authToken ?? () async => 'test-token',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PrimaryDiaryServerDestination', () {
    // -----------------------------------------------------------------------
    // Static properties
    // -----------------------------------------------------------------------

    test('id is primary_diary_server', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.id, 'primary_diary_server');
    });

    test('wireFormat is json-v1', () {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(dest.wireFormat, 'json-v1');
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
    // Test 1: transform produces a valid WirePayload
    // -----------------------------------------------------------------------

    test('transform([oneEvent]) produces WirePayload with correct contentType, '
        'transformVersion, and round-trippable JSON bytes', () async {
      final dest = _destination(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      expect(payload.contentType, 'application/json');
      expect(payload.transformVersion, 'v1');

      // Bytes must round-trip through JSON
      final decoded =
          jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
      expect(decoded, isA<Map<String, dynamic>>());
      // event_id must be present so the server can identify the event
      expect(decoded['event_id'], event.eventId);
    });

    // -----------------------------------------------------------------------
    // Test 2: 200 OK -> SendOk
    // -----------------------------------------------------------------------

    test('200 OK response returns SendOk', () async {
      final client = MockClient(
        (_) async => http.Response('{"ok": true}', 200),
      );
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendOk>());
    });

    // -----------------------------------------------------------------------
    // Test 3: 500 -> SendTransient
    // -----------------------------------------------------------------------

    test('500 response returns SendTransient with httpStatus 500', () async {
      final client = MockClient(
        (_) async => http.Response('internal error', 500),
      );
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendTransient>());
      final transient = result as SendTransient;
      expect(transient.httpStatus, 500);
      expect(transient.error, contains('500'));
    });

    // -----------------------------------------------------------------------
    // Test 4: 404 -> SendPermanent
    // -----------------------------------------------------------------------

    test('404 response returns SendPermanent', () async {
      final client = MockClient((_) async => http.Response('not found', 404));
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendPermanent>());
      final permanent = result as SendPermanent;
      expect(permanent.error, contains('404'));
    });

    // -----------------------------------------------------------------------
    // Test 5: REQ-d00113-C: 409 with questionnaire_deleted -> SendOk
    // -----------------------------------------------------------------------

    // Verifies: REQ-d00113-C
    test('REQ-d00113-C: 409 with {"error":"questionnaire_deleted"} returns '
        'SendOk so the FIFO drains', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'error': 'questionnaire_deleted'}), 409),
      );
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(
        result,
        isA<SendOk>(),
        reason:
            'A 409 questionnaire_deleted is a permanent server-side '
            'soft-delete; the locally recorded event remains the audit '
            'fact and the FIFO must drain (REQ-d00113-C).',
      );
    });

    // -----------------------------------------------------------------------
    // Test 6: 409 with other body -> SendPermanent
    // -----------------------------------------------------------------------

    test('409 with other error body returns SendPermanent', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'duplicate'}), 409),
      );
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendPermanent>());
      final permanent = result as SendPermanent;
      expect(permanent.error, contains('409'));
    });

    // -----------------------------------------------------------------------
    // Test 7: http.ClientException -> SendTransient
    // -----------------------------------------------------------------------

    test('http.ClientException from client returns SendTransient', () async {
      final client = MockClient((_) async {
        throw http.ClientException('connection refused');
      });
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendTransient>());
      final transient = result as SendTransient;
      expect(transient.error, contains('connection refused'));
      expect(transient.httpStatus, isNull);
    });

    // -----------------------------------------------------------------------
    // Test 8: TimeoutException -> SendTransient
    // -----------------------------------------------------------------------

    test('TimeoutException from client returns SendTransient', () async {
      final client = MockClient((_) async {
        throw TimeoutException('request timed out');
      });
      final dest = _destination(client: client);
      final event = _makeEvent();
      final payload = await dest.transform([event]);

      final result = await dest.send(payload);
      expect(result, isA<SendTransient>());
      final transient = result as SendTransient;
      expect(transient.error, startsWith('timeout:'));
    });

    // -----------------------------------------------------------------------
    // Test 9: POST goes to ${baseUrl}/events
    // -----------------------------------------------------------------------

    test('POST goes to baseUrl resolved with "events" path', () async {
      Uri? capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        return http.Response('', 200);
      });
      final dest = _destination(
        client: client,
        baseUrl: 'https://diary.example.com/api/v2/',
      );
      final event = _makeEvent();
      final payload = await dest.transform([event]);
      await dest.send(payload);

      expect(capturedUrl, isNotNull);
      expect(capturedUrl.toString(), 'https://diary.example.com/api/v2/events');
    });

    // -----------------------------------------------------------------------
    // Test 10: Authorization header present / absent
    // -----------------------------------------------------------------------

    test('Authorization: Bearer <token> header is present when authToken '
        'returns a token', () async {
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['authorization'];
        return http.Response('', 200);
      });
      final dest = _destination(
        client: client,
        authToken: () async => 'my-jwt-token',
      );
      final event = _makeEvent();
      final payload = await dest.transform([event]);
      await dest.send(payload);

      expect(capturedAuth, 'Bearer my-jwt-token');
    });

    test(
      'Authorization header is absent when authToken returns null',
      () async {
        var hadAuthHeader = false;
        final client = MockClient((request) async {
          hadAuthHeader = request.headers.containsKey('authorization');
          return http.Response('', 200);
        });
        final dest = _destination(client: client, authToken: () async => null);
        final event = _makeEvent();
        final payload = await dest.transform([event]);
        await dest.send(payload);

        expect(hadAuthHeader, isFalse);
      },
    );
  });
}
