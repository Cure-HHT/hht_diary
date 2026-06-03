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

  ResendActivationEmailAction makeAction() => ResendActivationEmailAction(
    flowTokenMinter: SerialFlowTokenMinter(start: 1),
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: declares resend_activation permission + required idempotency',
    () {
      final action = makeAction();
      expect(action.name, 'ACT-USR-006');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-006']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: parseInput requires userId and activationExpiresAt',
    () {
      final action = makeAction();
      expect(
        () => action.parseInput(<String, Object?>{'userId': 'u1'}),
        throwsFormatException,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank userId', () {
    final action = makeAction();
    expect(
      () => action.validate(
        ResendActivationEmailInput(
          userId: '',
          activationExpiresAt: '2026-12-01T00:00:00Z',
        ),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits user_activation_code_issued with reissue=true and flowToken',
    () async {
      final action = ResendActivationEmailAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 9),
      );
      final result = await action.execute(
        ResendActivationEmailInput(
          userId: 'u1',
          activationExpiresAt: '2026-12-01T00:00:00Z',
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_activation_code_issued',
      ]);
      expect(result.events[0].data['reissue'], true);
      expect(result.events[0].data['issued_by'], 'admin-1');
      expect(result.events[0].data['expires_at'], '2026-12-01T00:00:00Z');
      expect(result.events[0].flowToken, isNotNull);
    },
  );
}
