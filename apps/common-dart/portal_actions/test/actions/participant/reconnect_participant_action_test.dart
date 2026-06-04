// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-004)
// Verifies: DIARY-DEV-linking-code-lifecycle/A  (server-side code + full contract)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ReconnectParticipantAction(
    flowTokenMinter: SerialFlowTokenMinter(),
    linkingPrefix: 'CA',
  );
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'sc-1',
      roles: {'SiteCoordinator'},
      activeRole: 'SiteCoordinator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares permission + required idempotency', () {
    expect(action.name, 'ACT-PAT-004');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-004']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires siteId + participantId, trims them, '
      'ignores extra keys', () {
    expect(
      () => action.parseInput(<String, Object?>{'siteId': 's1'}),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      'linkingCode': 'LCxxx',
      'expiresAt': '2026-06-01T00:00:00Z',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
  });

  test('validate rejects blank siteId', () {
    expect(
      () => action.validate(
        const ReconnectParticipantInput(siteId: '', participantId: 'p1'),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank participantId', () {
    expect(
      () => action.validate(
        const ReconnectParticipantInput(siteId: 's1', participantId: ''),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-004']!;
    final scope = action.scopeFor(
      perm,
      const ReconnectParticipantInput(siteId: 's1', participantId: 'p1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits [participant_linking_code_issued, participant_reconnected] '
    'both with equal non-null flowToken; first carries the full contract',
    () async {
      final a = ReconnectParticipantAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 5),
        linkingPrefix: 'CA',
      );
      final r = await a.execute(
        const ReconnectParticipantInput(siteId: 's1', participantId: 'p1'),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.result.linkingCode, isNotEmpty);
      expect(r.result.linkingCode.startsWith('CA'), isTrue);
      expect(r.result.expiresAt, '2026-06-02T00:00:00.000Z');

      expect(r.events.map((e) => e.entryType), [
        'participant_linking_code_issued',
        'participant_reconnected',
      ]);
      expect(r.events[0].flowToken, matches(RegExp(r'^PAT\d{6}$')));
      expect(r.events[0].flowToken, r.events[1].flowToken);
      expect(r.events[0].flowToken, 'PAT000005');

      final issued = r.events[0];
      expect(issued.data['linking_code'], r.result.linkingCode);
      expect(issued.data['participant_id'], 'p1');
      expect(issued.data['site_id'], 's1');
      expect(issued.data['generated_by'], 'sc-1');
      expect(issued.data['purpose'], 'reconnect');
      expect(issued.data['status'], 'active');
      expect(issued.data['mobile_linking_status'], 'linking_in_progress');
      expect(issued.data['expires_at'], '2026-06-02T00:00:00.000Z');

      expect(r.events[1].data['by'], 'sc-1');
    },
  );
}
