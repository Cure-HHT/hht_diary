// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = AssignSiteAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: declares assign_site permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-008');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-008']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput rejects non-list sites', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'userId': 'u1',
        'sites': 'site-1',
        'previousSites': <String>[],
      }),
      throwsFormatException,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: parseInput rejects non-list previousSites',
    () {
      expect(
        () => action.parseInput(<String, Object?>{
          'userId': 'u1',
          'sites': <String>['site-1'],
          'previousSites': 'old-site',
        }),
        throwsFormatException,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: site widening emits only user_sites_changed',
    () async {
      final result = await action.execute(
        AssignSiteInput(
          userId: 'u1',
          sites: <String>['site-1', 'site-2'],
          previousSites: <String>['site-1'],
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_sites_changed',
      ]);
      expect(result.events[0].data['before'], <String>['site-1']);
      expect(result.events[0].data['after'], <String>['site-1', 'site-2']);
      expect(result.events[0].data['changed_by'], 'admin-1');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: same-set assignment emits only user_sites_changed (no revoke)',
    () async {
      final result = await action.execute(
        AssignSiteInput(
          userId: 'u1',
          sites: <String>['A', 'B'],
          previousSites: <String>['A', 'B'],
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_sites_changed',
      ]);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: site narrowing emits user_sites_changed + user_sessions_revoked',
    () async {
      final result = await action.execute(
        AssignSiteInput(
          userId: 'u1',
          sites: <String>['site-1'],
          previousSites: <String>['site-1', 'site-2'],
        ),
        ctx,
      );
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_sites_changed',
        'user_sessions_revoked',
      ]);
      expect(result.events[0].data['before'], <String>['site-1', 'site-2']);
      expect(result.events[1].data['reason_kind'], 'authz_narrowed');
      expect(result.events[1].data['by'], 'admin-1');
    },
  );
}
