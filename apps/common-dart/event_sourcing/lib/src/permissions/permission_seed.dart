// lib/src/permissions/permission_seed.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-A (PermissionSeed value type).

import 'package:meta/meta.dart';

@immutable
class PermissionSeed {
  const PermissionSeed({required this.roles, required this.grants});

  final Set<String> roles;
  final Map<String, Set<String>> grants;
}
