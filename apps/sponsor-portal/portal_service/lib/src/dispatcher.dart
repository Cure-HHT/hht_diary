// Implements: DIARY-PRD-action-inventory/A — wires the portal action registry,
//   the event-log-backed authorization policy, and an idempotency store into
//   an ActionDispatcher that enforces every portal action submission.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';

import 'authz.dart';

/// Build a portal ActionDispatcher over [eventStore]. Bootstraps the
/// authorization policy from the role-permission seed; throws [StateError]
/// (carrying the seed validation errors) if the seed is malformed, since a
/// fail-safe policy would silently deny every dispatch.
Future<ActionDispatcher> buildPortalDispatcher({
  required EventStore eventStore,
  IdempotencyStore? idempotency,
  String linkingPrefix = 'XX',
}) async {
  final bootstrap = await buildPortalAuthorizationPolicy(
    eventStore: eventStore,
  );
  final AuthorizationPolicy policy;
  switch (bootstrap) {
    case PolicyReady():
      policy = bootstrap.policy;
    case PolicyFailSafe():
      throw StateError(
        'portal authorization seed failed: ${bootstrap.errors.join('; ')}',
      );
  }

  return ActionDispatcher(
    registry: buildPortalActionRegistry(linkingPrefix: linkingPrefix),
    authorization: policy,
    events: eventStore,
    idempotency: idempotency ?? InMemoryIdempotencyStore(),
  );
}
