// VERIFIES REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling — diary-side read repo

import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:diary_functions/diary_functions.dart';
import 'package:test/test.dart';

class _CapturedCall {
  _CapturedCall({required this.query, required this.parameters});
  final String query;
  final Map<String, dynamic>? parameters;
}

void main() {
  late List<_CapturedCall> calls;
  late List<List<dynamic>> Function(String query)? rowsFor;

  setUp(() {
    calls = [];
    rowsFor = null;
    databaseQueryOverride = (query, {parameters, table}) async {
      calls.add(_CapturedCall(query: query, parameters: parameters));
      return rowsFor?.call(query) ?? <List<dynamic>>[];
    };
  });

  tearDown(() {
    databaseQueryOverride = null;
  });

  group('DiaryNotificationRepository — write methods reject', () {
    test('insertPending throws UnsupportedError', () {
      final repo = DiaryNotificationRepository();
      expect(
        () => repo.insertPending(
          Envelope(
            notificationId: 'env-1',
            participantId: 'pat-1',
            type: NotificationType.participantStatusUpdate,
            title: 'X',
            payload: const <String, dynamic>{},
            status: EnvelopeStatus.pending,
            createdAt: DateTime.utc(2026, 5, 8),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('markSent throws UnsupportedError', () {
      final repo = DiaryNotificationRepository();
      expect(
        () => repo.markSent('id-1', 'msg-1'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('markFailed throws UnsupportedError', () {
      final repo = DiaryNotificationRepository();
      expect(
        () => repo.markFailed('id-1', 'oops'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('DiaryNotificationRepository.findById', () {
    test('returns null when no row matches', () async {
      rowsFor = (_) => <List<dynamic>>[];
      final repo = DiaryNotificationRepository();

      final result = await repo.findById('id-1', participantId: '840-001');
      expect(result, isNull);
    });

    test('parses a row into an Envelope with all fields', () async {
      final created = DateTime.utc(2026, 5, 8, 10, 30);
      final sentAt = DateTime.utc(2026, 5, 8, 10, 30, 5);
      rowsFor = (_) => [
        <dynamic>[
          '11111111-1111-1111-1111-111111111111',
          '840-001',
          'participant_status_update',
          'Account Disconnected',
          'You have been disconnected.',
          true,
          jsonEncode({'action': 'disconnect'}),
          'sent',
          'projects/cure-hht-admin/messages/0:abc',
          null,
          created,
          sentAt,
          null,
        ],
      ];
      final repo = DiaryNotificationRepository();

      final result = await repo.findById(
        '11111111-1111-1111-1111-111111111111',
        participantId: '840-001',
      );

      expect(result, isNotNull);
      expect(result!.type, equals(NotificationType.participantStatusUpdate));
      expect(result.status, equals(EnvelopeStatus.sent));
      expect(result.payload, equals(<String, dynamic>{'action': 'disconnect'}));
      expect(result.userVisible, isTrue);
      expect(result.createdAt, equals(created));
      expect(result.sentAt, equals(sentAt));
    });

    test('query includes WHERE participant_id (defense in depth)', () async {
      final repo = DiaryNotificationRepository();
      await repo.findById('id-1', participantId: '840-001');

      expect(calls.single.query, contains('WHERE notification_id = @id'));
      expect(
        calls.single.query,
        contains('AND participant_id = @participantId'),
      );
      expect(calls.single.parameters!['participantId'], equals('840-001'));
    });
  });

  group('DiaryNotificationRepository.findSince', () {
    test('orders ascending by created_at, applies limit', () async {
      rowsFor = (_) => <List<dynamic>>[];
      final repo = DiaryNotificationRepository();
      final since = DateTime.utc(2026, 5, 8, 9, 0);

      await repo.findSince(since, participantId: '840-001', limit: 25);

      expect(calls.single.query, contains('ORDER BY created_at ASC'));
      expect(calls.single.query, contains('LIMIT @limit'));
      final params = calls.single.parameters!;
      expect(params['since'], equals(since));
      expect(params['limit'], equals(25));
      expect(params['participantId'], equals('840-001'));
    });
  });

  group('DiaryNotificationRepository.markDeliveredIfNull', () {
    test('no-op for empty id list', () async {
      final repo = DiaryNotificationRepository();
      await repo.markDeliveredIfNull(<String>[], participantId: '840-001');
      expect(calls, isEmpty);
    });

    test(
      'updates only rows where delivered_at IS NULL — idempotent on duplicate fetch',
      () async {
        final repo = DiaryNotificationRepository();
        await repo.markDeliveredIfNull(<String>[
          'id-1',
          'id-2',
        ], participantId: '840-001');

        expect(calls.single.query, contains('UPDATE notifications'));
        expect(calls.single.query, contains("SET status = 'delivered'"));
        expect(calls.single.query, contains('delivered_at = now()'));
        expect(
          calls.single.query,
          contains('AND delivered_at IS NULL'),
          reason:
              'idempotent — duplicate fetch from another device must not bump',
        );
        expect(
          calls.single.query,
          contains('AND participant_id = @participantId'),
        );
        expect(calls.single.parameters!['ids'], equals(['id-1', 'id-2']));
      },
    );
  });
}
