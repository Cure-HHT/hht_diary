import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../_helpers/in_memory_repository.dart';

void _seedEnvelope(
  InMemoryNotificationRepository repo, {
  required String id,
  required String participantId,
  required DateTime createdAt,
}) {
  repo.envelopes[id] = Envelope(
    notificationId: id,
    participantId: participantId,
    type: NotificationType.reminder,
    title: 'Yesterday Reminder',
    payload: const <String, dynamic>{},
    status: EnvelopeStatus.sent,
    createdAt: createdAt,
  );
}

Handler _handler(
  InMemoryNotificationRepository repo, {
  String? Function(Request)? resolver,
}) {
  return envelopeSinceHandler(
    repo: repo,
    participantResolver: (req) async => resolver?.call(req) ?? 'pat-1',
  );
}

// Verifies: DIARY-DEV-inbound-event-on-receipt/A — since query returns envelopes after cursor
void main() {
  group('envelopeSinceHandler', () {
    test('returns envelopes created after `since`, sorted ascending', () async {
      final repo = InMemoryNotificationRepository();
      _seedEnvelope(
        repo,
        id: 'older',
        participantId: 'pat-1',
        createdAt: DateTime.utc(2026, 5, 8, 9, 0),
      );
      _seedEnvelope(
        repo,
        id: 'mid',
        participantId: 'pat-1',
        createdAt: DateTime.utc(2026, 5, 8, 10, 0),
      );
      _seedEnvelope(
        repo,
        id: 'newer',
        participantId: 'pat-1',
        createdAt: DateTime.utc(2026, 5, 8, 11, 0),
      );

      final since = DateTime.utc(2026, 5, 8, 9, 30).toIso8601String();
      final response = await _handler(repo).call(
        Request('GET', Uri.parse('http://x/api/v1/notifications?since=$since')),
      );

      expect(response.statusCode, equals(200));
      final json =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        items.map((e) => e['notification_id']),
        equals(<String>['mid', 'newer']),
      );
    });

    test('next_cursor is the newest createdAt in the page', () async {
      final repo = InMemoryNotificationRepository();
      final newest = DateTime.utc(2026, 5, 8, 11, 0);
      _seedEnvelope(
        repo,
        id: 'a',
        participantId: 'pat-1',
        createdAt: DateTime.utc(2026, 5, 8, 10, 0),
      );
      _seedEnvelope(repo, id: 'b', participantId: 'pat-1', createdAt: newest);

      final since = DateTime.utc(2026, 5, 8, 9, 0).toIso8601String();
      final response = await _handler(repo).call(
        Request('GET', Uri.parse('http://x/api/v1/notifications?since=$since')),
      );

      final json =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final cursor = DateTime.parse(json['next_cursor'] as String).toUtc();
      expect(cursor, equals(newest));
    });

    test('empty page echoes the request cursor in next_cursor', () async {
      final repo = InMemoryNotificationRepository();
      final since = DateTime.utc(2026, 5, 8, 12, 0);
      final response = await _handler(repo).call(
        Request(
          'GET',
          Uri.parse(
            'http://x/api/v1/notifications?since=${since.toIso8601String()}',
          ),
        ),
      );
      final json =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect((json['items'] as List).isEmpty, isTrue);
      // Mobile must be safe to advance its cursor even on an empty page.
      expect(json['next_cursor'], equals(since.toIso8601String()));
    });

    test('limit clamped at maxLimit', () async {
      final repo = InMemoryNotificationRepository();
      for (var i = 0; i < 10; i++) {
        _seedEnvelope(
          repo,
          id: 'e-$i',
          participantId: 'pat-1',
          createdAt: DateTime.utc(2026, 5, 8, 10).add(Duration(minutes: i)),
        );
      }

      final since = DateTime.utc(2026, 5, 8, 9).toIso8601String();
      final handler = envelopeSinceHandler(
        repo: repo,
        participantResolver: (_) async => 'pat-1',
        maxLimit: 3,
      );
      final response = await handler.call(
        Request(
          'GET',
          Uri.parse('http://x/api/v1/notifications?since=$since&limit=999'),
        ),
      );
      final json =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect((json['items'] as List).length, equals(3));
    });

    test('400 on missing `since`', () async {
      final repo = InMemoryNotificationRepository();
      final response = await _handler(
        repo,
      ).call(Request('GET', Uri.parse('http://x/api/v1/notifications')));
      expect(response.statusCode, equals(400));
    });

    test('400 on malformed `since`', () async {
      final repo = InMemoryNotificationRepository();
      final response = await _handler(repo).call(
        Request(
          'GET',
          Uri.parse('http://x/api/v1/notifications?since=not-a-date'),
        ),
      );
      expect(response.statusCode, equals(400));
    });

    test('401 when participantResolver returns null', () async {
      final repo = InMemoryNotificationRepository();
      final since = DateTime.utc(2026, 5, 8).toIso8601String();
      final handler = envelopeSinceHandler(
        repo: repo,
        participantResolver: (_) async => null,
      );
      final response = await handler.call(
        Request('GET', Uri.parse('http://x/api/v1/notifications?since=$since')),
      );
      expect(response.statusCode, equals(401));
    });
  });
}
