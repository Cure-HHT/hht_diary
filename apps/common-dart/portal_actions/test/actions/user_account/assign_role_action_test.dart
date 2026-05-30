// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = AssignRoleAction();
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
    'DIARY-PRD-action-inventory/A: declares assign_role permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-007');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-007']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput rejects non-list roles', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'userId': 'u1',
        'roles': 'Admin',
        'previousRoles': <String>[],
      }),
      throwsFormatException,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: parseInput rejects non-list previousRoles',
    () {
      expect(
        () => action.parseInput(<String, Object?>{
          'userId': 'u1',
          'roles': <String>['Admin'],
          'previousRoles': 'old-role',
        }),
        throwsFormatException,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: role widening emits only user_roles_changed',
    () async {
      final result = await action.execute(
        AssignRoleInput(
          userId: 'u1',
          roles: <String>['A', 'B'],
          previousRoles: <String>['A'],
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_roles_changed',
      ]);
      expect(result.events[0].data['before'], <String>['A']);
      expect(result.events[0].data['after'], <String>['A', 'B']);
      expect(result.events[0].data['changed_by'], 'admin-1');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: same-set assignment emits only user_roles_changed (no revoke)',
    () async {
      final result = await action.execute(
        AssignRoleInput(
          userId: 'u1',
          roles: <String>['A', 'B'],
          previousRoles: <String>['A', 'B'],
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_roles_changed',
      ]);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: role narrowing emits user_roles_changed + user_sessions_revoked',
    () async {
      final result = await action.execute(
        AssignRoleInput(
          userId: 'u1',
          roles: <String>['A'],
          previousRoles: <String>['A', 'B'],
        ),
        ctx,
      );
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_roles_changed',
        'user_sessions_revoked',
      ]);
      expect(result.events[0].data['before'], <String>['A', 'B']);
      expect(result.events[1].data['reason_kind'], 'authz_narrowed');
      expect(result.events[1].data['by'], 'admin-1');
    },
  );
}
