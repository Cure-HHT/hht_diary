// Convenience scaffolding (not bound to a REQ): a deny-all
// AuthorizationPolicy used as a test fixture and as a placeholder
// during early app bootstrap. Production deployments wire
// TableBackedAuthorizationPolicy from the permissions module.

import 'package:event_sourcing/src/actions/authorization_decision.dart';
import 'package:event_sourcing/src/actions/authorization_policy.dart';
import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/actions/principal.dart';

/// Authorization policy that denies every request. Useful for unit
/// tests of the dispatcher's authorize stage and as a temporary
/// placeholder during early app bootstrap.
///
/// The default constructor logs a warning on every call (signal that
/// production should NOT be using this). Use [DenyAllAuthorizationPolicy.forTests]
/// to suppress the warning in unit tests.
class DenyAllAuthorizationPolicy extends AuthorizationPolicy {
  const DenyAllAuthorizationPolicy() : _suppressWarning = false;

  const DenyAllAuthorizationPolicy.forTests() : _suppressWarning = true;

  final bool _suppressWarning;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission permission,
  ) async {
    if (!_suppressWarning) {
      // ignore: avoid_print
      print(
        'WARNING: DenyAllAuthorizationPolicy.isPermitted called in '
        'production mode (use TableBackedAuthorizationPolicy from the '
        "event_sourcing package's permissions module, or another "
        'concrete policy)',
      );
    }
    return Deny(permission: permission, reason: DenyReason.notGranted);
  }

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async =>
      const <Permission>{};
}
