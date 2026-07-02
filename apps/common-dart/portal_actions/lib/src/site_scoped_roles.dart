// Implements: DIARY-PRD-user-account-create/A — the authoritative set of roles
//   whose assignment binds to specific Sites and therefore REQUIRE at least one
//   assigned Site. Kept in portal_actions so server-side actions enforce the
//   invariant independently of any client form guard.

/// Backend-canonical role identifiers whose authorization binds to specific
/// **Sites** and therefore REQUIRE at least one assigned Site
/// (DIARY-PRD-user-account-create/A, DIARY-PRD-user-account-edit/C).
///
/// Mirrors the UI-side `roleScopeKind`
/// (portal_ui_evs/lib/src/user_account_logic.dart): `StudyCoordinator` and
/// `CRA` are site-scoped, while `Administrator` (all-sites wildcard) and
/// `SystemOperator` (total wildcard) are NOT site-scoped and may legitimately
/// carry zero Sites. The strings are the `PortalRole.systemName` values the
/// backend stores on `user_role_scopes.role`.
const Set<String> siteScopedRoleNames = <String>{'StudyCoordinator', 'CRA'};

/// True when [role] binds to Sites and thus requires at least one assigned
/// Site. Unknown roles are treated as NOT site-scoped (only the two known
/// site-scoped roles gate the Site requirement).
bool isSiteScopedRole(String role) => siteScopedRoleNames.contains(role);
