import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = DeactivateUserAccountAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 29),
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: declares deactivate permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-003');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-003']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/B
  test(
    'DIARY-PRD-action-inventory/B: parseInput requires userId and reason',
    () {
      expect(
        () => action.parseInput(<String, Object?>{'userId': 'u1'}),
        throwsFormatException,
      );
      final input = action.parseInput(<String, Object?>{
        'userId': 'u1',
        'reason': 'left study',
      });
      expect(input.userId, 'u1');
      expect(input.reason, 'left study');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/B
  test('DIARY-PRD-action-inventory/B: validate rejects empty reason', () {
    expect(
      () => action.validate(
        const DeactivateUserAccountInput(userId: 'u1', reason: '   '),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-DEV-shared-events-catalog/A
  test(
    'DIARY-DEV-shared-events-catalog/A: execute emits deactivated + sessions_revoked',
    () async {
      final result = await action.execute(
        const DeactivateUserAccountInput(userId: 'u1', reason: 'left study'),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_deactivated',
        'user_sessions_revoked',
      ]);
      for (final e in result.events) {
        expect(e.aggregateType, 'portal_user');
        expect(e.aggregateId, 'u1');
      }
      expect(result.events.first.data['reason'], 'left study');
      expect(result.events.first.data['deactivated_by'], 'admin-1');
      expect(result.events[1].data['reason_kind'], 'deactivated');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/B
  test(
    'DIARY-PRD-action-inventory/B: parseInput normalizes surrounding whitespace to canonical values',
    () {
      final input = action.parseInput(<String, Object?>{
        'userId': '  u1  ',
        'reason': '  left study  ',
      });
      expect(input.userId, 'u1');
      expect(input.reason, 'left study');
    },
  );
}
