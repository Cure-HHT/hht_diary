// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167-D (ActionRegistry and Bootstrap): the top-level
//   convenience function that composes all dispatcher dependencies
//   into a ready ActionDispatcher.

import 'package:event_sourcing/event_sourcing.dart' show EventStore;
import 'package:event_sourcing/src/actions/action.dart';
import 'package:event_sourcing/src/actions/action_dispatcher.dart';
import 'package:event_sourcing/src/actions/action_registry.dart';
import 'package:event_sourcing/src/actions/authorization_policy.dart';
import 'package:event_sourcing/src/actions/idempotency_store.dart';

/// Compose a ready [ActionDispatcher] from its dependencies.
///
/// Builds an [ActionRegistry], registers all supplied [actions]
/// (rejecting collisions per REQ-d00167-A), wires the registry plus
/// [authorization], [events], and [idempotency] into the dispatcher,
/// and returns it.
ActionDispatcher bootstrapAuditedActions({
  required EventStore events,
  required AuthorizationPolicy authorization,
  required IdempotencyStore idempotency,
  required Iterable<Action<Object?, Object?>> actions,
}) {
  final registry = ActionRegistry();
  for (final action in actions) {
    registry.register(action);
  }
  return ActionDispatcher(
    registry: registry,
    authorization: authorization,
    events: events,
    idempotency: idempotency,
  );
}
