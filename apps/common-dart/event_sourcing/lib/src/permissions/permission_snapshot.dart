// lib/src/permissions/permission_snapshot.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00177-A (snapshot value type and serialization).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.role,
    required this.grants,
    required this.issuedAt,
  });

  factory PermissionSnapshot.fromJson(Map<String, Object?> json) {
    final grantsList = json['grants']! as List<Object?>;
    final grants = grantsList.map((g) {
      final m = g! as Map<Object?, Object?>;
      final scopeName = m['scope']! as String;
      return Permission(
        m['name']! as String,
        scope: ScopeClass.values.firstWhere(
          (s) => s.name == scopeName,
          orElse: () => throw FormatException('unknown scope $scopeName'),
        ),
      );
    }).toSet();
    return PermissionSnapshot(
      role: json['role']! as String,
      grants: grants,
      issuedAt: DateTime.parse(json['issuedAt']! as String),
    );
  }

  final String role;
  final Set<Permission> grants;
  final DateTime issuedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'grants': grants
        .map((p) => <String, Object?>{'name': p.name, 'scope': p.scope.name})
        .toList(),
    'issuedAt': issuedAt.toIso8601String(),
  };
}
