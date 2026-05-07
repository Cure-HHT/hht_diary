// lib/src/permissions/snapshot_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (client-side RoleMatrixReader),
//   REQ-d00177-C (principal-scoped — only answers for snapshot.role).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:event_sourcing/src/permissions/permission_snapshot.dart';
import 'package:event_sourcing/src/permissions/role_matrix_reader.dart';

class SnapshotRoleMatrixReader implements RoleMatrixReader {
  const SnapshotRoleMatrixReader(this._snapshot);
  final PermissionSnapshot _snapshot;

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    if (role != _snapshot.role) return false;
    return _snapshot.grants.any((p) => p.name == permissionName);
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    return role == _snapshot.role ? _snapshot.grants : const <Permission>{};
  }
}
