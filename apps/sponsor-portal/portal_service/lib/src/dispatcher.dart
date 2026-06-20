// Implements: DIARY-PRD-action-inventory/A — wires the portal action registry,
//   the event-log-backed authorization policy, and an idempotency store into
//   an ActionDispatcher that enforces every portal action submission.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';

import 'authz.dart';
import 'self_management_guard_policy.dart';

/// Build a portal ActionDispatcher over [eventStore]. Bootstraps the
/// authorization policy from [roleGrantsYaml] (the sponsor role-permissions.yaml
/// source); throws [StateError] (carrying the seed validation errors) if the
/// seed is malformed, since a fail-safe policy would silently deny every
/// dispatch.
Future<ActionDispatcher> buildPortalDispatcher({
  required EventStore eventStore,
  required String roleGrantsYaml,
  IdempotencyStore? idempotency,
  String linkingPrefix = 'XX',
  String sponsorDiscoveryKey = '',
}) async {
  final bootstrap = await buildPortalAuthorizationPolicy(
    eventStore: eventStore,
    roleGrantsYaml: roleGrantsYaml,
  );
  final AuthorizationPolicy policy;
  switch (bootstrap) {
    case PolicyReady():
      // Wrap the seeded policy so a user can never run a user-account action on
      // their own account (self-lockout / "cannot edit/deactivate own account").
      policy = SelfManagementGuardPolicy(bootstrap.policy);
    case PolicyFailSafe():
      throw StateError(
        'portal authorization seed failed: ${bootstrap.errors.join('; ')}',
      );
  }

  return ActionDispatcher(
    registry: buildPortalActionRegistry(
      linkingPrefix: linkingPrefix,
      sponsorDiscoveryKey: sponsorDiscoveryKey,
    ),
    authorization: policy,
    events: eventStore,
    idempotency: idempotency ?? InMemoryIdempotencyStore(),
  );
}
