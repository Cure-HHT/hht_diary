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
      // Verifies: DIARY-GUI-audit-log-common/F — the Action-Inventory name.
      expect(row['action_name'], 'Create User Account');
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

    // Verifies: DIARY-GUI-audit-log-common/A — display names resolved from the
    //   nameByEmail map populate the actor (initiator.name) and the affected
    //   account (target_name); an absent entry leaves names off.
    test('resolves actor + target display names from nameByEmail', () {
      final row = auditRowJson(
        _event(const UserInitiator('admin-1')),
        nameByEmail: const {
          'admin-1': 'Elvira Koliadina',
          'u@x.com': 'Mike Lewis',
        },
      );
      expect(row['initiator'],
          {'kind': 'user', 'label': 'admin-1', 'name': 'Elvira Koliadina'});
      expect(row['target_name'], 'Mike Lewis');
    });

    test('omits names when nameByEmail has no entry', () {
      final row = auditRowJson(_event(const UserInitiator('admin-1')));
      expect((row['initiator']! as Map).containsKey('name'), isFalse);
      expect(row.containsKey('target_name'), isFalse);
    });
  });

  group('adminActionName / auditEventIsAdminAction', () {
    // Verifies: DIARY-GUI-audit-log-common/F + DIARY-DEV-audit-log-read/A
    test('maps Administrator action entry types to Action-Inventory names', () {
      expect(adminActionName('user_created', 'finalized'), 'Create User Account');
      expect(adminActionName('user_profile_changed', 'x'), 'Edit User Account');
      expect(adminActionName('user_deactivated', 'x'), 'Deactivate User Account');
      expect(adminActionName('user_reactivated', 'x'), 'Reactivate User Account');
      expect(adminActionName('user_activation_code_issued', 'x'),
          'Resend Activation Email');
      expect(adminActionName('user_role_scope', 'role_assigned'),
          'Assign Role or Site to User Account');
    });

    test('returns null for system/automation events (excluded from admin log)',
        () {
      for (final et in const [
        'session_started',
        'session_terminated',
        'user_activated',
        'user_sessions_revoked',
        'edc_sync_succeeded',
      ]) {
        expect(adminActionName(et, 'x'), isNull, reason: et);
      }
    });

    test('auditEventIsAdminAction tracks adminActionName nullability', () {
      StoredEvent ev(String entryType) => StoredEvent.synthetic(
            eventId: 'e',
            aggregateId: 'a',
            aggregateType: 'portal_user',
            entryType: entryType,
            eventType: 'x',
            sequenceNumber: 1,
            data: const {},
            metadata: const {},
            initiator: const UserInitiator('admin-1'),
            clientTimestamp: DateTime.utc(2026),
            eventHash: 'h',
          );
      expect(auditEventIsAdminAction(ev('user_reactivated')), isTrue);
      expect(auditEventIsAdminAction(ev('session_started')), isFalse);
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
