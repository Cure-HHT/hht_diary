// lib/src/permissions/fail_safe_authorization_policy.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-A (every query denies with bootstrapFailure reason).

import 'package:event_sourcing/event_sourcing.dart';

class FailSafeAuthorizationPolicy implements AuthorizationPolicy {
  const FailSafeAuthorizationPolicy(this.bootstrapErrors);
  final List<String> bootstrapErrors;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission perm,
  ) async {
    return Deny(permission: perm, reason: DenyReason.bootstrapFailure);
  }

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async {
    return const <Permission>{};
  }
}
