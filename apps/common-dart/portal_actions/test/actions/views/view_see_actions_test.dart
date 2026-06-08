// Verifies: DIARY-PRD-action-inventory/A  (ACT-SEE-001..004)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ACT-SEE-001 ViewQuestionnaireStatusAction is a site-scoped gate',
    () async {
      final a = ViewQuestionnaireStatusAction();
      expect(a.name, 'ACT-SEE-001');
      expect(a.permissions, contains(portalPermissionsByActId['ACT-SEE-001']));
      expect(a.idempotency, Idempotency.none);
      final input = a.parseInput(<String, Object?>{'siteId': ' s1 '});
      expect(input.siteId, 's1');
      final scope = a.scopeFor(portalPermissionsByActId['ACT-SEE-001']!, input);
      expect((scope! as BoundScope).value, 's1');
      final r = await a.execute(input, _ctx());
      expect(r.events, isEmpty);
    },
  );

  test('ACT-SEE-002 ViewRaveSyncStatusAction is an unscoped gate', () async {
    final a = ViewRaveSyncStatusAction();
    expect(a.name, 'ACT-SEE-002');
    expect(a.permissions, contains(portalPermissionsByActId['ACT-SEE-002']));
    expect(a.idempotency, Idempotency.none);
    final r = await a.execute(a.parseInput(const <String, Object?>{}), _ctx());
    expect(r.events, isEmpty);
  });

  test('ACT-SEE-003 ViewUserAccountsAction is an unscoped gate', () async {
    final a = ViewUserAccountsAction();
    expect(a.name, 'ACT-SEE-003');
    expect(a.permissions, contains(portalPermissionsByActId['ACT-SEE-003']));
    expect(a.idempotency, Idempotency.none);
    final r = await a.execute(a.parseInput(const <String, Object?>{}), _ctx());
    expect(r.events, isEmpty);
  });

  test('ACT-SEE-004 ViewDiaryEntriesAction is an unscoped gate', () async {
    final a = ViewDiaryEntriesAction();
    expect(a.name, 'ACT-SEE-004');
    expect(a.permissions, contains(portalPermissionsByActId['ACT-SEE-004']));
    expect(a.idempotency, Idempotency.none);
    final r = await a.execute(a.parseInput(const <String, Object?>{}), _ctx());
    expect(r.events, isEmpty);
  });
}

ActionContext _ctx() => ActionContext(
  principal: Principal.user(
    userId: 'sc-1',
    roles: const {'StudyCoordinator'},
    activeRole: 'StudyCoordinator',
  ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2026, 6, 8),
);
