import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';
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
    // Mirrors the real _roleScopesJsonFor multiplicity: the Administrator
    // carries TWO role-level scopes (site wildcard + staff tier); the System
    // Operator one (total). Stand-in JSON — the builder is scope-shape-agnostic.
    List<Object> roleScopesJsonFor(String role) => switch (role) {
      'Administrator' => <Object>[
        <String, Object?>{'kind': 'wildcard', 'class': 'site'},
        <String, Object?>{'kind': 'bound', 'class': 'tier', 'value': 'staff'},
      ],
      _ => <Object>[
        <String, Object?>{'kind': 'total'},
      ],
    };

    test('Administrator assign carries BOTH a site AND a staff-tier scope', () {
      const plan = AssignmentPlan(
        assignRoles: ['Administrator'],
        assignSites: [('StudyCoordinator', 'site-1')],
        revokeRoles: [],
        revokeSites: [],
      );
      final subs = assignmentSubmissions(plan, 'u@x.io', roleScopesJsonFor);

      // 1 assignSite + 2 assignRole (one per Administrator scope).
      expect(subs, hasLength(3));
      expect(subs[0].actionName, assignSiteAction); // ACT-USR-008
      expect(subs[0].rawInput, {
        'userId': 'u@x.io',
        'role': 'StudyCoordinator',
        'site': 'site-1',
      });
      // Both role-level scopes are emitted as separate assign_role submissions.
      final adminScopes = subs
          .where((s) => s.actionName == assignRoleAction)
          .map((s) => s.rawInput['scope'])
          .toList();
      expect(adminScopes, roleScopesJsonFor('Administrator'));
      // Regression (DIARY-DEV-operator-tier-authz/E): a provisioned Administrator
      // MUST receive a tier-class scope, else it cannot manage users.
      expect(
        adminScopes.whereType<Map>().any((m) => m['class'] == 'tier'),
        isTrue,
        reason: 'Administrator must carry a tier-class coverage scope',
      );
      expect(subs.every((s) => s.idempotencyKey == null), isTrue);
    });

    test('orders revokes before assigns; per-scope role submissions', () {
      const plan = AssignmentPlan(
        assignRoles: ['Administrator'],
        assignSites: [('CRA', 'site-2')],
        revokeRoles: ['SystemOperator'],
        revokeSites: [('CRA', 'site-1')],
      );
      final subs = assignmentSubmissions(plan, 'u@x.io', roleScopesJsonFor);

      // SystemOperator -> 1 revoke_role; Administrator -> 2 assign_role.
      expect(subs.map((s) => s.actionName).toList(), [
        revokeSiteAction, // ACT-USR-011  (CRA site-1)
        revokeRoleAction, // ACT-USR-010  (SystemOperator, total)
        assignSiteAction, // ACT-USR-008  (CRA site-2)
        assignRoleAction, // ACT-USR-007  (Administrator, site)
        assignRoleAction, // ACT-USR-007  (Administrator, tier:staff)
      ]);
    });
  });

  group('currentTuplesFor', () {
    test('site-scoped assignments expand one tuple per bound site; '
        'wildcards contribute a single role-only tuple', () {
      const user = PortalUserView(
        email: 'eparker@clinicaltrial.com',
        name: 'Dr. Emily Parker',
        status: UserStatusView.active,
        assignments: [
          RoleAssignmentView(
            role: 'StudyCoordinator',
            boundSites: ['s1', 's2'],
            isWildcard: false,
          ),
          RoleAssignmentView(
            role: 'Administrator',
            boundSites: [],
            isWildcard: true,
          ),
        ],
      );
      final tuples = currentTuplesFor(user);
      expect(tuples.map((t) => (t.role, t.site)).toList(), [
        ('StudyCoordinator', 's1'),
        ('StudyCoordinator', 's2'),
        ('Administrator', ''),
      ]);

      // Round-trip: feeding the tuples back as the unchanged desired
      // state must produce an empty plan (no spurious revokes/assigns).
      final plan = planAssignmentChanges(
        desired: const [
          DesiredAssignment(role: 'StudyCoordinator', sites: ['s1', 's2']),
          DesiredAssignment(role: 'Administrator', sites: []),
        ],
        current: tuples,
      );
      expect(plan.assignRoles, isEmpty);
      expect(plan.assignSites, isEmpty);
      expect(plan.revokeRoles, isEmpty);
      expect(plan.revokeSites, isEmpty);
    });
  });

  group('editUserSubmissions', () {
    const emptyPlan = AssignmentPlan(
      assignRoles: [],
      assignSites: [],
      revokeRoles: [],
      revokeSites: [],
    );

    test('no profile change + empty plan -> no submissions', () {
      final subs = editUserSubmissions(
        userId: 'u@x.io',
        newName: null,
        newEmail: null,
        plan: emptyPlan,
      );
      expect(subs, isEmpty);
    });

    test('profile edit precedes the assignment realization and only '
        'carries the changed fields', () {
      const plan = AssignmentPlan(
        assignRoles: [],
        assignSites: [('CRA', 'site-2')],
        revokeRoles: [],
        revokeSites: [],
      );
      final subs = editUserSubmissions(
        userId: 'u@x.io',
        newName: 'New Name',
        newEmail: null,
        plan: plan,
      );
      expect(subs.map((s) => s.actionName).toList(), [
        editUserAction, // ACT-USR-002 first
        assignSiteAction,
      ]);
      expect(subs.first.rawInput, {'userId': 'u@x.io', 'name': 'New Name'});
    });

    test('email change emits newEmail', () {
      final subs = editUserSubmissions(
        userId: 'u@x.io',
        newName: null,
        newEmail: 'new@x.io',
        plan: emptyPlan,
      );
      expect(subs.single.actionName, editUserAction);
      expect(subs.single.rawInput, {
        'userId': 'u@x.io',
        'newEmail': 'new@x.io',
      });
    });
  });
}
