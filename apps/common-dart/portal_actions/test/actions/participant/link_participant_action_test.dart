// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-001)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = LinkParticipantAction();
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
    expect(action.name, 'ACT-PAT-001');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-PAT-001']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires all four fields, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'participantId': 'p1',
        'linkingCode': 'LC123',
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      'linkingCode': ' LC123 ',
      'expiresAt': ' 2026-06-01T00:00:00Z ',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
    expect(input.linkingCode, 'LC123');
    expect(input.expiresAt, '2026-06-01T00:00:00Z');
  });

  test('validate rejects blank linkingCode', () {
    expect(
      () => action.validate(
        const LinkParticipantInput(
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
        const LinkParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          linkingCode: 'LC123',
          expiresAt: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-001']!;
    final scope = action.scopeFor(
      perm,
      const LinkParticipantInput(
        siteId: 's1',
        participantId: 'p1',
        linkingCode: 'LC123',
        expiresAt: '2026-06-01T00:00:00Z',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits participant_linking_code_issued with purpose link, no flowToken',
    () async {
      final r = await action.execute(
        const LinkParticipantInput(
          siteId: 's1',
          participantId: 'p1',
          linkingCode: 'LC123',
          expiresAt: '2026-06-01T00:00:00Z',
        ),
        ctx,
      );
      expect(r.result.participantId, 'p1');
      expect(r.events.map((e) => e.entryType), [
        'participant_linking_code_issued',
      ]);
      final e = r.events.single;
      expect(e.aggregateType, 'participant');
      expect(e.aggregateId, 'p1');
      expect(e.flowToken, isNull);
      expect(e.data['linking_code'], 'LC123');
      expect(e.data['purpose'], 'link');
      expect(e.data['generated_by'], 'sc-1');
      expect(e.data['expires_at'], '2026-06-01T00:00:00Z');
    },
  );
}
