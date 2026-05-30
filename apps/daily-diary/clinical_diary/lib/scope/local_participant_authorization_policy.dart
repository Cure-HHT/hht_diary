// Implements: DIARY-DEV-local-participant-authorization/D — on-device authorization
//   permits the authenticated local participant; it is NOT the authoritative gate.
//
// SELF-IMPOSED-RESTRICTION NOTE: the diary is local-first and single-user, so on
// device the local participant is permitted their own diary actions. This is NOT
// a study-enrollment gate — recording works regardless of link state (the only
// enrollment gate is on sync). The diary-server re-validates synced events at
// ingest as the authoritative authorization gate. The lib ships only
// DenyAllAuthorizationPolicy, so this permissive local policy is authored here.
import 'package:event_sourcing/event_sourcing.dart';

class LocalParticipantAuthorizationPolicy extends AuthorizationPolicy {
  const LocalParticipantAuthorizationPolicy({
    this.grantedPermissions = const {},
  });

  /// Permissions surfaced via [effectivePermissionsFor] for PermissionGate UI.
  /// Typically `ActionRegistry.allDeclaredPermissions`.
  final Set<Permission> grantedPermissions;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
    ScopeValue? scopeValue, {
    Transaction? txn,
  }) async {
    if (principal is UserPrincipal) return const Allow();
    return Deny(permission: permission, reason: DenyReason.notGranted);
  }

  @override
  Future<EffectiveAuthorization> effectivePermissionsFor(
    Principal principal, {
    Transaction? txn,
  }) async {
    if (principal is UserPrincipal) {
      return EffectiveAuthorization(
        activeRole: principal.activeRole,
        rolePermissions: grantedPermissions,
        scopeAssignments: const [],
      );
    }
    return EffectiveAuthorization.empty;
  }
}
