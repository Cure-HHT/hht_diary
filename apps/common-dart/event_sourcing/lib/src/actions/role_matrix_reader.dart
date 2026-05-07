// IMPLEMENTS REQUIREMENTS:
//   REQ-d00169-B: read interface for the role-permission matrix.

/// Read-only access to the deploy-time-configurable role-permission
/// matrix. Implementations typically read from a Postgres materialized
/// view (`role_permission_matrix`) populated by the discovery tool +
/// admin grants.
//
// Implements: REQ-d00169-B — TableBackedAuthorizationPolicy depends on
// this; deployers wire a concrete impl at app bootstrap.
// ignore: one_member_abstracts
abstract class RoleMatrixReader {
  Future<Set<String>> permissionsForRole(String role);
}
