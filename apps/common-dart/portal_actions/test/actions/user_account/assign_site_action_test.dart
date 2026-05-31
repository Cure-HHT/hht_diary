// Verifies: DIARY-PRD-user-account-site-assignment/D
// Verifies: DIARY-PRD-user-account-edit/E
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = AssignSiteAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares assign_site permission + required idempotency', () {
    expect(action.name, 'ACT-USR-008');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-USR-008']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test(
    'emits one role_assigned binding the site as a BoundScope under the role',
    () async {
      final input = action.parseInput(<String, Object?>{
        'userId': 'sc-9',
        'role': 'StudyCoordinator',
        'site': 'site-3',
      });
      final result = await action.execute(input, ctx);
      expect(result.events, hasLength(1));
      final e = result.events.single;
      expect(e.eventType, 'role_assigned');
      expect(e.aggregateType, 'user_role_scope');
      expect(
        e.data['scope'],
        const BoundScope(class_: 'site', value: 'site-3').toJson(),
      );
      expect(
        e.aggregateId,
        computeRoleAssignmentAggregateId(
          userId: 'sc-9',
          role: 'StudyCoordinator',
          scope: const BoundScope(class_: 'site', value: 'site-3'),
        ),
      );
    },
  );

  test('rejects missing site/role/userId', () {
    expect(
      () => action.parseInput(<String, Object?>{'userId': 'u', 'role': 'r'}),
      throwsA(isA<FormatException>()),
    );
  });
}
