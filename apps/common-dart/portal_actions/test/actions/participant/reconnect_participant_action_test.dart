// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-004)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = ReconnectParticipantAction(
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
    expect(action.name, 'ACT-PAT-004');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-004']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires all four fields, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'participantId': 'p1',
        'linkingCode': 'LC456',
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      'linkingCode': ' LC456 ',
      'expiresAt': ' 2026-06-01T00:00:00Z ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
    expect(input.linkingCode, 'LC456');
    expect(input.expiresAt, '2026-06-01T00:00:00Z');
  });

  test('validate rejects blank linkingCode', () {
    expect(
      () => action.validate(
        const ReconnectParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          linkingCode: '',
          expiresAt: '2026-06-01T00:00:00Z',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank expiresAt', () {
    expect(
      () => action.validate(
        const ReconnectParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          linkingCode: 'LC456',
          expiresAt: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-004']!;
    final scope = action.scopeFor(
      perm,
      const ReconnectParticipantInput(
        siteId: 's1',
        participantId: 'p1',
        linkingCode: 'LC456',
        expiresAt: '2026-06-01T00:00:00Z',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits [participant_linking_code_issued, participant_reconnected] '
    'both with equal non-null flowToken; first has purpose reconnect',
    () async {
      final a = ReconnectParticipantAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 5),
      );
      final r = await a.execute(
        const ReconnectParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          linkingCode: 'LC456',
          expiresAt: '2026-06-01T00:00:00Z',
        ),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), [
        'participant_linking_code_issued',
        'participant_reconnected',
      ]);
      expect(r.events[0].flowToken, isNotNull);
      expect(r.events[0].flowToken, r.events[1].flowToken);
      expect(r.events[0].flowToken, 'FT000005');
      expect(r.events[0].data['purpose'], 'reconnect');
      expect(r.events[0].data['linking_code'], 'LC456');
      expect(r.events[1].data['by'], 'sc-1');
    },
  );
}
