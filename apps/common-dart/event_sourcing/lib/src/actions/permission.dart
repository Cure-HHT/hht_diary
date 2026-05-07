// IMPLEMENTS REQUIREMENTS:
//   REQ-d00169 (REQ-AUTHZ): Permission value type, used as a key in
//   the role-permission matrix and declared on each Action.
//   REQ-d00172-A: Permission carries the ScopeClass that constrains which
//   principals may exercise it based on session context.

import 'package:event_sourcing/src/actions/scope_class.dart';

/// A named permission, by convention `<aggregate>.<verb>` (e.g.
/// `user.invite`, `patient.enroll`). Used by `Action.permissions` to
/// declare what the action requires; used by `AuthorizationPolicy` to
/// decide whether a principal may execute it.
class Permission {
  // Implements: REQ-d00169-D — Permission is the discovery tool's unit;
  // each registered permission becomes one row in the SQL migration.
  const Permission(this.name, {required this.scope})
    : assert(name != '', 'name must not be empty');

  /// Throws `ArgumentError` if `name` is empty or whitespace-only.
  factory Permission.checked(String name, {required ScopeClass scope}) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'must not be empty or whitespace',
      );
    }
    return Permission(name, scope: scope);
  }

  final String name;

  /// The session-context precondition that restricts which principals
  /// may exercise this permission.
  final ScopeClass scope;

  @override
  bool operator ==(Object other) => other is Permission && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Permission($name, scope: $scope)';
}
