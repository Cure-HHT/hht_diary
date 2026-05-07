// lib/src/permissions/permission_revoked_payload.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-B (event payload shape for permission_revoked).

import 'package:meta/meta.dart';

@immutable
class PermissionRevokedPayload {
  const PermissionRevokedPayload({
    required this.role,
    required this.permissionName,
  });

  factory PermissionRevokedPayload.fromJson(Map<String, Object?> json) {
    return PermissionRevokedPayload(
      role: json['role']! as String,
      permissionName: json['permissionName']! as String,
    );
  }

  final String role;
  final String permissionName;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'permissionName': permissionName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionRevokedPayload &&
          role == other.role &&
          permissionName == other.permissionName;

  @override
  int get hashCode => Object.hash(role, permissionName);
}
