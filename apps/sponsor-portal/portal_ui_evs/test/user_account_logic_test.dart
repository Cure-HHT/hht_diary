import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/user_account_logic.dart';

void main() {
  test('statusFromRow', () {
    expect(statusFromRow({'status': 'pending'}), UserStatus.pending);
    expect(statusFromRow({'status': 'revoked'}), UserStatus.revoked);
    expect(statusFromRow({'status': 'active'}), UserStatus.active);
    expect(statusFromRow({'status': 'locked'}), UserStatus.locked);
    expect(statusFromRow({}), UserStatus.unknown);
  });

  test('enabledUserActions per status', () {
    expect(enabledUserActions(UserStatus.pending), {
      UserAction.edit,
      UserAction.resendActivation,
      UserAction.deletePending,
      UserAction.deactivate,
      UserAction.manageRolesSites
    });
    expect(enabledUserActions(UserStatus.revoked), {UserAction.reactivate});
    expect(enabledUserActions(UserStatus.active),
        {UserAction.edit, UserAction.deactivate, UserAction.manageRolesSites});
    expect(enabledUserActions(UserStatus.locked), {UserAction.unlock});
    expect(enabledUserActions(UserStatus.unknown), <UserAction>{});
  });

  test('roleScopeKind', () {
    expect(roleScopeKind('StudyCoordinator'), RoleScopeKind.site);
    expect(roleScopeKind('CRA'), RoleScopeKind.site);
    expect(roleScopeKind('Administrator'), RoleScopeKind.allSites);
    expect(roleScopeKind('SystemOperator'), RoleScopeKind.everything);
  });

  test('planAssignmentChanges adds site-scoped role per site', () {
    final plan = planAssignmentChanges(
      desired: const [
        DesiredAssignment(role: 'StudyCoordinator', sites: ['s1', 's2'])
      ],
      current: const [],
    );
    expect(plan.assignSites,
        [('StudyCoordinator', 's1'), ('StudyCoordinator', 's2')]);
    expect(plan.assignRoles, isEmpty);
    expect(plan.revokeSites, isEmpty);
    expect(plan.revokeRoles, isEmpty);
  });

  test('planAssignmentChanges adds wildcard role once (no sites)', () {
    final plan = planAssignmentChanges(
      desired: const [DesiredAssignment(role: 'Administrator', sites: [])],
      current: const [],
    );
    expect(plan.assignRoles, ['Administrator']);
    expect(plan.assignSites, isEmpty);
  });

  test('planAssignmentChanges revokes removed site, keeps unchanged', () {
    final plan = planAssignmentChanges(
      desired: const [
        DesiredAssignment(role: 'StudyCoordinator', sites: ['s1'])
      ],
      current: const [
        CurrentTuple(role: 'StudyCoordinator', site: 's1'),
        CurrentTuple(role: 'StudyCoordinator', site: 's2')
      ],
    );
    expect(plan.assignSites, isEmpty);
    expect(plan.revokeSites, [('StudyCoordinator', 's2')]);
  });
}
