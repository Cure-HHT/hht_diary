import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../_helpers/in_memory_repository.dart';

/// Mounts the handler under a router so `request.params` resolves the
/// `<id>` segment — production wiring uses the same pattern.
Router _routerFor(
  InMemoryNotificationRepository repo, {
  required String? Function(Request) resolver,
}) {
  return Router()..get(
    '/api/v1/notifications/<id>',
    envelopeFetchHandler(
      repo: repo,
      participantResolver: (req) async => resolver(req),
    ),
  );
}

Envelope _seed(
  InMemoryNotificationRepository repo, {
  required String participantId,
}) {
  final envelope = Envelope(
    notificationId: 'env-1',
    participantId: participantId,
    type: NotificationType.participantStatusUpdate,
    title: 'Account Disconnected',
    payload: const <String, dynamic>{'action': 'disconnect'},
    status: EnvelopeStatus.sent,
    createdAt: DateTime.utc(2026, 5, 8, 10, 0),
    sentAt: DateTime.utc(2026, 5, 8, 10, 0, 1),
  );
  repo.envelopes[envelope.notificationId] = envelope;
  return envelope;
}

// Verifies: DIARY-DEV-inbound-event-on-receipt/A — fetch by id stamps delivered on first read
void main() {
  group('envelopeFetchHandler', () {
    test('200 returns the envelope JSON', () async {
      final repo = InMemoryNotificationRepository();
      _seed(repo, participantId: 'pat-1');
      final router = _routerFor(repo, resolver: (_) => 'pat-1');

      final response = await router.call(
        Request('GET', Uri.parse('http://x/api/v1/notifications/env-1')),
      );

      expect(response.statusCode, equals(200));
      final json =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(json['notification_id'], equals('env-1'));
      expect(json['type'], equals('participant_status_update'));
    });

    test('401 when participantResolver returns null', () async {
      final repo = InMemoryNotificationRepository();
      _seed(repo, participantId: 'pat-1');
      final router = _routerFor(repo, resolver: (_) => null);

      final response = await router.call(
        Request('GET', Uri.parse('http://x/api/v1/notifications/env-1')),
      );

      expect(response.statusCode, equals(401));
    });

    test('404 when envelope does not exist for this participant', () async {
      final repo = InMemoryNotificationRepository();
      _seed(repo, participantId: 'pat-OTHER');
      // Caller is pat-1 but the envelope belongs to pat-OTHER.
      final router = _routerFor(repo, resolver: (_) => 'pat-1');

      final response = await router.call(
        Request('GET', Uri.parse('http://x/api/v1/notifications/env-1')),
      );

      expect(response.statusCode, equals(404));
    });

    test(
      'first read transitions status to delivered (idempotent on second)',
      () async {
        final repo = InMemoryNotificationRepository();
        _seed(repo, participantId: 'pat-1');
        final router = _routerFor(repo, resolver: (_) => 'pat-1');

        await router.call(
          Request('GET', Uri.parse('http://x/api/v1/notifications/env-1')),
        );
        final firstStored = repo.envelopes['env-1']!;
        expect(firstStored.status, equals(EnvelopeStatus.delivered));
        final firstDelivered = firstStored.deliveredAt;
        expect(firstDelivered, isNotNull);

        // Second call must not bump deliveredAt — idempotent.
        await router.call(
          Request('GET', Uri.parse('http://x/api/v1/notifications/env-1')),
        );
        final secondStored = repo.envelopes['env-1']!;
        expect(secondStored.deliveredAt, equals(firstDelivered));
      },
    );
  });
}
