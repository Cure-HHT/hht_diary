// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — Principal is constructed at the
//   request boundary and passed via ActionContext through every stage.
//   `toInitiator()` produces the Initiator stamped onto every emitted
//   event (success or denial).

import 'package:event_sourcing/src/storage/initiator.dart'
    show Initiator, UserInitiator, AnonymousInitiator;

/// The authenticated (or anonymous) caller of an action.
//
// Sealed: every consumer-side switch must exhaustively handle both
// variants. Adding a third variant is a deliberate code-plus-REQ change.
sealed class Principal {
  const Principal();

  const factory Principal.user({
    required String userId,
    required Set<String> roles,
    required String activeRole,
    String? activeSite,
  }) = UserPrincipal;

  const factory Principal.anonymous({String? ipAddress}) = AnonymousPrincipal;

  /// Stable string identifier used to key idempotency-cache entries
  /// per-principal (so two different principals can use the same
  /// idempotency key without collision).
  String get id;

  /// The `Initiator` value the dispatcher stamps onto every emitted
  /// event for this dispatch (including denial events).
  Initiator toInitiator();
}

final class UserPrincipal extends Principal {
  const UserPrincipal({
    required this.userId,
    required this.roles,
    required this.activeRole,
    this.activeSite,
  }) : assert(userId != '', 'userId must not be empty'),
       assert(activeRole != '', 'activeRole must not be empty');

  final String userId;
  final Set<String> roles;
  final String activeRole;

  /// The site the user has selected for the current session, if any.
  /// Used by site-scoped permissions in `action_permissions`.
  final String? activeSite;

  @override
  String get id => userId;

  @override
  Initiator toInitiator() => UserInitiator(userId);
}

final class AnonymousPrincipal extends Principal {
  const AnonymousPrincipal({this.ipAddress});

  final String? ipAddress;

  @override
  String get id => 'anon:${ipAddress ?? 'unknown'}';

  @override
  Initiator toInitiator() => AnonymousInitiator(ipAddress: ipAddress);
}
