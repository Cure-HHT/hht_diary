// Verifies: DIARY-PRD-user-account-site-assignment/D
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = RevokeSiteAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares revoke_site permission', () {
    expect(action.name, 'ACT-USR-011');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-USR-011']),
    );
  });

  test(
    'emits one role_unassigned with BoundScope(site) under the role',
    () async {
      final input = action.parseInput(<String, Object?>{
        'userId': 'sc-9',
        'role': 'StudyCoordinator',
        'site': 'site-3',
      });
      final result = await action.execute(input, ctx);
      expect(result.events, hasLength(1));
      final e = result.events.single;
      expect(e.eventType, 'role_unassigned');
      expect(
        e.data['scope'],
        const BoundScope(class_: 'site', value: 'site-3').toJson(),
      );
    },
  );
}
