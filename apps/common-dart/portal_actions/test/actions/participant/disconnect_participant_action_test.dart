// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-003)
// Verifies: DIARY-DEV-relink-device-gate/B — disconnect emits mobile_linking_status
//   = disconnected, which lets the relink gate allow a later re-link.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = DisconnectParticipantAction(
    flowTokenMinter: SerialFlowTokenMinter(),
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
    expect(action.name, 'ACT-PAT-003');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-003']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires siteId + participantId + reason, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'participantId': 'p1',
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      'reason': ' device lost ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
    expect(input.reason, 'device lost');
  });

  test('validate rejects blank reason', () {
    expect(
      () => action.validate(
        const DisconnectParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          reason: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-003']!;
    final scope = action.scopeFor(
      perm,
      const DisconnectParticipantInput(
        siteId: 's1',
        participantId: 'p1',
        reason: 'device lost',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits participant_disconnected with reason and flowToken',
    () async {
      final a = DisconnectParticipantAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 3),
      );
      final r = await a.execute(
        const DisconnectParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          reason: 'device lost',
        ),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), ['participant_disconnected']);
      final e = r.events.single;
      expect(e.aggregateType, 'participant');
      expect(e.aggregateId, 'p1');
      expect(e.flowToken, matches(RegExp(r'^PAT\d{6}$')));
      expect(e.flowToken, 'PAT000003');
      expect(e.data['reason'], 'device lost');
      expect(e.data['by'], 'sc-1');
      expect(e.data['mobile_linking_status'], 'disconnected');
    },
  );
}
