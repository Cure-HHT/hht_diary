// VERIFIES REQUIREMENTS:
//   REQ-d00167: dispatch + status transitions persist correctly
//   REQ-d00168: PHI checks happen at the OutboxWriter layer; the repo
//               accepts already-validated envelopes
//   REQ-d00169: findSince ordering + bounded result set; markDelivered
//               idempotent semantics
//
// Unit tests for [PgNotificationRepository] using
// [databaseQueryOverride]. Verifies the SQL shape, parameter binding,
// and UserContext used by each method without spinning up a real
// Postgres. RLS policy enforcement is integration-test territory and
// is out of scope here — the docker-postgres test (P1B.1 follow-up)
// covers it.

import 'dart:convert';

import 'package:comms/comms.dart';
import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/notifications/pg_notification_repository.dart';
import 'package:test/test.dart';

/// Capture-and-replay handler for [databaseQueryOverride]. Records
/// every (query, parameters, context) so tests can assert on each
/// step of a multi-statement repo method.
class _CapturedCall {
  _CapturedCall({
    required this.query,
    required this.parameters,
    required this.context,
  });
  final String query;
  final Map<String, dynamic>? parameters;
  final UserContext context;
}

void main() {
  late List<_CapturedCall> calls;
  late List<List<dynamic>> Function(String query)? rowsFor;

  Envelope buildEnvelope({
    String id = '11111111-1111-1111-1111-111111111111',
    String patientId = '840-001',
    NotificationType type = NotificationType.patientStatusUpdate,
    String title = 'Account Disconnected',
    String? body = 'Your study account has been disconnected.',
    bool userVisible = true,
    Map<String, dynamic>? payload,
    EnvelopeStatus status = EnvelopeStatus.pending,
    DateTime? createdAt,
  }) {
    return Envelope(
      notificationId: id,
      patientId: patientId,
      type: type,
      title: title,
      body: body,
      userVisible: userVisible,
      payload: payload ?? <String, dynamic>{'action': 'disconnect'},
      status: status,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 8, 10, 30),
    );
  }

  setUp(() {
    calls = [];
    rowsFor = null;
    databaseQueryOverride = (query, {parameters, required context}) async {
      calls.add(
        _CapturedCall(query: query, parameters: parameters, context: context),
      );
      return rowsFor?.call(query) ?? <List<dynamic>>[];
    };
  });

  tearDown(() {
    databaseQueryOverride = null;
  });

  group('PgNotificationRepository.insertPending', () {
    test('runs INSERT under service context with all envelope fields', () async {
      final repo = PgNotificationRepository();
      final envelope = buildEnvelope();

      await repo.insertPending(envelope);

      expect(calls, hasLength(1));
      expect(calls[0].query, contains('INSERT INTO notifications'));
      expect(
        calls[0].query,
        contains('ON CONFLICT (notification_id) DO NOTHING'),
        reason:
            'idempotent on retry — writer can re-attempt without duplicate row',
      );
      expect(calls[0].context, equals(UserContext.service));

      final params = calls[0].parameters!;
      expect(params['notificationId'], equals(envelope.notificationId));
      expect(params['patientId'], equals(envelope.patientId));
      expect(params['notificationType'], equals('patient_status_update'));
      expect(params['title'], equals(envelope.title));
      expect(params['body'], equals(envelope.body));
      expect(params['userVisible'], isTrue);
      expect(
        jsonDecode(params['payload'] as String),
        equals(<String, dynamic>{'action': 'disconnect'}),
      );
      expect(params['status'], equals('pending'));
    });

    test('serialises payload as JSON, not as a Map literal', () async {
      final repo = PgNotificationRepository();
      await repo.insertPending(
        buildEnvelope(
          payload: <String, dynamic>{
            'action': 'lock_task',
            'questionnaire_instance_id': 'inst-1',
          },
        ),
      );
      // Postgres expects JSONB-as-text for ::jsonb cast — must be
      // a JSON string, not a Dart Map<>.toString().
      expect(calls[0].parameters!['payload'], isA<String>());
      final decoded =
          jsonDecode(calls[0].parameters!['payload'] as String)
              as Map<String, dynamic>;
      expect(decoded['action'], equals('lock_task'));
    });
  });

  group('PgNotificationRepository.findById', () {
    test('returns null when no row matches', () async {
      rowsFor = (_) => <List<dynamic>>[];
      final repo = PgNotificationRepository();

      final result = await repo.findById(
        '00000000-0000-0000-0000-000000000000',
        patientId: '840-001',
      );

      expect(result, isNull);
      expect(calls.single.context.role, equals('patient'));
      expect(calls.single.context.patientId, equals('840-001'));
    });

    test('parses a row into an Envelope with all fields', () async {
      final created = DateTime.utc(2026, 5, 8, 10, 30);
      final sentAt = DateTime.utc(2026, 5, 8, 10, 30, 5);
      rowsFor = (_) => [
        <dynamic>[
          '11111111-1111-1111-1111-111111111111',
          '840-001',
          'patient_status_update',
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
      final repo = PgNotificationRepository();

      final result = await repo.findById(
        '11111111-1111-1111-1111-111111111111',
        patientId: '840-001',
      );

      expect(result, isNotNull);
      expect(
        result!.notificationId,
        equals('11111111-1111-1111-1111-111111111111'),
      );
      expect(result.type, equals(NotificationType.patientStatusUpdate));
      expect(result.status, equals(EnvelopeStatus.sent));
      expect(result.payload, equals(<String, dynamic>{'action': 'disconnect'}));
      expect(result.userVisible, isTrue);
      expect(
        result.messageId,
        equals('projects/cure-hht-admin/messages/0:abc'),
      );
      expect(result.createdAt, equals(created));
      expect(result.sentAt, equals(sentAt));
      expect(result.deliveredAt, isNull);
    });

    test('uses patient context, includes WHERE patient_id', () async {
      final repo = PgNotificationRepository();
      await repo.findById('id-1', patientId: '840-001');

      expect(calls.single.context.role, equals('patient'));
      expect(calls.single.context.patientId, equals('840-001'));
      expect(calls.single.query, contains('WHERE notification_id = @id'));
      expect(calls.single.query, contains('AND patient_id = @patientId'));
    });
  });

  group('PgNotificationRepository.findSince', () {
    test('orders ascending by created_at, applies limit', () async {
      rowsFor = (_) => <List<dynamic>>[];
      final repo = PgNotificationRepository();
      final since = DateTime.utc(2026, 5, 8, 9, 0);

      await repo.findSince(since, patientId: '840-001', limit: 25);

      expect(calls.single.query, contains('ORDER BY created_at ASC'));
      expect(calls.single.query, contains('LIMIT @limit'));
      final params = calls.single.parameters!;
      expect(params['since'], equals(since));
      expect(params['limit'], equals(25));
      expect(params['patientId'], equals('840-001'));
      expect(calls.single.context.role, equals('patient'));
    });
  });

  group('PgNotificationRepository.markSent', () {
    test(
      'updates status + message_id + sent_at under service context',
      () async {
        final repo = PgNotificationRepository();
        await repo.markSent('id-1', 'msg-99');

        expect(calls.single.query, contains('UPDATE notifications'));
        expect(calls.single.query, contains("SET status = 'sent'"));
        expect(calls.single.query, contains('message_id = @messageId'));
        expect(
          calls.single.query,
          contains('COALESCE(sent_at, now())'),
          reason: 'sent_at is set only on first transition to sent',
        );
        expect(calls.single.query, contains("WHERE notification_id = @id"));
        expect(
          calls.single.query,
          contains("AND status = 'pending'"),
          reason: 'avoid clobbering an already-delivered envelope',
        );
        expect(calls.single.context, equals(UserContext.service));
        expect(calls.single.parameters!['id'], equals('id-1'));
        expect(calls.single.parameters!['messageId'], equals('msg-99'));
      },
    );
  });

  group('PgNotificationRepository.markFailed', () {
    test('captures error string under service context', () async {
      final repo = PgNotificationRepository();
      await repo.markFailed('id-1', 'UNREGISTERED');

      expect(calls.single.query, contains("SET status = 'failed'"));
      expect(calls.single.query, contains('last_error = @error'));
      expect(calls.single.context, equals(UserContext.service));
      expect(calls.single.parameters!['error'], equals('UNREGISTERED'));
    });
  });

  group('PgNotificationRepository.markDeliveredIfNull', () {
    test('no-op for empty id list', () async {
      final repo = PgNotificationRepository();
      await repo.markDeliveredIfNull(<String>[], patientId: '840-001');
      expect(calls, isEmpty);
    });

    test(
      'updates only rows where delivered_at IS NULL — patient context',
      () async {
        final repo = PgNotificationRepository();
        await repo.markDeliveredIfNull(<String>[
          'id-1',
          'id-2',
        ], patientId: '840-001');

        expect(calls.single.query, contains('UPDATE notifications'));
        expect(calls.single.query, contains("SET status = 'delivered'"));
        expect(calls.single.query, contains('delivered_at = now()'));
        expect(
          calls.single.query,
          contains('AND delivered_at IS NULL'),
          reason: 'idempotent — duplicate fetch must not bump the timestamp',
        );
        expect(calls.single.query, contains('AND patient_id = @patientId'));
        expect(calls.single.context.role, equals('patient'));
        expect(calls.single.context.patientId, equals('840-001'));
        expect(calls.single.parameters!['ids'], equals(['id-1', 'id-2']));
      },
    );
  });
}
