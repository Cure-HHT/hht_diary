// Pure-Dart HTTP client for the envelope endpoints. Used by the mobile
// diary app on cold start / resume to pull envelopes since the last
// cursor, and by the FCM dispatcher to fetch a single envelope by id
// when an FCM wake-up arrives.
//
// No Flutter SDK dependency — caller injects the [http.Client]
// (`http.Client()` for tests, `http.Client()` from the consuming app
// in production) so this works in unit tests, isolates, and Flutter
// build modes alike.

import 'dart:convert';

import 'package:comms/src/notifications/envelope.dart';
import 'package:http/http.dart' as http;

/// Thrown by [EnvelopeFetcher] when the server returns a non-success
/// status. The body is captured so a polling loop can decide whether
/// to retry (5xx) or escalate (4xx).
class EnvelopeFetchException implements Exception {
  EnvelopeFetchException({required this.statusCode, required this.body});
  final int statusCode;
  final String body;

  @override
  String toString() =>
      'EnvelopeFetchException: statusCode=$statusCode body=$body';
}

// Implements: DIARY-DEV-inbound-event-on-receipt/A — client fetches envelopes by id / since cursor
class EnvelopeFetcher {
  EnvelopeFetcher({required this.httpClient, required this.baseUrl});

  /// Caller-owned HTTP client. The fetcher does not close it.
  final http.Client httpClient;

  /// Server base (e.g. `Uri.parse('https://diary.example.com')`).
  /// Endpoint paths are appended via `replace(path: ...)` so any
  /// trailing slash on [baseUrl] does not double-up.
  final Uri baseUrl;

  /// `GET /api/v1/notifications/<id>`. Returns the envelope. The
  /// server-side handler also stamps `delivered_at` on first read.
  Future<Envelope> fetchById(String id, {required String authHeader}) async {
    final uri = baseUrl.replace(path: '/api/v1/notifications/$id');
    final response = await httpClient.get(
      uri,
      headers: {'authorization': authHeader},
    );
    if (response.statusCode != 200) {
      throw EnvelopeFetchException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Envelope.fromJson(json);
  }

  /// `GET /api/v1/notifications?since=<iso8601>&limit=<n>`. Returns
  /// the envelopes plus the server-emitted `next_cursor` the caller
  /// should persist for the next poll.
  Future<EnvelopeSincePage> fetchSince(
    DateTime since, {
    required String authHeader,
    int limit = 50,
  }) async {
    final uri = baseUrl.replace(
      path: '/api/v1/notifications',
      queryParameters: <String, String>{
        'since': since.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    );
    final response = await httpClient.get(
      uri,
      headers: {'authorization': authHeader},
    );
    if (response.statusCode != 200) {
      throw EnvelopeFetchException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    return EnvelopeSincePage(
      envelopes: items
          .map(
            (dynamic item) => Envelope.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: DateTime.parse(json['next_cursor'] as String).toUtc(),
    );
  }
}

/// A page of envelopes plus the cursor for the next poll.
class EnvelopeSincePage {
  const EnvelopeSincePage({required this.envelopes, required this.nextCursor});
  final List<Envelope> envelopes;
  final DateTime nextCursor;
}
