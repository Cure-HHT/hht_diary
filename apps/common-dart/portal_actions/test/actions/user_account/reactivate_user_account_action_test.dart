// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  ReactivateUserAccountAction makeAction() => ReactivateUserAccountAction(
    flowTokenMinter: SerialFlowTokenMinter(start: 1),
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: declares reactivate permission + required idempotency',
    () {
      final action = makeAction();
      expect(action.name, 'ACT-USR-004');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-004']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: parseInput requires userId, reason, activationExpiresAt',
    () {
      final action = makeAction();
      expect(
        () => action.parseInput(<String, Object?>{'userId': 'u1'}),
        throwsFormatException,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank reason', () {
    final action = makeAction();
    expect(
      () => action.validate(
        ReactivateUserAccountInput(
          userId: 'u1',
          reason: '',
          activationExpiresAt: '2026-12-01T00:00:00Z',
        ),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits user_reactivated + user_activation_code_issued with shared flowToken',
    () async {
      final action = ReactivateUserAccountAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 3),
      );
      final result = await action.execute(
        ReactivateUserAccountInput(
          userId: 'u1',
          reason: 'returned to study',
          activationExpiresAt: '2026-12-01T00:00:00Z',
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_reactivated',
        'user_activation_code_issued',
      ]);
      final ft0 = result.events[0].flowToken;
      final ft1 = result.events[1].flowToken;
      expect(ft0, isNotNull);
      expect(ft0, ft1);
      expect(result.events[0].data['reason'], 'returned to study');
      expect(result.events[0].data['by'], 'admin-1');
      expect(result.events[1].data['reissue'], false);
      expect(result.events[1].data['expires_at'], '2026-12-01T00:00:00Z');
      expect(result.events[1].data['issued_by'], 'admin-1');
    },
  );
}
