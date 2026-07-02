import 'package:comms/comms.dart';
import 'package:test/test.dart';

// Verifies: DIARY-DEV-inbound-event-on-receipt/A — Envelope wire format round-trips every field
void main() {
  group('NotificationType', () {
    test('wire values match the spec vocabulary', () {
      expect(
        NotificationType.questionnaireUpdate.wire,
        equals('questionnaire_update'),
      );
      expect(
        NotificationType.participantStatusUpdate.wire,
        equals('participant_status_update'),
      );
      expect(NotificationType.reminder.wire, equals('reminder'));
    });

    test('fromWire roundtrips every value', () {
      for (final type in NotificationType.values) {
        expect(NotificationType.fromWire(type.wire), equals(type));
      }
    });

    test('fromWire throws on unknown value', () {
      expect(
        () => NotificationType.fromWire('unknown_value'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EnvelopeStatus', () {
    test('fromWire roundtrips every value', () {
      for (final status in EnvelopeStatus.values) {
        expect(EnvelopeStatus.fromWire(status.wire), equals(status));
      }
    });
  });

  group('Envelope.toJson / fromJson', () {
    final fixed = DateTime.utc(2026, 5, 8, 10, 30);

    test('round-trips a fully populated envelope', () {
      final original = Envelope(
        notificationId: 'env-001',
        participantId: 'pat-123',
        type: NotificationType.questionnaireUpdate,
        title: 'Questionnaire Finalized',
        body: 'Your questionnaire is locked.',
        userVisible: true,
        payload: <String, dynamic>{
          'action': 'lock_task',
          'questionnaire_instance_id': 'inst-9',
        },
        status: EnvelopeStatus.delivered,
        messageId: 'projects/cure-hht-admin/messages/0:abc',
        error: null,
        createdAt: fixed,
        sentAt: fixed.add(const Duration(seconds: 1)),
        deliveredAt: fixed.add(const Duration(seconds: 2)),
      );

      final json = original.toJson();
      final reparsed = Envelope.fromJson(json);

      expect(reparsed.notificationId, equals(original.notificationId));
      expect(reparsed.participantId, equals(original.participantId));
      expect(reparsed.type, equals(original.type));
      expect(reparsed.title, equals(original.title));
      expect(reparsed.body, equals(original.body));
      expect(reparsed.userVisible, equals(original.userVisible));
      expect(reparsed.payload, equals(original.payload));
      expect(reparsed.status, equals(original.status));
      expect(reparsed.messageId, equals(original.messageId));
      expect(reparsed.createdAt.toUtc(), equals(original.createdAt));
      expect(reparsed.sentAt!.toUtc(), equals(original.sentAt));
      expect(reparsed.deliveredAt!.toUtc(), equals(original.deliveredAt));
    });

    test('omits null fields from JSON output', () {
      final pending = Envelope(
        notificationId: 'env-002',
        participantId: 'pat-123',
        type: NotificationType.participantStatusUpdate,
        title: 'Account Disconnected',
        payload: const <String, dynamic>{'action': 'disconnect'},
        status: EnvelopeStatus.pending,
        createdAt: fixed,
      );

      final json = pending.toJson();

      expect(json.containsKey('body'), isFalse);
      expect(json.containsKey('message_id'), isFalse);
      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('sent_at'), isFalse);
      expect(json.containsKey('delivered_at'), isFalse);
    });

    test('user_visible defaults to true when omitted from JSON', () {
      final json = <String, dynamic>{
        'notification_id': 'env-003',
        'participant_id': 'pat-123',
        'type': 'reminder',
        'title': 'Yesterday Reminder',
        'payload': <String, dynamic>{},
        'status': 'pending',
        'created_at': fixed.toIso8601String(),
      };
      final envelope = Envelope.fromJson(json);
      expect(envelope.userVisible, isTrue);
    });
  });

  group('Envelope.copyWith', () {
    test('updates only the named fields', () {
      final original = Envelope(
        notificationId: 'env-1',
        participantId: 'pat-1',
        type: NotificationType.reminder,
        title: 'Yesterday Reminder',
        payload: const <String, dynamic>{},
        status: EnvelopeStatus.pending,
        createdAt: DateTime.utc(2026, 5, 8),
      );

      final updated = original.copyWith(
        status: EnvelopeStatus.sent,
        messageId: 'msg-99',
      );

      expect(updated.status, equals(EnvelopeStatus.sent));
      expect(updated.messageId, equals('msg-99'));
      expect(updated.title, equals(original.title));
      expect(updated.payload, equals(original.payload));
      expect(updated.notificationId, equals(original.notificationId));
    });
  });
}
