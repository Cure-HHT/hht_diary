// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = EditUserAccountAction();
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
    'DIARY-PRD-action-inventory/A: declares edit permission + required idempotency',
    () {
      expect(action.name, 'ACT-USR-002');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-002']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput requires userId', () {
    expect(
      () => action.parseInput(<String, Object?>{'name': 'Alice'}),
      throwsFormatException,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: validate rejects no-change input (name same as previous, no email)',
    () {
      expect(
        () => action.validate(
          EditUserAccountInput(
            userId: 'u1',
            name: 'Alice',
            previousName: 'Alice',
            newEmail: null,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: validate rejects whitespace-only newEmail with no name change',
    () {
      expect(
        () => action.validate(
          EditUserAccountInput(
            userId: 'u1',
            name: 'Alice',
            previousName: 'Alice',
            newEmail: '   ',
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits only user_profile_changed on name-only change',
    () async {
      final result = await action.execute(
        EditUserAccountInput(
          userId: 'u1',
          name: 'Alice B',
          previousName: 'Alice',
          newEmail: null,
        ),
        ctx,
      );
      expect(result.result.userId, 'u1');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_profile_changed',
      ]);
      expect(result.events[0].data['before'], 'Alice');
      expect(result.events[0].data['after'], 'Alice B');
      expect(result.events[0].data['changed_by'], 'admin-1');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits only user_email_change_requested on email-only change',
    () async {
      final result = await action.execute(
        EditUserAccountInput(
          userId: 'u1',
          name: null,
          previousName: null,
          newEmail: 'new@example.com',
        ),
        ctx,
      );
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_email_change_requested',
      ]);
      expect(result.events[0].data['new_email'], 'new@example.com');
      expect(result.events[0].data['requested_by'], 'admin-1');
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits both events in order when both change',
    () async {
      final result = await action.execute(
        EditUserAccountInput(
          userId: 'u1',
          name: 'Bob',
          previousName: 'Alice',
          newEmail: 'bob@example.com',
        ),
        ctx,
      );
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_profile_changed',
        'user_email_change_requested',
      ]);
    },
  );
}
