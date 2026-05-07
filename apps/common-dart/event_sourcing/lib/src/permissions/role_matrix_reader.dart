// lib/src/permissions/role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (RoleMatrixReader is the single seam between policy and
//   storage substrate).
//
// Three concrete implementations live in sibling files:
//   - InMemoryRoleMatrixReader (Map-backed; tests + FailSafe)
//   - MaterializedViewRoleMatrixReader (server-side over StorageBackend)
//   - SnapshotRoleMatrixReader (client-side over PermissionSnapshot)

import 'package:event_sourcing/event_sourcing.dart' show Permission;

abstract class RoleMatrixReader {
  Future<bool> isGranted(String role, String permissionName);
  Future<Set<Permission>> grantsForRole(String role);
}
