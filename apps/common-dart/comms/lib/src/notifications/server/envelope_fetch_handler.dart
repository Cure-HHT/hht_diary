// Shelf handler factory for `GET /api/v1/notifications/{id}`. Returns
// the envelope as JSON and idempotently transitions its state to
// `delivered` on the first successful read so the server has a
// confirmed-receipt audit point.
//
// The factory's `participantResolver` argument is the app-side bridge from
// the request's auth header to a participant row id — each sponsor's auth
// model differs (Identity Platform claims vs. JWT subject vs. session
// cookie), so resolution lives in the consuming app.

import 'dart:convert';

import 'package:comms/src/notifications/repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds a Shelf [Handler] that serves a single envelope by id.
///
/// Mount as: `router.get('/api/v1/notifications/<id>', envelopeFetchHandler(...))`
// Implements: DIARY-DEV-inbound-event-on-receipt/A — fetch by id marks delivered on first read
Handler envelopeFetchHandler({
  required NotificationRepository repo,
  required Future<String?> Function(Request) participantResolver,
}) {
  return (Request request) async {
    final participantId = await participantResolver(request);
    if (participantId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: const {'content-type': 'application/json'},
      );
    }

    final id = request.params['id'];
    if (id == null || id.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing notification id'}),
        headers: const {'content-type': 'application/json'},
      );
    }

    final envelope = await repo.findById(id, participantId: participantId);
    if (envelope == null) {
      return Response.notFound(
        jsonEncode({'error': 'Envelope not found'}),
        headers: const {'content-type': 'application/json'},
      );
    }

    // Idempotent delivered-stamp on first read. The repository
    // implementation MUST short-circuit when delivered_at is already
    // non-null so a duplicate fetch from mobile does not re-stamp.
    if (envelope.deliveredAt == null) {
      await repo.markDeliveredIfNull(<String>[
        id,
      ], participantId: participantId);
    }

    return Response.ok(
      jsonEncode(envelope.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  };
}
