// IMPLEMENTS REQUIREMENTS:
//   REQ-d00169 (AuthorizationPolicy): pluggable authorization interface
//   that the dispatcher's authorize stage queries once per declared
//   permission on the action.

import 'package:event_sourcing/src/actions/authorization_decision.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/principal.dart';

/// Pluggable authorization decision-maker. Concrete impls live in the
/// `action_permissions` library (TableBackedAuthorizationPolicy over a
/// RoleMatrixReader; FailSafeAuthorizationPolicy for the boot-failure
/// case).
//
// Implements: REQ-d00169-A — interface shape with isPermitted +
//             permissionsFor.
abstract class AuthorizationPolicy {
  const AuthorizationPolicy();

  /// Decide whether [principal] may exercise [permission].
  ///
  /// The dispatcher's authorize stage calls this once per permission
  /// declared by the action being dispatched. The first non-Allow
  /// short-circuits and produces an `authorization_denied` denial event.
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
  );

  /// The exercisable permission set for [principal] right now (filtered
  /// by session-context preconditions).
  ///
  /// Hosts call this once per session start to construct a
  /// `PermissionSnapshot` for client delivery.
  Future<Set<Permission>> permissionsFor(Principal principal);
}
