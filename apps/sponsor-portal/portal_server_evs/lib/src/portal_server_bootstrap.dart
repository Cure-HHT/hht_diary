// Implements: DIARY-DEV-portal-reaction-server/A — composes ReactionHandlers over
//   openPortalEventStore + buildPortalDispatcher, exposing GET /me, POST /actions,
//   and the WS /subscriptions endpoint, plus a boot seed.
import 'dart:convert';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_identity/portal_identity.dart';
import 'package:portal_service/portal_service.dart';
import 'package:rave_integration/rave_integration.dart';
import 'package:reaction/reaction.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'activation_code_store.dart';
import 'activation_reactor.dart';
import 'activation_routes.dart';
import 'audit_row.dart';
import 'dev_credential_auth_validator.dart';
import 'login_routes.dart';
import 'otp_store.dart';
import 'session_cascade_reactor.dart';
import 'session_store.dart';
import 'session_token_validator.dart';

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
  // Test seam: force a specific RAVE client (e.g. DevSeedRaveClient) so a unit
  // test is hermetic regardless of ambient RAVE_UAT_* env. null = the normal
  // env-based selection below.
  RaveClient? raveClient,
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
  final RaveClient resolvedRaveClient;
  final List<String> studyOids;
  if (raveClient != null) {
    // Explicit override (tests): use it as-is, scoped to the dev study oid.
    resolvedRaveClient = raveClient;
    studyOids = const <String>[DevSeedRaveClient.studyOid];
  } else if (env['RAVE_UAT_URL'] != null) {
    resolvedRaveClient = RaveClient(
      baseUrl: env['RAVE_UAT_URL']!,
      username: env['RAVE_UAT_USERNAME']!,
      password: env['RAVE_UAT_PWD']!,
    );
    studyOids = <String>[env['RAVE_STUDY_OID'] ?? DevSeedRaveClient.studyOid];
  } else {
    resolvedRaveClient = DevSeedRaveClient();
    studyOids = const <String>[DevSeedRaveClient.studyOid];
  }
  final ingester = RaveEdcIngester(
    client: resolvedRaveClient,
    store: eventStore,
    studyOids: studyOids,
    lockoutConfig: lockoutConfig,
  );
  try {
    await ingester.syncAll(now: DateTime.now().toUtc());
  } catch (e, st) {
    stderr.writeln('portal boot RAVE sync failed (continuing): $e\n$st');
  }

  // 5. Activation reactor + routes: ephemeral code store + email sender +
  //    reactor that watches for user_activation_code_issued events. Routes are
  //    PUBLIC (mounted outside authMiddleware on topRouter).
  // Implements: DIARY-DEV-portal-activation-email-delivery/A+B
  // Implements: DIARY-DEV-portal-activation-code-lifecycle/A
  final activationStore = ActivationCodeStore();
  final activationSender = ActivationEmailSender(
    transport: EmailTransport.fromConfig(EmailConfig.fromEnvironment()),
  );
  final portalUrl =
      Platform.environment['PORTAL_URL'] ?? 'http://localhost:8084';
  final activationReactor = ActivationReactor(
    store: activationStore,
    emailSender: activationSender,
    portalUrl: portalUrl,
  )..start(eventStore); // keep-alive: StreamSubscription inside holds a ref

  final activationRouter = buildActivationRouter(
    store: activationStore,
    eventStore: eventStore,
    provision: IdentityAdmin.lookupOrProvisionByEmail,
  );

  // 6. Dispatcher (registers all portal actions).
  final dispatcher = await buildPortalDispatcher(eventStore: eventStore);

  // 7. Validator selection — default is dev so the existing admin-1/sc-1
  //    workflow is unchanged. Set PORTAL_AUTH_MODE=session + PORTAL_SESSION_SIGNING_KEY
  //    to enable production session-token authentication.
  // Implements: DIARY-DEV-portal-session-token/A+B
  // Implements: DIARY-DEV-portal-session-lifecycle/A
  final authMode = Platform.environment['PORTAL_AUTH_MODE'] ?? 'dev';
  final signingKey = Platform.environment['PORTAL_SESSION_SIGNING_KEY'] ?? '';
  final sessionStore = SessionStore();
  final idleMinutes =
      int.tryParse(Platform.environment['PORTAL_SESSION_IDLE_MINUTES'] ?? '') ??
          10;

  final PrincipalAuthValidator validator;
  if (authMode == 'session') {
    if (signingKey.isEmpty) {
      throw StateError(
          'PORTAL_AUTH_MODE=session requires PORTAL_SESSION_SIGNING_KEY');
    }
    // Implements: DIARY-DEV-portal-session-token/B
    validator = SessionTokenValidator(
      signingKey: signingKey,
      backend: backend,
      eventStore: eventStore,
      sessionStore: sessionStore,
      idleTimeout: Duration(minutes: idleMinutes),
    );
  } else {
    validator = const DevCredentialAuthValidator();
  }

  // 7b. Login collaborators (OTP sender, identity config, login/session routes).
  //     Built unconditionally — login routes are always mounted; in dev mode the
  //     signingKey defaults to 'dev-unused' so the token math still runs.
  // Implements: DIARY-DEV-portal-login-second-factor/A+B+C
  final otpStore = OtpStore(
    ttl: Duration(
      minutes:
          int.tryParse(Platform.environment['PORTAL_OTP_TTL_MINUTES'] ?? '') ??
              10,
    ),
  );
  final emailConfig = EmailConfig.fromEnvironment();
  final otpSender = _LoginOtpSenderAdapter(
      LoginOtpSender(transport: EmailTransport.fromConfig(emailConfig)));
  final identityConfig = <String, Object?>{
    'projectId': Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ??
        'demo-local-stack',
    'apiKey': Platform.environment['PORTAL_IDENTITY_API_KEY'] ?? 'demo-api-key',
    'appId': Platform.environment['PORTAL_IDENTITY_APP_ID'] ?? '',
    'authDomain': Platform.environment['PORTAL_IDENTITY_AUTH_DOMAIN'] ?? '',
    'messagingSenderId':
        Platform.environment['PORTAL_IDENTITY_SENDER_ID'] ?? '',
    'emulatorHost': Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ?? '',
  };
  // Implements: DIARY-DEV-portal-login-identity-verification/A+B
  final loginRouter = buildLoginRouter(
    eventStore: eventStore,
    backend: backend,
    otpStore: otpStore,
    otpSender: otpSender,
    signingKey: signingKey.isEmpty ? 'dev-unused' : signingKey,
    verifyIdToken: verifyIdToken,
    identityConfig: identityConfig,
  );
  // Implements: DIARY-DEV-portal-session-lifecycle/A
  final authedSessionRouter = buildAuthedSessionRouter(
    eventStore: eventStore,
    signingKey: signingKey.isEmpty ? 'dev-unused' : signingKey,
  );

  // 7c. Session cascade reactor — mirrors exact treatment of ActivationReactor:
  //     started here, retained as a local final (StreamSubscription inside keeps
  //     it alive), stopped in dispose.
  // Implements: DIARY-DEV-portal-session-lifecycle/B
  final sessionCascadeReactor =
      SessionCascadeReactor(eventStore: eventStore, backend: backend)..start();

  final handlers = ReactionHandlers(
    eventStore: eventStore,
    dispatcher: dispatcher,
    policy: policy,
    scopeClassRegistry: buildPortalScopeRegistry(),
  );

  // 8. Routes: WS /subscriptions outside HTTP-auth middleware (Flutter web
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

  // Audit-trail read, gated to principals holding portal.audit.view. Reads the
  // event log reverse-chronological and maps each event to an audit row via the
  // shared auditRowJson mapper. The authenticated Principal is attached by
  // authMiddleware and read via principalFromContext.
  // Implements: DIARY-DEV-audit-log-read/A+B
  Future<Response> auditHandler(Request request) async {
    final principal = principalFromContext(request);
    final Iterable<String> perms;
    if (principal is UserPrincipal) {
      final eff = await policy.effectivePermissionsFor(principal);
      perms = eff.rolePermissions.map((p) => p.name);
    } else {
      perms = const <String>[];
    }
    if (!auditAccessAllowed(perms)) {
      return Response.forbidden('requires $auditViewPermission');
    }
    final requested =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 200;
    final limit = requested.clamp(1, 1000);
    final events = await backend.readEventsReverse().take(limit).toList();
    final rows = events.map(auditRowJson).toList();
    return Response.ok(
      jsonEncode(<String, Object?>{'rows': rows, 'count': rows.length}),
      headers: const {'Content-Type': 'application/json'},
    );
  }

  final httpRouter = Router()
    ..get('/me', handlers.me)
    ..post('/actions', handlers.actions)
    // The client's permission source reads this to drive PermissionGate; without
    // it every gate fails closed (no widgets render, for any role).
    ..get('/permissions/snapshot', handlers.permissions)
    ..get('/audit', auditHandler)
    ..post('/admin/rave-sync', raveSyncHandler)
    // Authed session routes (logout) — mounted inside the authed pipeline so
    // Bearer validation + principal context are present.
    // Implements: DIARY-DEV-portal-session-lifecycle/A
    ..mount('/', authedSessionRouter.call);

  final httpPipeline = const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(authMiddleware(validator))
      .addHandler(httpRouter.call);

  // Public route handlers — each wrapped in _cors() so the browser can read
  // responses from a different origin, and OPTIONS preflights short-circuit
  // before any auth check.  All are registered on topRouter BEFORE the
  // catch-all ..mount('/', httpPipeline).
  //
  // /activate: ephemeral code validation + password-set (no session yet).
  // Implements: DIARY-DEV-portal-activation-email-delivery/B
  final activationHandler =
      const Pipeline().addMiddleware(_cors()).addHandler(activationRouter.call);

  // /login, /login/verify-otp, /config/identity: unauthenticated login flow.
  // Implements: DIARY-DEV-portal-login-identity-verification/A+B
  // Implements: DIARY-DEV-portal-login-second-factor/A+B+C
  final loginHandler =
      const Pipeline().addMiddleware(_cors()).addHandler(loginRouter.call);

  final topRouter = Router()
    ..get('/subscriptions', handlers.subscriptions(validator))
    // Activation routes (public).
    ..options('/activate/<code>', activationHandler)
    ..options('/activate', activationHandler)
    ..get('/activate/<code>', activationHandler)
    ..post('/activate', activationHandler)
    // Login routes (public).
    ..options('/config/identity', loginHandler)
    ..get('/config/identity', loginHandler)
    ..options('/login', loginHandler)
    ..post('/login', loginHandler)
    ..options('/login/verify-otp', loginHandler)
    ..post('/login/verify-otp', loginHandler);

  // Dev-only: /dev/users exposes the role-assignment list so the dev
  // ConnectScreen can populate a dropdown. Not mounted in session mode.
  // Implements: DIARY-DEV-portal-reaction-server/B
  if (authMode != 'session') {
    final devUsersRouter = buildDevUsersRouter(backend: backend);
    final devUsersHandler =
        const Pipeline().addMiddleware(_cors()).addHandler(devUsersRouter.call);
    topRouter
      ..options('/dev/users', devUsersHandler)
      ..get('/dev/users', devUsersHandler);
  }

  // Catch-all authed pipeline — must come last on topRouter.
  topRouter.mount('/', httpPipeline);

  Future<void> dispose() async {
    await activationReactor.stop();
    await sessionCascadeReactor.stop();
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

/// Bridges portal_identity's [LoginOtpSender] to the [OtpSender] interface
/// declared in login_routes.dart, so portal_server_evs needs no direct
/// dependency on the internal LoginOtpSender type at every call site.
class _LoginOtpSenderAdapter implements OtpSender {
  _LoginOtpSenderAdapter(this._sender);
  final LoginOtpSender _sender;
  // Implements: DIARY-DEV-portal-login-second-factor/A
  @override
  Future<void> sendOtp(
          {required String recipientEmail, required String code}) =>
      _sender.sendOtp(recipientEmail: recipientEmail, code: code);
}
