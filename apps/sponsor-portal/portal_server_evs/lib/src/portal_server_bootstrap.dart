// Implements: DIARY-DEV-portal-reaction-server/A — composes ReactionHandlers over
//   openPortalEventStore + buildPortalDispatcher, exposing GET /me, POST /actions,
//   and the WS /subscriptions endpoint, plus a boot seed.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:reaction/reaction.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'dev_credential_auth_validator.dart';

/// Composed server: the top-level shelf [router] (ready for shelf_io.serve),
/// the live [eventStore] + [dispatcher] (for tests), and a [dispose] callback.
class PortalServerBoot {
  PortalServerBoot({
    required this.router,
    required this.eventStore,
    required this.dispatcher,
    required this.dispose,
  });

  final Router router;
  final EventStore eventStore;
  final ActionDispatcher dispatcher;
  final Future<void> Function() dispose;
}

const _corsHeaders = <String, String>{
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

Middleware _cors() => (Handler inner) => (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };

/// Compose the reactive portal server over [backend].
Future<PortalServerBoot> bootstrapPortalServer({
  required StorageBackend backend,
}) async {
  // 1. Event store (registers role_permission_grants, user_role_scopes,
  //    participant_site_index, portal entry types + framework types).
  final eventStore = await openPortalEventStore(backend: backend);

  // 2. Authorization policy from the SP1/SP2 role-permission seed.
  final bootstrap =
      await buildPortalAuthorizationPolicy(eventStore: eventStore);
  final AuthorizationPolicy policy;
  switch (bootstrap) {
    case PolicyReady():
      policy = bootstrap.policy;
    case PolicyFailSafe():
      throw StateError(
        'portal authorization seed failed: ${bootstrap.errors.join('; ')}',
      );
  }

  // 3. Grant the Administrator role view:user_role_scopes so the admin client
  //    can subscribe to that view (ReactionHandlers' default ViewPermissionNamer
  //    is `view:<viewName>`). This is a view-read permission, not an action
  //    permission, so it is appended directly rather than via the validated
  //    action-permission seed.
  await eventStore.append(
    entryType: 'role_permission_grant',
    aggregateType: 'role_permission_grant',
    aggregateId: 'Administrator:view:user_role_scopes',
    eventType: 'permission_granted',
    data: PermissionGrantedPayload(
      role: 'Administrator',
      permissionName: 'view:user_role_scopes',
    ).toJson(),
    initiator: const AutomationInitiator(service: 'portal-skeleton-seed'),
  );

  // 4. Seed role assignments: an admin (so the admin Principal passes the
  //    membership gate) and a coordinator (to demonstrate enforced denial).
  await bootstrapRoleAssignments(
    eventStore: eventStore,
    seed: const RoleAssignmentSeed(entries: <RoleAssignmentSeedEntry>[
      RoleAssignmentSeedEntry(
        userId: 'admin-1',
        role: 'Administrator',
        scope: ValueWildcardScope(class_: 'site'),
      ),
      RoleAssignmentSeedEntry(
        userId: 'sc-1',
        role: 'StudyCoordinator',
        scope: BoundScope(class_: 'site', value: 'site-1'),
      ),
    ]),
  );

  // 5. Dispatcher (registers all portal actions).
  final dispatcher = await buildPortalDispatcher(eventStore: eventStore);

  // 6. Reaction handlers + dev auth.
  const validator = DevCredentialAuthValidator();
  final handlers = ReactionHandlers(
    eventStore: eventStore,
    dispatcher: dispatcher,
    policy: policy,
    scopeClassRegistry: buildPortalScopeRegistry(),
  );

  // 7. Routes: WS /subscriptions outside HTTP-auth middleware (Flutter web
  //    cannot set WS upgrade headers; credentials arrive in-band). HTTP me/actions
  //    behind CORS + authMiddleware (CORS first so OPTIONS preflight short-circuits
  //    before the auth check).
  final httpRouter = Router()
    ..get('/me', handlers.me)
    ..post('/actions', handlers.actions);

  final httpPipeline = const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(authMiddleware(validator))
      .addHandler(httpRouter.call);

  final topRouter = Router()
    ..get('/subscriptions', handlers.subscriptions(validator))
    ..mount('/', httpPipeline);

  Future<void> dispose() async {
    await handlers.dispose();
    await eventStore.close();
  }

  return PortalServerBoot(
    router: topRouter,
    eventStore: eventStore,
    dispatcher: dispatcher,
    dispose: dispose,
  );
}
