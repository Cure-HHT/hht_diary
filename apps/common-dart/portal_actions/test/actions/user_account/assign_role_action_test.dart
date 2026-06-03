// Verifies: DIARY-PRD-user-account-edit/E
// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = AssignRoleAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares assign_role permission + required idempotency', () {
    expect(action.name, 'ACT-USR-007');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-USR-007']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('emits one role_assigned for the (user, role, scope) tuple', () async {
    final input = action.parseInput(<String, Object?>{
      'userId': 'sc-9',
      'role': 'StudyCoordinator',
      'scope': const BoundScope(class_: 'site', value: 'site-1').toJson(),
    });
    final result = await action.execute(input, ctx);
    expect(result.events, hasLength(1));
    final e = result.events.single;
    expect(e.eventType, 'role_assigned');
    expect(e.aggregateType, 'user_role_scope');
    expect(
      e.aggregateId,
      computeRoleAssignmentAggregateId(
        userId: 'sc-9',
        role: 'StudyCoordinator',
        scope: const BoundScope(class_: 'site', value: 'site-1'),
      ),
    );
    expect(e.data['user_id'], 'sc-9');
    expect(e.data['role'], 'StudyCoordinator');
    expect(
      e.data['scope'],
      const BoundScope(class_: 'site', value: 'site-1').toJson(),
    );
  });

  test('rejects missing/blank userId or role', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'role': 'X',
        'scope': const TotalWildcardScope().toJson(),
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => action.validate(
        action.parseInput(<String, Object?>{
          'userId': '  ',
          'role': 'X',
          'scope': const TotalWildcardScope().toJson(),
        }),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
