// Implements: DIARY-DEV-portal-reaction-server/A — composes ReactionHandlers over
//   openPortalEventStore + buildPortalDispatcher, exposing GET /me, POST /actions,
//   and the WS /subscriptions endpoint, plus a boot seed.
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:rave_integration/rave_integration.dart';
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

  // 3. Grant view-read permissions so clients can subscribe to the views that
  //    drive their screens (ReactionHandlers' default ViewPermissionNamer is
  //    `view:<viewName>`). These are view-read permissions, not action
  //    permissions, so they are appended directly rather than via the validated
  //    action-permission seed.
  Future<void> grantView(String role, String view) => eventStore.append(
        entryType: 'role_permission_grant',
        aggregateType: 'role_permission_grant',
        aggregateId: '$role:view:$view',
        eventType: 'permission_granted',
        data: PermissionGrantedPayload(
          role: role,
          permissionName: 'view:$view',
        ).toJson(),
        initiator: const AutomationInitiator(service: 'portal-skeleton-seed'),
      );

  // Administrator can subscribe to the role-assignments view + the user-accounts
  // index (only Administrator holds the user-management permissions).
  await grantView('Administrator', 'user_role_scopes');
  await grantView('Administrator', 'users_index');
  // The site list + participant records back the StudyCoordinator/CRA/Admin
  // operational screens.
  for (final role in const ['StudyCoordinator', 'CRA', 'Administrator']) {
    await grantView(role, 'sites_index');
    await grantView(role, 'participant_record');
  }
  // The RAVE-sync status screen is visible to operations roles too.
  for (final role in const [
    'StudyCoordinator',
    'CRA',
    'Administrator',
    'SystemOperator',
  ]) {
    await grantView(role, 'rave_sync_status');
  }

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

  // 4b. Boot-time RAVE sync: pull sites + subjects into the event log so the
  //     sites_index / participant_record / participant_site_index views are
  //     populated at startup. Uses the live RaveClient when RAVE_UAT_* env is
  //     present, else a fixed dev fixture (DevSeedRaveClient). The sync runs
  //     inside try/catch and CONTINUES on error: boot must not crash if RAVE is
  //     down or locked out — the RAVE-Sync screen surfaces the failure.
  // Implements: DIARY-DEV-rave-edc-ingest/A
  final env = Platform.environment;
  final lockoutConfig = LockoutConfig.fromEnv(env);
  final RaveClient raveClient;
  final List<String> studyOids;
  if (env['RAVE_UAT_URL'] != null) {
    raveClient = RaveClient(
      baseUrl: env['RAVE_UAT_URL']!,
      username: env['RAVE_UAT_USERNAME']!,
      password: env['RAVE_UAT_PWD']!,
    );
    studyOids = <String>[env['RAVE_STUDY_OID'] ?? DevSeedRaveClient.studyOid];
  } else {
    raveClient = DevSeedRaveClient();
    studyOids = const <String>[DevSeedRaveClient.studyOid];
  }
  final ingester = RaveEdcIngester(
    client: raveClient,
    store: eventStore,
    studyOids: studyOids,
    lockoutConfig: lockoutConfig,
  );
  try {
    await ingester.syncAll(now: DateTime.now().toUtc());
  } catch (e, st) {
    stderr.writeln('portal boot RAVE sync failed (continuing): $e\n$st');
  }

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
  // On-demand RAVE re-sync, gated to operations roles. The authenticated
  // Principal is attached by authMiddleware and read via principalFromContext.
  // Implements: DIARY-DEV-rave-edc-ingest/A
  Future<Response> raveSyncHandler(Request request) async {
    final principal = principalFromContext(request);
    final roles =
        principal is UserPrincipal ? principal.roles : const <String>{};
    if (!roles.contains('SystemOperator') && !roles.contains('Administrator')) {
      return Response.forbidden('requires SystemOperator or Administrator');
    }
    try {
      final result = await ingester.syncAll(now: DateTime.now().toUtc());
      return Response.ok(
        '{"skipped":${result.skipped},"sites":${result.sitesCount},'
        '"participants":${result.participantsCount}}',
        headers: const {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'RAVE sync failed: $e');
    }
  }

  final httpRouter = Router()
    ..get('/me', handlers.me)
    ..post('/actions', handlers.actions)
    // The client's permission source reads this to drive PermissionGate; without
    // it every gate fails closed (no widgets render, for any role).
    ..get('/permissions/snapshot', handlers.permissions)
    ..post('/admin/rave-sync', raveSyncHandler);

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
