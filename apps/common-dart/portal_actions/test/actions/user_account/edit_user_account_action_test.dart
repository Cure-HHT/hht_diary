// Verifies: DIARY-PRD-user-account-edit/A
// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('validate rejects a malformed newEmail', () {
    final action = EditUserAccountAction();
    expect(
      () => action.validate(
        EditUserAccountInput(
          userId: 'u-1',
          name: null,
          newEmail: 'not-an-email',
        ),
      ),
      throwsArgumentError,
    );
    // A valid address still passes.
    action.validate(
      EditUserAccountInput(
        userId: 'u-1',
        name: null,
        newEmail: 'new@example.com',
      ),
    );
  });

  final action = EditUserAccountAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'admin-1',
      roles: const {'Administrator'},
      activeRole: 'Administrator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares edit permission', () {
    expect(action.name, 'ACT-USR-002');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-USR-002']),
    );
  });

  test('name change emits user_profile_changed carrying the canonical '
      '{name} key so the users_index merge updates the row', () async {
    final input = action.parseInput(<String, Object?>{
      'userId': 'u-1',
      'name': 'New Name',
    });
    final result = await action.execute(input, ctx);
    final e = result.events.firstWhere(
      (d) => d.eventType == 'user_profile_changed',
    );
    expect(e.data['name'], 'New Name');
    expect(
      e.data.containsKey('after'),
      isFalse,
      reason:
          "legacy audit-table key 'after' must not reappear — the display "
          'name folds from the canonical name key',
    );
    expect(e.data['changed_by'], 'admin-1');
  });

  test('email change emits user_email_change_requested', () async {
    final input = action.parseInput(<String, Object?>{
      'userId': 'u-1',
      'newEmail': 'new@example.com',
    });
    final result = await action.execute(input, ctx);
    expect(
      result.events.any((d) => d.eventType == 'user_email_change_requested'),
      isTrue,
    );
  });

  test('rejects when neither name nor email supplied', () {
    expect(
      () => action.validate(
        action.parseInput(<String, Object?>{'userId': 'u-1'}),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
