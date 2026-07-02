import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// Verifies: DIARY-DEV-inbound-event-on-receipt/A — client fetcher round-trips with server
void main() {
  final fixed = DateTime.utc(2026, 5, 8, 10, 0);

  group('EnvelopeFetcher.fetchById', () {
    test('parses a 200 response into an Envelope', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          equals('https://diary.example.com/api/v1/notifications/env-1'),
        );
        expect(request.headers['authorization'], equals('Bearer token'));
        return http.Response(
          jsonEncode(<String, dynamic>{
            'notification_id': 'env-1',
            'participant_id': 'pat-1',
            'type': 'participant_status_update',
            'title': 'Account Disconnected',
            'user_visible': true,
            'payload': <String, dynamic>{'action': 'disconnect'},
            'status': 'delivered',
            'created_at': fixed.toIso8601String(),
            'delivered_at': fixed
                .add(const Duration(seconds: 1))
                .toIso8601String(),
          }),
          200,
        );
      });
      final fetcher = EnvelopeFetcher(
        httpClient: client,
        baseUrl: Uri.parse('https://diary.example.com'),
      );

      final envelope = await fetcher.fetchById(
        'env-1',
        authHeader: 'Bearer token',
      );
      expect(envelope.notificationId, equals('env-1'));
      expect(envelope.type, equals(NotificationType.participantStatusUpdate));
      expect(envelope.status, equals(EnvelopeStatus.delivered));
    });

    test('throws EnvelopeFetchException on non-200', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"not found"}', 404),
      );
      final fetcher = EnvelopeFetcher(
        httpClient: client,
        baseUrl: Uri.parse('https://diary.example.com'),
      );

      expect(
        () => fetcher.fetchById('missing', authHeader: 'Bearer token'),
        throwsA(
          isA<EnvelopeFetchException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  group('EnvelopeFetcher.fetchSince', () {
    test(
      'builds the query string with since + limit and parses items',
      () async {
        final since = DateTime.utc(2026, 5, 8, 9, 0);
        final newest = DateTime.utc(2026, 5, 8, 11, 0);

        final client = MockClient((request) async {
          expect(request.url.path, equals('/api/v1/notifications'));
          expect(
            request.url.queryParameters['since'],
            equals(since.toIso8601String()),
          );
          expect(request.url.queryParameters['limit'], equals('25'));
          return http.Response(
            jsonEncode(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                {
                  'notification_id': 'a',
                  'participant_id': 'pat-1',
                  'type': 'reminder',
                  'title': 'Yesterday Reminder',
                  'user_visible': true,
                  'payload': <String, dynamic>{},
                  'status': 'sent',
                  'created_at': fixed.toIso8601String(),
                },
                {
                  'notification_id': 'b',
                  'participant_id': 'pat-1',
                  'type': 'reminder',
                  'title': 'Yesterday Reminder',
                  'user_visible': true,
                  'payload': <String, dynamic>{},
                  'status': 'sent',
                  'created_at': newest.toIso8601String(),
                },
              ],
              'next_cursor': newest.toIso8601String(),
            }),
            200,
          );
        });
        final fetcher = EnvelopeFetcher(
          httpClient: client,
          baseUrl: Uri.parse('https://diary.example.com'),
        );

        final page = await fetcher.fetchSince(
          since,
          authHeader: 'Bearer t',
          limit: 25,
        );
        expect(page.envelopes, hasLength(2));
        expect(page.envelopes[0].notificationId, equals('a'));
        expect(page.envelopes[1].notificationId, equals('b'));
        expect(page.nextCursor, equals(newest));
      },
    );
  });
}
