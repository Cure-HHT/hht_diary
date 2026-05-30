// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = DeletePendingUserAction();
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
    'DIARY-PRD-action-inventory/A: declares delete_pending permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-009');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-009']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput requires userId', () {
    expect(() => action.parseInput(<String, Object?>{}), throwsFormatException);
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank userId', () {
    expect(
      () => action.validate(const DeletePendingUserInput(userId: '   ')),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits user_deleted with deleted_by',
    () async {
      final result = await action.execute(
        const DeletePendingUserInput(userId: 'u1'),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), ['user_deleted']);
      expect(result.events[0].aggregateType, 'portal_user');
      expect(result.events[0].aggregateId, 'u1');
      expect(result.events[0].data['deleted_by'], 'admin-1');
    },
  );
}
