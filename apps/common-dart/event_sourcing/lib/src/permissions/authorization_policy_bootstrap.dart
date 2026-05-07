// lib/src/permissions/authorization_policy_bootstrap.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-B (sealed PolicyReady | PolicyFailSafe with isReady flag),
//   REQ-d00178-C (PolicyFailSafe.policy is FailSafeAuthorizationPolicy
//   with the carried errors).

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

@immutable
sealed class AuthorizationPolicyBootstrap {
  const AuthorizationPolicyBootstrap();
  AuthorizationPolicy get policy;
  bool get isReady;
  List<String> get errors;
}

final class PolicyReady extends AuthorizationPolicyBootstrap {
  const PolicyReady(this._policy);
  final AuthorizationPolicy _policy;

  @override
  AuthorizationPolicy get policy => _policy;
  @override
  bool get isReady => true;
  @override
  List<String> get errors => const <String>[];
}

final class PolicyFailSafe extends AuthorizationPolicyBootstrap {
  const PolicyFailSafe(this._errors);
  final List<String> _errors;

  @override
  AuthorizationPolicy get policy => FailSafeAuthorizationPolicy(_errors);
  @override
  bool get isReady => false;
  @override
  List<String> get errors => _errors;
}
