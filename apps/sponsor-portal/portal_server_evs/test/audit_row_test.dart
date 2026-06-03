import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:test/test.dart';

StoredEvent _event(Initiator initiator) => StoredEvent.synthetic(
      eventId: 'evt-1',
      aggregateId: 'u@x.com',
      aggregateType: 'portal_user',
      entryType: 'user_created',
      eventType: 'finalized',
      sequenceNumber: 7,
      data: const {'email': 'u@x.com'},
      metadata: const {'change_reason': 'r'},
      initiator: initiator,
      clientTimestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      eventHash: 'hash-1',
    );

void main() {
  group('auditRowJson', () {
    test('maps a user-initiated event to an audit row', () {
      final row = auditRowJson(_event(const UserInitiator('admin-1')));

      expect(row['entry_type'], 'user_created');
      expect(row['event_type'], 'finalized');
      expect(row['aggregate_type'], 'portal_user');
      expect(row['aggregate_id'], 'u@x.com');
      expect(row['initiator'], {'kind': 'user', 'label': 'admin-1'});
      expect(row['change_reason'], 'r');
      expect(row['data'], isA<Map>());
      expect(row['timestamp'], isA<String>());
      expect(row['timestamp'], '2026-01-02T03:04:05.000Z');
      expect(row['event_id'], 'evt-1');
      expect(row['sequence'], 7);
    });

    test('maps an automation-initiated event', () {
      final row = auditRowJson(
        _event(const AutomationInitiator(service: 'edc_sync')),
      );
      expect(row['initiator'], {'kind': 'automation', 'label': 'edc_sync'});
    });

    test('maps an anonymous-initiated event', () {
      final row = auditRowJson(
        _event(const AnonymousInitiator(ipAddress: null)),
      );
      final initiator = row['initiator']! as Map<String, Object?>;
      expect(initiator['kind'], 'anonymous');
    });
  });

  group('auditAccessAllowed', () {
    test('allows when the audit-view permission is present', () {
      expect(
        auditAccessAllowed(['portal.audit.view', 'portal.user.create']),
        isTrue,
      );
    });

    test('denies when the audit-view permission is absent', () {
      expect(auditAccessAllowed(['portal.user.create']), isFalse);
    });

    test('denies on an empty permission set', () {
      expect(auditAccessAllowed([]), isFalse);
    });
  });
}
