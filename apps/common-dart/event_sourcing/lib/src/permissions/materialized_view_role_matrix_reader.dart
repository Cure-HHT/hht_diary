// lib/src/permissions/materialized_view_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (server-side RoleMatrixReader). Reads through
//   StorageBackend's view methods over the role_permission_grants view.

import 'package:event_sourcing/event_sourcing.dart';

class MaterializedViewRoleMatrixReader implements RoleMatrixReader {
  const MaterializedViewRoleMatrixReader(this.backend);
  final StorageBackend backend;

  static const String _viewName = 'role_permission_grants';

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    final rows = await backend.findViewRows(_viewName);
    return rows.any(
      (r) => r['role'] == role && r['permissionName'] == permissionName,
    );
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    final rows = await backend.findViewRows(_viewName);
    return rows
        .where((r) => r['role'] == role)
        .map(
          (r) => Permission(
            r['permissionName']! as String,
            scope: ScopeClass.values.firstWhere(
              (s) => s.name == r['scope']! as String,
              orElse: () => throw StateError(
                "unknown scope '${r['scope']}' for "
                "${r['role']}:${r['permissionName']}",
              ),
            ),
          ),
        )
        .toSet();
  }
}
