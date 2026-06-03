// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-007)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ViewParticipantAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'sc-1',
      roles: {'SiteCoordinator'},
      activeRole: 'SiteCoordinator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares permission + none idempotency', () {
    expect(action.name, 'ACT-PAT-007');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-007']),
    );
    expect(action.idempotency, Idempotency.none);
  });

  test('parseInput requires siteId + participantId, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{'siteId': 's1'}),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
  });

  test('validate rejects blank participantId', () {
    expect(
      () => action.validate(
        const ViewParticipantInput(siteId: 's1', participantId: ''),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-007']!;
    final scope = action.scopeFor(
      perm,
      const ViewParticipantInput(siteId: 's1', participantId: 'p1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test('execute returns empty events and correct participantId', () async {
    final r = await action.execute(
      const ViewParticipantInput(siteId: 's1', participantId: 'p1'),
      ctx,
    );
    expect(r.events, isEmpty);
    expect(r.result.participantId, 'p1');
  });
}
