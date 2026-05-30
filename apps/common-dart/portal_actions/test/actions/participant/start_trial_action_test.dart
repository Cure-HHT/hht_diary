// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-002)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = StartTrialAction(flowTokenMinter: SerialFlowTokenMinter());
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
    expect(action.name, 'ACT-PAT-002');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-002']),
    );
    expect(action.idempotency, Idempotency.required);
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

  test('validate rejects blank-after-trim', () {
    expect(
      () => action.validate(
        const StartTrialInput(siteId: '', participantId: 'p1'),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-002']!;
    final scope = action.scopeFor(
      perm,
      const StartTrialInput(siteId: 's1', participantId: 'p1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits participant_trial_started with flowToken on participant aggregate',
    () async {
      final a = StartTrialAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 7),
      );
      final r = await a.execute(
        const StartTrialInput(siteId: 's1', participantId: 'p1'),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), ['participant_trial_started']);
      final e = r.events.single;
      expect(e.aggregateType, 'participant');
      expect(e.aggregateId, 'p1');
      expect(e.flowToken, 'PAT000007');
      expect(e.data['by'], 'sc-1');
      expect(e.data['started_at'], '2026-05-30T00:00:00.000Z');
    },
  );
}
