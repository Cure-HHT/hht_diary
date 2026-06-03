// Implements: DIARY-DEV-user-account-projection/B — UserStatus + per-status legal actions.
// Implements: DIARY-DEV-user-account-projection/C — pure desired-vs-current assignment diff
//   (cartesian over roles x sites), realized via the single-tuple assign/revoke actions.

import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;

/// Action names the user-account assign/revoke plan dispatches. Kept here (not
/// just in the screen) so the pure submission builder and its test reference
/// the same constants.
const String assignRoleAction = 'ACT-USR-007';
const String assignSiteAction = 'ACT-USR-008';
const String revokeRoleAction = 'ACT-USR-010';
const String revokeSiteAction = 'ACT-USR-011';

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
  manageRolesSites,
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
    UserAction.manageRolesSites,
  },
  UserStatus.active => {
    UserAction.edit,
    UserAction.deactivate,
    UserAction.manageRolesSites,
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

/// Builds the ordered [ActionSubmission] list realizing an [AssignmentPlan] for
/// [userId]: revoke sites/roles first, then assign sites/roles. Site-scoped
/// pairs use ACT-USR-008/011 (role + site); wildcard roles use ACT-USR-007/010
/// (role + the role-level wildcard scope from [wildcardScopeJsonFor]).
///
/// No idempotency keys are minted here: the screen submits each through an
/// `ActionClient`, which mints the per-submission key at submit time (the
/// actions declare `Idempotency.required`, so a missing key is parse-denied and
/// nothing commits).
///
/// Pure: no widget/scope dependency, so the screen can build the submissions
/// here and the test can assert action/rawInput shapes + revoke-before-assign
/// ordering.
List<ActionSubmission> assignmentSubmissions(
  AssignmentPlan plan,
  String userId,
  Object Function(String role) wildcardScopeJsonFor,
) => <ActionSubmission>[
  for (final (role, site) in plan.revokeSites)
    ActionSubmission(
      actionName: revokeSiteAction,
      rawInput: <String, Object?>{'userId': userId, 'role': role, 'site': site},
    ),
  for (final role in plan.revokeRoles)
    ActionSubmission(
      actionName: revokeRoleAction,
      rawInput: <String, Object?>{
        'userId': userId,
        'role': role,
        'scope': wildcardScopeJsonFor(role),
      },
    ),
  for (final (role, site) in plan.assignSites)
    ActionSubmission(
      actionName: assignSiteAction,
      rawInput: <String, Object?>{'userId': userId, 'role': role, 'site': site},
    ),
  for (final role in plan.assignRoles)
    ActionSubmission(
      actionName: assignRoleAction,
      rawInput: <String, Object?>{
        'userId': userId,
        'role': role,
        'scope': wildcardScopeJsonFor(role),
      },
    ),
];
