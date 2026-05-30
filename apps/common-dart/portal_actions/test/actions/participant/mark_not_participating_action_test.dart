// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-005)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = MarkNotParticipatingAction(
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
    expect(action.name, 'ACT-PAT-005');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-005']),
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
      'reason': ' withdrew ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
    expect(input.reason, 'withdrew');
  });

  test('validate rejects blank reason', () {
    expect(
      () => action.validate(
        const MarkNotParticipatingInput(
          siteId: 's1',
          participantId: 'p1',
          reason: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-005']!;
    final scope = action.scopeFor(
      perm,
      const MarkNotParticipatingInput(
        siteId: 's1',
        participantId: 'p1',
        reason: 'withdrew',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits participant_marked_not_participating with reason and flowToken',
    () async {
      final a = MarkNotParticipatingAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 2),
      );
      final r = await a.execute(
        const MarkNotParticipatingInput(
          siteId: 's1',
          participantId: 'p1',
          reason: 'withdrew',
        ),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), [
        'participant_marked_not_participating',
      ]);
      final e = r.events.single;
      expect(e.aggregateType, 'participant');
      expect(e.aggregateId, 'p1');
      expect(e.flowToken, isNotNull);
      expect(e.flowToken, 'FT000002');
      expect(e.data['reason'], 'withdrew');
      expect(e.data['by'], 'sc-1');
    },
  );
}
