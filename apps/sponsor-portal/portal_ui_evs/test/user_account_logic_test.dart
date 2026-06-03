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
      UserAction.manageRolesSites,
    });
    expect(enabledUserActions(UserStatus.revoked), {UserAction.reactivate});
    expect(enabledUserActions(UserStatus.active), {
      UserAction.edit,
      UserAction.deactivate,
      UserAction.manageRolesSites,
    });
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
        DesiredAssignment(role: 'StudyCoordinator', sites: ['s1', 's2']),
      ],
      current: const [],
    );
    expect(plan.assignSites, [
      ('StudyCoordinator', 's1'),
      ('StudyCoordinator', 's2'),
    ]);
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
        DesiredAssignment(role: 'StudyCoordinator', sites: ['s1']),
      ],
      current: const [
        CurrentTuple(role: 'StudyCoordinator', site: 's1'),
        CurrentTuple(role: 'StudyCoordinator', site: 's2'),
      ],
    );
    expect(plan.assignSites, isEmpty);
    expect(plan.revokeSites, [('StudyCoordinator', 's2')]);
  });

  group('assignmentSubmissions', () {
    Object wildcardScopeJsonFor(String role) => <String, Object?>{
      'kind': 'wildcard',
      'role': role,
    };

    test('builds assignSite + wildcard assignRole submissions; no keys', () {
      const plan = AssignmentPlan(
        assignRoles: ['Administrator'],
        assignSites: [('StudyCoordinator', 'site-1')],
        revokeRoles: [],
        revokeSites: [],
      );
      final subs = assignmentSubmissions(plan, 'u@x.io', wildcardScopeJsonFor);

      expect(subs, hasLength(2));
      // assignSites come before assignRoles.
      expect(subs[0].actionName, assignSiteAction); // ACT-USR-008
      expect(subs[0].rawInput, {
        'userId': 'u@x.io',
        'role': 'StudyCoordinator',
        'site': 'site-1',
      });
      expect(subs[1].actionName, assignRoleAction); // ACT-USR-007
      expect(subs[1].rawInput, {
        'userId': 'u@x.io',
        'role': 'Administrator',
        'scope': wildcardScopeJsonFor('Administrator'),
      });
      // ActionClient mints keys at submit; the builder leaves them null.
      expect(subs[0].idempotencyKey, isNull);
      expect(subs[1].idempotencyKey, isNull);
    });

    test('orders revokes before assigns', () {
      const plan = AssignmentPlan(
        assignRoles: ['Administrator'],
        assignSites: [('CRA', 'site-2')],
        revokeRoles: ['SystemOperator'],
        revokeSites: [('CRA', 'site-1')],
      );
      final subs = assignmentSubmissions(plan, 'u@x.io', wildcardScopeJsonFor);

      expect(subs.map((s) => s.actionName).toList(), [
        revokeSiteAction, // ACT-USR-011
        revokeRoleAction, // ACT-USR-010
        assignSiteAction, // ACT-USR-008
        assignRoleAction, // ACT-USR-007
      ]);
      // revoke role / assign role carry the wildcard scope, not a site.
      expect(subs[1].rawInput['scope'], wildcardScopeJsonFor('SystemOperator'));
      expect(subs[3].rawInput['scope'], wildcardScopeJsonFor('Administrator'));
    });
  });
}
