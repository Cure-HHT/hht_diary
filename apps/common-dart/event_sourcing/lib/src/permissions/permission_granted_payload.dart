// lib/src/permissions/permission_granted_payload.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-A (event payload shape for permission_granted).

import 'package:event_sourcing/event_sourcing.dart' show ScopeClass;
import 'package:meta/meta.dart';

@immutable
class PermissionGrantedPayload {
  const PermissionGrantedPayload({
    required this.role,
    required this.permissionName,
    required this.scope,
  });

  factory PermissionGrantedPayload.fromJson(Map<String, Object?> json) {
    final scopeName = json['scope']! as String;
    final scope = ScopeClass.values.firstWhere(
      (s) => s.name == scopeName,
      orElse: () => throw FormatException('unknown scope: $scopeName'),
    );
    return PermissionGrantedPayload(
      role: json['role']! as String,
      permissionName: json['permissionName']! as String,
      scope: scope,
    );
  }

  final String role;
  final String permissionName;
  final ScopeClass scope;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'permissionName': permissionName,
    'scope': scope.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionGrantedPayload &&
          role == other.role &&
          permissionName == other.permissionName &&
          scope == other.scope;

  @override
  int get hashCode => Object.hash(role, permissionName, scope);
}
