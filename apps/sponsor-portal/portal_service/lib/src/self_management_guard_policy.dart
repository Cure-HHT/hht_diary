import 'package:event_sourcing/event_sourcing.dart';

/// Wraps an [AuthorizationPolicy] to forbid a user from running a
/// user-account-management action on their OWN account.
///
/// Every target-bearing `portal.user.*` permission is declared
/// `scopeClass: 'user'`, and the action's `scopeFor` resolves it to
/// `BoundScope('user', targetUserId)`. When that target IS the requesting
/// principal, this denies — preventing self-lockout (deactivating yourself,
/// revoking your own role, editing your own roles/sites) and satisfying the
/// user-management journeys' "cannot edit / deactivate your own account" rule.
/// Without this, a properly-provisioned Administrator (whose `tier:staff`
/// coverage includes their own staff-tier account) is authorized to manage
/// themselves.
///
/// All other decisions — including every non-`user`-scoped permission and the
/// `tier`-class grant_role escalation axis — delegate to [_inner] unchanged.
/// `effectivePermissionsFor` is delegated as-is: the principal genuinely holds
/// these permissions (for other users); the self-restriction is enforced only
/// at the per-target authorize check.
class SelfManagementGuardPolicy extends AuthorizationPolicy {
  SelfManagementGuardPolicy(this._inner);

  final AuthorizationPolicy _inner;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
    ScopeValue? scopeValue, {
    Transaction? txn,
  }) {
    if (permission.scopeClass == 'user' &&
        scopeValue is BoundScope &&
        scopeValue.value == principal.id) {
      return Future<AuthorizationDecision>.value(
        Deny(permission: permission, reason: DenyReason.notGranted),
      );
    }
    return _inner.isPermitted(principal, permission, scopeValue, txn: txn);
  }

  @override
  Future<EffectiveAuthorization> effectivePermissionsFor(
    Principal principal, {
    Transaction? txn,
  }) => _inner.effectivePermissionsFor(principal, txn: txn);
}
