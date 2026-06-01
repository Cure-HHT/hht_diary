// Implements: DIARY-DEV-user-account-projection/B — UserStatus + per-status legal actions.
// Implements: DIARY-DEV-user-account-projection/C — pure desired-vs-current assignment diff
//   (cartesian over roles x sites), realized via the single-tuple assign/revoke actions.

enum UserStatus {
  pending,
  active,
  revoked,
  locked,
  unknown;

  String get label => switch (this) {
        UserStatus.pending => 'Pending',
        UserStatus.active => 'Active',
        UserStatus.revoked => 'Revoked',
        UserStatus.locked => 'Locked',
        UserStatus.unknown => 'Unknown',
      };
}

enum UserAction {
  edit,
  resendActivation,
  deletePending,
  deactivate,
  reactivate,
  unlock,
  manageRolesSites
}

UserStatus statusFromRow(Map<String, Object?> row) => switch (row['status']) {
      'pending' => UserStatus.pending,
      'active' => UserStatus.active,
      'revoked' => UserStatus.revoked,
      'locked' => UserStatus.locked,
      _ => UserStatus.unknown,
    };

Set<UserAction> enabledUserActions(UserStatus s) => switch (s) {
      UserStatus.pending => {
          UserAction.edit,
          UserAction.resendActivation,
          UserAction.deletePending,
          UserAction.deactivate,
          UserAction.manageRolesSites
        },
      UserStatus.active => {
          UserAction.edit,
          UserAction.deactivate,
          UserAction.manageRolesSites
        },
      UserStatus.revoked => {UserAction.reactivate},
      UserStatus.locked => {UserAction.unlock},
      UserStatus.unknown => <UserAction>{},
    };

enum RoleScopeKind { site, allSites, everything }

RoleScopeKind roleScopeKind(String role) => switch (role) {
      'StudyCoordinator' || 'CRA' => RoleScopeKind.site,
      'Administrator' => RoleScopeKind.allSites,
      'SystemOperator' => RoleScopeKind.everything,
      _ => RoleScopeKind.site,
    };

class DesiredAssignment {
  const DesiredAssignment({required this.role, required this.sites});
  final String role;
  final List<String> sites;
}

class CurrentTuple {
  const CurrentTuple({required this.role, required this.site});
  final String role;
  final String site;
}

class AssignmentPlan {
  const AssignmentPlan({
    required this.assignRoles,
    required this.assignSites,
    required this.revokeRoles,
    required this.revokeSites,
  });
  final List<String> assignRoles;
  final List<(String, String)> assignSites;
  final List<String> revokeRoles;
  final List<(String, String)> revokeSites;
}

AssignmentPlan planAssignmentChanges({
  required List<DesiredAssignment> desired,
  required List<CurrentTuple> current,
}) {
  // Set literals are insertion-ordered (LinkedHashSet) so the resulting plan
  // lists are deterministic and follow the caller's desired/current ordering.
  final desiredSitePairs = <(String, String)>{};
  final desiredRoles = <String>{};
  for (final d in desired) {
    if (roleScopeKind(d.role) == RoleScopeKind.site) {
      for (final s in d.sites) {
        desiredSitePairs.add((d.role, s));
      }
    } else {
      desiredRoles.add(d.role);
    }
  }
  final currentSitePairs = <(String, String)>{};
  final currentRoles = <String>{};
  for (final c in current) {
    if (roleScopeKind(c.role) == RoleScopeKind.site) {
      currentSitePairs.add((c.role, c.site));
    } else {
      currentRoles.add(c.role);
    }
  }
  return AssignmentPlan(
    assignRoles: desiredRoles.difference(currentRoles).toList(),
    assignSites: desiredSitePairs.difference(currentSitePairs).toList(),
    revokeRoles: currentRoles.difference(desiredRoles).toList(),
    revokeSites: currentSitePairs.difference(desiredSitePairs).toList(),
  );
}
