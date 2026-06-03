// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-PAT-001)
// Verifies: DIARY-DEV-linking-code-lifecycle/A  (server-side code + full contract)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = LinkParticipantAction(linkingPrefix: 'CA');
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

  test('parseInput requires siteId + participantId, trims them, '
      'ignores extra keys', () {
    expect(
      () => action.parseInput(<String, Object?>{'siteId': 's1'}),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'participantId': ' p1 ',
      // extra wire keys from the legacy UI are ignored:
      'linkingCode': 'LCxxx',
      'expiresAt': '2026-06-01T00:00:00Z',
    });
    expect(input.siteId, 's1');
    expect(input.participantId, 'p1');
  });

  test('validate rejects blank siteId', () {
    expect(
      () => action.validate(
        const LinkParticipantInput(siteId: '', participantId: 'p1'),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank participantId', () {
    expect(
      () => action.validate(
        const LinkParticipantInput(siteId: 's1', participantId: ''),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-PAT-001']!;
    final scope = action.scopeFor(
      perm,
      const LinkParticipantInput(siteId: 's1', participantId: 'p1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test('execute generates the code server-side and emits the full '
      'participant_linking_code_issued contract, no flowToken', () async {
    final r = await action.execute(
      const LinkParticipantInput(siteId: 's1', participantId: 'p1'),
      ctx,
    );
    // result carries the generated code + expiry
    expect(r.result.participantId, 'p1');
    expect(r.result.linkingCode, isNotEmpty);
    expect(r.result.linkingCode.startsWith('CA'), isTrue);
    expect(r.result.expiresAt, '2026-06-02T00:00:00.000Z');

    expect(r.events.map((e) => e.entryType), [
      'participant_linking_code_issued',
    ]);
    final e = r.events.single;
    expect(e.aggregateType, 'participant');
    expect(e.aggregateId, 'p1');
    expect(e.flowToken, isNull);
    // emitted code == result code
    expect(e.data['linking_code'], r.result.linkingCode);
    expect(e.data['participant_id'], 'p1');
    expect(e.data['site_id'], 's1');
    expect(e.data['generated_by'], 'sc-1');
    expect(e.data['purpose'], 'link');
    expect(e.data['status'], 'active');
    expect(e.data['mobile_linking_status'], 'linking_in_progress');
    // expiry deterministic from ctx.requestStartedAt + 72h
    expect(e.data['expires_at'], '2026-06-02T00:00:00.000Z');
  });
}
