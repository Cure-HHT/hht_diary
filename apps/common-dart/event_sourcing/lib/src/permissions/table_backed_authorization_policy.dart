// lib/src/permissions/table_backed_authorization_policy.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-A (isPermitted with scope-precondition check before matrix
//   lookup),
//   REQ-d00176-B (permissionsFor filters by session preconditions).

import 'package:event_sourcing/event_sourcing.dart';

class TableBackedAuthorizationPolicy implements AuthorizationPolicy {
  const TableBackedAuthorizationPolicy(this._reader);
  final RoleMatrixReader _reader;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission perm,
  ) async {
    if (!_scopePreconditionMet(principal, perm.scope)) {
      return Deny(
        permission: perm,
        reason: DenyReason.sessionPreconditionMissing,
      );
    }
    if (principal is! UserPrincipal) {
      // AnonymousPrincipal has no role — nothing in the matrix can be
      // granted to them.
      return Deny(permission: perm, reason: DenyReason.notGranted);
    }
    final granted = await _reader.isGranted(principal.activeRole, perm.name);
    return granted
        ? const Allow()
        : Deny(permission: perm, reason: DenyReason.notGranted);
  }

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async {
    if (principal is! UserPrincipal) {
      return const <Permission>{};
    }
    final all = await _reader.grantsForRole(principal.activeRole);
    return all.where((p) => _scopePreconditionMet(principal, p.scope)).toSet();
  }

  bool _scopePreconditionMet(Principal p, ScopeClass scope) {
    return switch (scope) {
      ScopeClass.global => true,
      ScopeClass.site => p is UserPrincipal && p.activeSite != null,
      // UserPrincipal has a non-empty userId by invariant; anonymous has none.
      ScopeClass.self => p is UserPrincipal,
    };
  }
}
