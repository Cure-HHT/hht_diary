// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (ActionRegistry and Bootstrap): keyed action registry
//   with name-collision detection at register time and permission
//   discovery for the role-permission matrix migration tool.

import 'package:event_sourcing/src/actions/action.dart';
import 'package:event_sourcing/src/actions/permission.dart';

/// Central registry of all `Action` instances known to a deployment.
//
// Implements: REQ-d00167-A — register throws on name collision.
//             REQ-d00167-B — lookup returns the registered action or null.
//             REQ-d00167-C — allDeclaredPermissions is the union across
//             every registered action.
class ActionRegistry {
  ActionRegistry();

  final Map<String, Action<Object?, Object?>> _byName =
      <String, Action<Object?, Object?>>{};

  /// Register [action]. Throws [ArgumentError] if `action.name` is
  /// already registered.
  void register<TI, TR>(Action<TI, TR> action) {
    if (_byName.containsKey(action.name)) {
      throw ArgumentError.value(
        action.name,
        'action.name',
        'already registered; action names must be unique',
      );
    }
    _byName[action.name] = action as Action<Object?, Object?>;
  }

  /// Returns the action registered under [name], or null.
  Action<Object?, Object?>? lookup(String name) => _byName[name];

  /// Every registered action, in insertion order.
  Iterable<Action<Object?, Object?>> get all => _byName.values;

  /// Union of `permissions` across every registered action. Used by the
  /// permission discovery tool to seed the role-permission matrix.
  Set<Permission> get allDeclaredPermissions => <Permission>{
    for (final a in _byName.values) ...a.permissions,
  };
}
