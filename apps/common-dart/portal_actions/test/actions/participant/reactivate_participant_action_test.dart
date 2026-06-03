// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-006)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ReactivateParticipantAction(
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
    expect(action.name, 'ACT-PAT-006');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-006']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires all five fields, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'participantId': 'p1',
        'reason': 'rejoined',
        'linkingCode': 'LC789',
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      'reason': ' rejoined ',
      'linkingCode': ' LC789 ',
      'expiresAt': ' 2026-06-01T00:00:00Z ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
    expect(input.reason, 'rejoined');
    expect(input.linkingCode, 'LC789');
    expect(input.expiresAt, '2026-06-01T00:00:00Z');
  });

  test('validate rejects blank reason', () {
    expect(
      () => action.validate(
        const ReactivateParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          reason: '',
          linkingCode: 'LC789',
          expiresAt: '2026-06-01T00:00:00Z',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank expiresAt', () {
    expect(
      () => action.validate(
        const ReactivateParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          reason: 'rejoined',
          linkingCode: 'LC789',
          expiresAt: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-006']!;
    final scope = action.scopeFor(
      perm,
      const ReactivateParticipantInput(
        siteId: 's1',
        participantId: 'p1',
        reason: 'rejoined',
        linkingCode: 'LC789',
        expiresAt: '2026-06-01T00:00:00Z',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits [participant_reactivated, participant_linking_code_issued] '
    'both with equal non-null flowToken; reactivated has reason',
    () async {
      final a = ReactivateParticipantAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 9),
      );
      final r = await a.execute(
        const ReactivateParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          reason: 'rejoined',
          linkingCode: 'LC789',
          expiresAt: '2026-06-01T00:00:00Z',
        ),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), [
        'participant_reactivated',
        'participant_linking_code_issued',
      ]);
      expect(r.events[0].flowToken, matches(RegExp(r'^PAT\d{6}$')));
      expect(r.events[0].flowToken, r.events[1].flowToken);
      expect(r.events[0].flowToken, 'PAT000009');
      expect(r.events[0].data['reason'], 'rejoined');
      expect(r.events[0].data['by'], 'sc-1');
      expect(r.events[1].data['purpose'], 'reconnect');
      expect(r.events[1].data['linking_code'], 'LC789');
    },
  );
}
