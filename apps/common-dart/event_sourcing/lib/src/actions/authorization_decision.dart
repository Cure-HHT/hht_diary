// IMPLEMENTS REQUIREMENTS:
//   REQ-d00173-B+C+D: isPermitted returns AuthorizationDecision (Allow
//   or Deny); Deny carries the denied Permission and a DenyReason; the
//   DenyReason enum has the three closed values notGranted,
//   sessionPreconditionMissing, bootstrapFailure.
//   REQ-d00171: the dispatcher uses Deny.permission and Deny.reason to
//   construct authorization_denied denial events.

import 'package:event_sourcing/src/actions/permission.dart';
import 'package:meta/meta.dart';

/// The outcome of an `AuthorizationPolicy.isPermitted` call.
//
// Sealed: every consumer-side switch must exhaustively handle Allow and
// Deny. Adding a third variant is a deliberate code-plus-REQ change.
@immutable
sealed class AuthorizationDecision {
  const AuthorizationDecision();
}

/// The principal is permitted to exercise the permission.
final class Allow extends AuthorizationDecision {
  const Allow();
}

/// The principal is NOT permitted. Carries the denied permission and
/// the reason class so the dispatcher can construct the right denial
/// event payload.
final class Deny extends AuthorizationDecision {
  const Deny({required this.permission, required this.reason});

  final Permission permission;
  final DenyReason reason;
}

/// Why a [Deny] decision was returned.
//
// Closed enum. Adding a value here is a deliberate code-plus-REQ change.
enum DenyReason {
  /// The principal's role does not hold the permission in the matrix.
  notGranted,

  /// The permission's scope precondition is not satisfied (e.g. site-
  /// scoped permission with no `activeSite`, or self-scoped permission
  /// while anonymous).
  sessionPreconditionMissing,

  /// The authorization policy booted in fail-safe mode; no decisions
  /// can be trusted, so everything is denied.
  bootstrapFailure,
}
