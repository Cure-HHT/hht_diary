// Shelf handler factory for `GET /api/v1/notifications?since=<iso8601>&limit=<n>`.
// Returns the participant's envelopes created strictly after `since`,
// paginated by `limit` (server-enforced ceiling). Mobile uses this on
// app resume / cold start to reconcile state without trusting any FCM
// payload (envelope pattern).

import 'dart:convert';

import 'package:comms/src/notifications/envelope.dart';
import 'package:comms/src/notifications/repository.dart';
import 'package:shelf/shelf.dart';

/// Builds a Shelf [Handler] that serves envelopes since a cursor.
///
/// Query params:
///   * `since` — required ISO-8601 timestamp; the cursor the mobile
///     persists locally. Server returns rows with `created_at > since`.
///   * `limit` — optional, default 50, server-clamped to a maximum so
///     a misbehaving client cannot pull the entire history in one call.
// Implements: DIARY-DEV-inbound-event-on-receipt/A — cursor-based since query for receipt reconciliation
Handler envelopeSinceHandler({
  required NotificationRepository repo,
  required Future<String?> Function(Request) participantResolver,
  int defaultLimit = 50,
  int maxLimit = 200,
}) {
  return (Request request) async {
    final participantId = await participantResolver(request);
    if (participantId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: const {'content-type': 'application/json'},
      );
    }

    final sinceParam = request.url.queryParameters['since'];
    if (sinceParam == null || sinceParam.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': "Missing 'since' query parameter"}),
        headers: const {'content-type': 'application/json'},
      );
    }
    final DateTime since;
    try {
      since = DateTime.parse(sinceParam).toUtc();
    } on FormatException {
      return Response.badRequest(
        body: jsonEncode({'error': "Invalid 'since' — expected ISO-8601"}),
        headers: const {'content-type': 'application/json'},
      );
    }

    final limitParam = request.url.queryParameters['limit'];
    var limit = defaultLimit;
    if (limitParam != null) {
      final parsed = int.tryParse(limitParam);
      if (parsed == null || parsed <= 0) {
        return Response.badRequest(
          body: jsonEncode({
            'error': "Invalid 'limit' — expected positive int",
          }),
          headers: const {'content-type': 'application/json'},
        );
      }
      limit = parsed > maxLimit ? maxLimit : parsed;
    }

    final envelopes = await repo.findSince(
      since,
      participantId: participantId,
      limit: limit,
    );

    return Response.ok(
      jsonEncode(<String, dynamic>{
        'items': envelopes.map((Envelope e) => e.toJson()).toList(),
        // Caller-side cursor advancement: the mobile persists the
        // newest created_at it has seen and uses it as `since` next
        // poll. Returning it here saves the client from scanning the
        // list on its end.
        'next_cursor': envelopes.isEmpty
            ? since.toIso8601String()
            : envelopes
                  .map((Envelope e) => e.createdAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toUtc()
                  .toIso8601String(),
      }),
      headers: const {'content-type': 'application/json'},
    );
  };
}
