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

  CreateUserAccountAction makeAction() =>
      CreateUserAccountAction(flowTokenMinter: SerialFlowTokenMinter(start: 1));

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: declares create permission + required idempotency',
    () {
      final action = makeAction();
      expect(action.name, 'ACT-USR-001');
      expect(
        action.permissions,
        contains(portalPermissionsByActId['ACT-USR-001']),
      );
      expect(action.idempotency, Idempotency.required);
    },
  );

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput rejects non-list roles', () {
    final action = makeAction();
    expect(
      () => action.parseInput(<String, Object?>{
        'email': 'a@b.com',
        'name': 'Alice',
        'activationExpiresAt': '2026-12-01T00:00:00Z',
        'roles': 'not-a-list',
        'sites': <String>[],
      }),
      throwsFormatException,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: parseInput rejects non-list sites', () {
    final action = makeAction();
    expect(
      () => action.parseInput(<String, Object?>{
        'email': 'a@b.com',
        'name': 'Alice',
        'activationExpiresAt': '2026-12-01T00:00:00Z',
        'roles': <String>['Admin'],
        'sites': 42,
      }),
      throwsFormatException,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank email', () {
    final action = makeAction();
    expect(
      () => action.validate(
        CreateUserAccountInput(
          email: '',
          name: 'Alice',
          activationExpiresAt: '2026-12-01T00:00:00Z',
          roles: const <String>[],
          sites: const <String>[],
        ),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test('validate rejects a malformed email (format is enforced at the '
      'action boundary, not only in client forms)', () {
    final action = makeAction();
    for (final bad in ['not-an-email', 'a@b', 'a b@c.com', '@x.com']) {
      expect(
        () => action.validate(
          CreateUserAccountInput(
            email: bad,
            name: 'Alice',
            activationExpiresAt: '2026-12-01T00:00:00Z',
            roles: const <String>[],
            sites: const <String>[],
          ),
        ),
        throwsArgumentError,
        reason: '"$bad" must be rejected',
      );
    }
  });

  // Verifies: DIARY-PRD-user-account-create/A — a site-scoped role (Study
  //   Coordinator / CRA) created with zero Sites is rejected at the action
  //   boundary, so the invariant holds even if the client form is bypassed.
  test('DIARY-PRD-user-account-create/A: create rejects a site-scoped role '
      'with zero Sites', () {
    final action = makeAction();
    for (final role in siteScopedRoleNames) {
      expect(
        () => action.validate(
          CreateUserAccountInput(
            email: 'a@b.com',
            name: 'Alice',
            activationExpiresAt: '2026-12-01T00:00:00Z',
            roles: <String>[role],
            sites: const <String>[],
          ),
        ),
        throwsArgumentError,
        reason: '$role with no Site must be rejected',
      );
    }
  });

  // Verifies: DIARY-PRD-user-account-create/A — the same site-scoped role with
  //   at least one Site is accepted.
  test('DIARY-PRD-user-account-create/A: create accepts a site-scoped role '
      'with at least one Site', () {
    final action = makeAction();
    expect(
      () => action.validate(
        CreateUserAccountInput(
          email: 'a@b.com',
          name: 'Alice',
          activationExpiresAt: '2026-12-01T00:00:00Z',
          roles: const <String>['StudyCoordinator'],
          sites: const <String>['site-1'],
        ),
      ),
      returnsNormally,
    );
  });

  // Verifies: DIARY-PRD-user-account-create/A — Administrator is wildcard-scoped
  //   (NOT site-scoped), so creating one with zero Sites is allowed.
  test('DIARY-PRD-user-account-create/A: create allows a non-site-scoped role '
      '(Administrator) with zero Sites', () {
    final action = makeAction();
    expect(
      () => action.validate(
        CreateUserAccountInput(
          email: 'a@b.com',
          name: 'Alice',
          activationExpiresAt: '2026-12-01T00:00:00Z',
          roles: const <String>['Administrator'],
          sites: const <String>[],
        ),
      ),
      returnsNormally,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test('DIARY-PRD-action-inventory/A: validate rejects blank name', () {
    final action = makeAction();
    expect(
      () => action.validate(
        CreateUserAccountInput(
          email: 'a@b.com',
          name: '   ',
          activationExpiresAt: '2026-12-01T00:00:00Z',
          roles: const <String>[],
          sites: const <String>[],
        ),
      ),
      throwsArgumentError,
    );
  });

  // Verifies: DIARY-PRD-action-inventory/A
  test(
    'DIARY-PRD-action-inventory/A: execute emits user_created + user_activation_code_issued with shared flowToken',
    () async {
      final action = CreateUserAccountAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 5),
      );
      final result = await action.execute(
        CreateUserAccountInput(
          email: 'alice@example.com',
          name: 'Alice',
          activationExpiresAt: '2026-12-01T00:00:00Z',
          roles: const <String>['Admin', 'Viewer'],
          sites: const <String>['site-1'],
        ),
        ctx,
      );
      expect(result.result.email, 'alice@example.com');
      expect(result.events.map((e) => e.entryType).toList(), [
        'user_created',
        'user_activation_code_issued',
      ]);
      // Both events share the same non-null flowToken
      final ft0 = result.events[0].flowToken;
      final ft1 = result.events[1].flowToken;
      expect(ft0, isNotNull);
      expect(ft0, ft1);
      // user_created fields
      expect(result.events[0].aggregateType, 'portal_user');
      expect(result.events[0].aggregateId, 'alice@example.com');
      expect(result.events[0].data['roles'], <String>['Admin', 'Viewer']);
      expect(result.events[0].data['created_by'], 'admin-1');
      // user_created carries explicit status for users_index merge
      final created = result.events.firstWhere(
        (e) => e.entryType == 'user_created',
      );
      expect(created.data['status'], 'pending');
      // user_activation_code_issued must NOT carry a status fact
      final code = result.events.firstWhere(
        (e) => e.entryType == 'user_activation_code_issued',
      );
      expect(code.data.containsKey('status'), isFalse);
      // user_activation_code_issued fields
      expect(result.events[1].data['reissue'], false);
      expect(result.events[1].data['issued_by'], 'admin-1');
      expect(result.events[1].data['expires_at'], '2026-12-01T00:00:00Z');
    },
  );
}
