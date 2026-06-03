// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = UnlockUserAccountAction();
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
    'DIARY-PRD-action-inventory/A: declares unlock permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-005');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-005']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: parseInput requires userId and reason',
    () {
      expect(
        () => action.parseInput(<String, Object?>{'userId': 'u1'}),
        throwsFormatException,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank reason', () {
    expect(
      () => action.validate(
        const UnlockUserAccountInput(userId: 'u1', reason: ''),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits user_account_unlocked with reason and by',
    () async {
      final result = await action.execute(
        const UnlockUserAccountInput(userId: 'u1', reason: 'false positive'),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_account_unlocked',
      ]);
      expect(result.events[0].aggregateType, 'portal_user');
      expect(result.events[0].aggregateId, 'u1');
      expect(result.events[0].data['reason'], 'false positive');
      expect(result.events[0].data['by'], 'admin-1');
    },
  );
}
