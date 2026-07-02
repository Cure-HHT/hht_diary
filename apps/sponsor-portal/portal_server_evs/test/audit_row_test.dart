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
      expect(
          adminActionName('user_created', 'finalized'), 'Create User Account');
      expect(adminActionName('user_profile_changed', 'x'), 'Edit User Account');
      expect(
          adminActionName('user_deactivated', 'x'), 'Deactivate User Account');
      expect(
          adminActionName('user_reactivated', 'x'), 'Reactivate User Account');
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

    test('auditEventIsAdminAction: user-initiated admin actions only', () {
      StoredEvent ev(String entryType, Initiator initiator) =>
          StoredEvent.synthetic(
            eventId: 'e',
            aggregateId: 'a',
            aggregateType: 'portal_user',
            entryType: entryType,
            eventType: 'x',
            sequenceNumber: 1,
            data: const {},
            metadata: const {},
            initiator: initiator,
            clientTimestamp: DateTime.utc(2026),
            eventHash: 'h',
          );
      const admin = UserInitiator('admin-1');
      // Admin-initiated admin action: included.
      expect(auditEventIsAdminAction(ev('user_reactivated', admin)), isTrue);
      // Non-admin-action entry type: excluded regardless of initiator.
      expect(auditEventIsAdminAction(ev('session_started', admin)), isFalse);
      // Admin-action entry type but automation-initiated (e.g. the activation
      // code an account-create flow auto-issues): excluded — the Admin view
      // shows the Administrator's own actions only, not "Automation" rows.
      expect(
        auditEventIsAdminAction(
          ev('user_activation_code_issued',
              const AutomationInitiator(service: 'sys')),
        ),
        isFalse,
      );
      // Anonymous-initiated: excluded.
      expect(
        auditEventIsAdminAction(
          ev('user_reactivated', const AnonymousInitiator(ipAddress: null)),
        ),
        isFalse,
      );
    });
  });

  group('auditRowParticipantId / participant_id stamping', () {
    StoredEvent ev({
      required String aggregateType,
      required String aggregateId,
      Map<String, Object?> data = const {},
      Initiator initiator = const UserInitiator('sc@x.com'),
    }) =>
        StoredEvent.synthetic(
          eventId: 'e',
          aggregateId: aggregateId,
          aggregateType: aggregateType,
          entryType: 'x',
          eventType: 'x',
          sequenceNumber: 1,
          data: data,
          metadata: const {},
          initiator: initiator,
          clientTimestamp: DateTime.utc(2026),
          eventHash: 'h',
        );

    // Verifies: DIARY-GUI-audit-log-study-coordinator/A
    test('participant aggregate: participant id IS the aggregate id', () {
      final e = ev(aggregateType: 'participant', aggregateId: 'P-42');
      expect(auditRowParticipantId(e), 'P-42');
      expect(auditRowJson(e)['participant_id'], 'P-42');
    });

    // Verifies: DIARY-GUI-audit-log-study-coordinator/A
    test('questionnaire_instance: prefers the event participant_id payload',
        () {
      final e = ev(
        aggregateType: 'questionnaire_instance',
        aggregateId: 'inst-1',
        data: const {'participant_id': 'P-7'},
      );
      expect(auditRowParticipantId(e), 'P-7');
      expect(auditRowJson(e)['participant_id'], 'P-7');
    });

    // Verifies: DIARY-GUI-audit-log-study-coordinator/A
    test('questionnaire_instance: falls back to the instance->participant join',
        () {
      // call-back / finalize / unlock events key on the instance id and carry
      // no participant_id in their payload — resolved via the join map.
      final e = ev(aggregateType: 'questionnaire_instance', aggregateId: 'i-9');
      expect(auditRowParticipantId(e), isNull);
      expect(
        auditRowParticipantId(e, const {'i-9': 'P-9'}),
        'P-9',
      );
      expect(
        auditRowJson(e,
            participantByInstance: const {'i-9': 'P-9'})['participant_id'],
        'P-9',
      );
    });

    test('other aggregates carry no participant_id', () {
      final e = ev(aggregateType: 'portal_user', aggregateId: 'u@x.com');
      expect(auditRowParticipantId(e), isNull);
      expect(auditRowJson(e).containsKey('participant_id'), isFalse);
    });
  });

  group('auditEventIsOwnActivity (view=mine scope)', () {
    StoredEvent ev(String aggregateType, Initiator initiator) =>
        StoredEvent.synthetic(
          eventId: 'e',
          aggregateId: 'P-1',
          aggregateType: aggregateType,
          entryType: 'x',
          eventType: 'x',
          sequenceNumber: 1,
          data: const {},
          metadata: const {},
          initiator: initiator,
          clientTimestamp: DateTime.utc(2026),
          eventHash: 'h',
        );
    const sc = UserInitiator('sc@x.com');

    // Verifies: DIARY-DEV-audit-log-read/A — the Study Coordinator's own
    //   participant/questionnaire actions, not peers' or automation's.
    test('includes the coordinator\'s own participant/questionnaire actions',
        () {
      expect(
          auditEventIsOwnActivity(ev('participant', sc), 'sc@x.com'), isTrue);
      expect(
        auditEventIsOwnActivity(ev('questionnaire_instance', sc), 'sc@x.com'),
        isTrue,
      );
    });

    test('excludes a peer coordinator\'s actions (separation of duties)', () {
      expect(
        auditEventIsOwnActivity(
            ev('participant', const UserInitiator('peer@x.com')), 'sc@x.com'),
        isFalse,
      );
    });

    test('excludes automation-initiated events', () {
      expect(
        auditEventIsOwnActivity(
            ev('participant', const AutomationInitiator(service: 'edc')),
            'sc@x.com'),
        isFalse,
      );
    });

    test('excludes aggregates outside the coordinator\'s scope', () {
      expect(
        auditEventIsOwnActivity(ev('portal_user', sc), 'sc@x.com'),
        isFalse,
      );
    });
  });

  group('auditEventMatchesParticipant (participant search)', () {
    StoredEvent ev(String aggregateId) => StoredEvent.synthetic(
          eventId: 'e',
          aggregateId: aggregateId,
          aggregateType: 'participant',
          entryType: 'x',
          eventType: 'x',
          sequenceNumber: 1,
          data: const {},
          metadata: const {},
          initiator: const UserInitiator('sc@x.com'),
          clientTimestamp: DateTime.utc(2026),
          eventHash: 'h',
        );

    // Verifies: DIARY-GUI-audit-log-study-coordinator/B
    test('case-insensitive substring match on participant id', () {
      expect(
          auditEventMatchesParticipant(ev('P-100'), 'p-10', const {}), isTrue);
      expect(auditEventMatchesParticipant(ev('P-100'), 'P-999', const {}),
          isFalse);
    });

    test('events with no participant never match', () {
      final e = StoredEvent.synthetic(
        eventId: 'e',
        aggregateId: 'u@x.com',
        aggregateType: 'portal_user',
        entryType: 'x',
        eventType: 'x',
        sequenceNumber: 1,
        data: const {},
        metadata: const {},
        initiator: const UserInitiator('sc@x.com'),
        clientTimestamp: DateTime.utc(2026),
        eventHash: 'h',
      );
      expect(auditEventMatchesParticipant(e, 'anything', const {}), isFalse);
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
