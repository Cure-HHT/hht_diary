// lib/src/permissions/in_memory_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (RoleMatrixReader in-memory impl). Used as a test
//   fixture and as the backing for FailSafeAuthorizationPolicy (with an
//   empty map).

import 'package:event_sourcing/event_sourcing.dart';

class InMemoryRoleMatrixReader implements RoleMatrixReader {
  const InMemoryRoleMatrixReader(this._grants);

  factory InMemoryRoleMatrixReader.empty() =>
      const InMemoryRoleMatrixReader(<String, Map<String, Permission>>{});

  final Map<String, Map<String, Permission>> _grants;

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    return _grants[role]?.containsKey(permissionName) ?? false;
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    final perPermission = _grants[role];
    if (perPermission == null) return const <Permission>{};
    return perPermission.values.toSet();
  }
}
