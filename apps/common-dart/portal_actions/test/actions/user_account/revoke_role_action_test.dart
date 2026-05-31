// Verifies: DIARY-PRD-user-account-edit/E
// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = RevokeRoleAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares revoke_role permission', () {
    expect(action.name, 'ACT-USR-010');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-USR-010']),
    );
  });

  test(
    'emits one role_unassigned for the same (user, role, scope) aggregate id',
    () async {
      const scope = BoundScope(class_: 'site', value: 'site-1');
      final input = action.parseInput(<String, Object?>{
        'userId': 'sc-9',
        'role': 'StudyCoordinator',
        'scope': scope.toJson(),
      });
      final result = await action.execute(input, ctx);
      expect(result.events, hasLength(1));
      final e = result.events.single;
      expect(e.eventType, 'role_unassigned');
      expect(e.aggregateType, 'user_role_scope');
      expect(
        e.aggregateId,
        computeRoleAssignmentAggregateId(
          userId: 'sc-9',
          role: 'StudyCoordinator',
          scope: scope,
        ),
      );
    },
  );
}
