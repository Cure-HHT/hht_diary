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
import 'linking_code_lifecycle_reactor.dart';
import 'activation_routes.dart';
import 'audit_row.dart';
import 'dev_credential_auth_validator.dart';
import 'login_routes.dart';
import 'otp_store.dart';
import 'password_reset_code_store.dart';
import 'password_reset_routes.dart';
import 'patient_ingest_handler.dart';
import 'patient_link_handler.dart';
import 'patient_state_handler.dart';
import 'portal_view_scopes.dart';
import 'seed_config.dart';
import 'session_cascade_reactor.dart';
import 'session_store.dart';
import 'session_token_validator.dart';
import 'user_tier_reactor.dart';

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
  IdempotencyStore? idempotency,
  // Optional, env-driven Administrator seed for session mode (real Identity
  // Platform auth has no dev login, so a real admin must exist to drive E2E).
  // Falls back to PORTAL_BOOTSTRAP_ADMIN_EMAIL. null/empty = no-op. Applied
  // ONCE, inside the seed-once gate, so restarts do not re-append it. Keyed by
  // email because the portal's user identity is the email address; the IdP
  // account + portal user are provisioned out-of-band via activation later.
  String? bootstrapAdminEmail,
}) async {
  // 1. Event store (registers role_permission_grants, user_role_scopes,
  //    participant_site_index, portal entry types + framework types).
  final eventStore = await openPortalEventStore(backend: backend);

  // Implements: DIARY-DEV-portal-durable-event-store/C — seed once. The marker is
  //   appended LAST in the seed block under aggregate id 'singleton'; a targeted
  //   per-aggregate read finds it on a seeded store. A fresh store has no marker
  //   -> seed runs.
  final alreadySeeded = await _portalSeedMarkerPresent(backend);

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

  // RAVE client resolution + ingester construction, declared at function scope
  //     (OUTSIDE the seed gate) so the on-demand /admin/rave-sync handler can
  //     reuse the same `ingester`. Uses the live RaveClient when RAVE_UAT_* env
  //     is present, else a fixed dev fixture (DevSeedRaveClient). The boot-time
  //     `syncAll` that populates the sites_index / participant_record /
  //     participant_site_index views at startup is GATED inside the
  //     `if (!alreadySeeded)` seed block below (see step 4b there).
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

  // Implements: DIARY-DEV-portal-durable-event-store/C — one-time seed gate.
  //   Steps 3 (view-permission grants), 4 (role assignments) and 4b (boot RAVE
  //   sync) are all side-effecting appends; against a durable store they must
  //   run exactly once. The `ingester` is DECLARED above this block (it is reused
  //   later by the on-demand /admin/rave-sync handler); only its boot-time
  //   `syncAll` is gated here. The marker is appended LAST under aggregate id
  //   'singleton' so the targeted read in _portalSeedMarkerPresent finds it.
  if (!alreadySeeded) {
    // 3. View-read permission grants are NOT seeded here — they are idempotent
    //    and run on EVERY boot (after this seed-once gate) via `_grantViewPerms`,
    //    so adding a grant propagates on redeploy without a DB reset (consistent
    //    with the action-permission seed + role assignments). See step 3c below.

    // 4. Role assignments are NOT seeded here — they are config-driven and
    //    idempotent, so they run on EVERY boot (after this seed-once gate) via
    //    `_resolveRoleAssignmentSeed` + `bootstrapRoleAssignments`. See below.

    // 4a. Optional env-driven Administrator seed. In session mode there is no
    //     dev login, so a real admin must exist to drive the E2E flows. Seeds
    //     ONLY the role assignment (Administrator, all sites); the portal user
    //     record + IdP account are created out-of-band via activation later.
    //     Keyed by email (the portal's user identity). Inside the seed-once
    //     gate so restarts do not re-append it; default null/empty is a no-op.
    // Implements: DIARY-DEV-portal-durable-event-store/C
    final adminEmail = bootstrapAdminEmail ??
        Platform.environment['PORTAL_BOOTSTRAP_ADMIN_EMAIL'];
    if (adminEmail != null && adminEmail.isNotEmpty) {
      await bootstrapRoleAssignments(
        eventStore: eventStore,
        seed: RoleAssignmentSeed(entries: <RoleAssignmentSeedEntry>[
          RoleAssignmentSeedEntry(
            userId: adminEmail,
            role: 'Administrator',
            scope: const ValueWildcardScope(class_: 'site'),
          ),
          // Implements: DIARY-DEV-operator-tier-authz/E — staff-tier coverage so
          //   the env-seeded Administrator can exercise user-management actions
          //   against staff-tier accounts.
          RoleAssignmentSeedEntry(
            userId: adminEmail,
            role: 'Administrator',
            scope: const BoundScope(class_: 'tier', value: 'staff'),
          ),
        ]),
      );
    }

    // 4b. Boot-time RAVE sync (the on-demand handler below re-uses `ingester`).
    //     The sync runs inside try/catch and CONTINUES on error: boot must not
    //     crash if RAVE is down or locked out — the RAVE-Sync screen surfaces the
    //     failure.
    try {
      await ingester.syncAll(now: DateTime.now().toUtc());
    } catch (e, st) {
      stderr.writeln('portal boot RAVE sync failed (continuing): $e\n$st');
    }

    // Marker — appended LAST under aggregate id 'singleton'; the targeted
    //   per-aggregate read in _portalSeedMarkerPresent looks it up directly.
    await eventStore.append(
      entryType: 'portal_seed_marker',
      aggregateType: 'portal_seed',
      aggregateId: 'singleton',
      eventType: 'seeded',
      data: const <String, Object?>{},
      initiator: const AutomationInitiator(service: 'portal-skeleton-seed'),
    );
  }

  // 3c. View-read permission grants — idempotent, applied on EVERY boot (NOT in
  //     the seed-once gate above). Clients subscribe to the views that drive
  //     their screens; ReactionHandlers' default ViewPermissionNamer is
  //     `view:<viewName>`. These are view-read permissions, not action
  //     permissions, so they are appended directly rather than via the validated
  //     action-permission seed. `grantView` skips a grant the role already holds
  //     (each grant is the sole event under aggregate id `<role>:view:<view>`),
  //     so re-running every boot adds NEW grants on redeploy without re-appending
  //     duplicates — matching the action-permission + role-assignment seeds.
  Future<void> grantView(String role, String view) async {
    final aggregateId = '$role:view:$view';
    final existing =
        await eventStore.backend.findEventsForAggregate(aggregateId);
    if (existing.any((e) => e.eventType == 'permission_granted')) return;
    await eventStore.append(
      entryType: 'role_permission_grant',
      aggregateType: 'role_permission_grant',
      aggregateId: aggregateId,
      eventType: 'permission_granted',
      data: PermissionGrantedPayload(
        role: role,
        permissionName: 'view:$view',
      ).toJson(),
      initiator: const AutomationInitiator(service: 'portal-skeleton-seed'),
    );
  }

  // The Administrator AND the SystemOperator hold the user-management
  // permissions, so both can subscribe to the role-assignments view + the
  // user-accounts index. The operator-tier is the role that provisions the
  // first Administrators, so it must be able to read the user list to do so.
  for (final role in const ['Administrator', 'SystemOperator']) {
    await grantView(role, 'user_role_scopes');
    await grantView(role, 'users_index');
  }
  // The SystemOperator also reads the site list (sites_index) so the user
  // provisioning UI can offer the real RAVE-synced sites when assigning a
  // site-scoped role — site reference data, NOT participant/clinical data
  // (it deliberately does not get participant_record).
  await grantView('SystemOperator', 'sites_index');
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

  // 4c. Role assignments — config-driven + idempotent, applied on EVERY boot
  //     (NOT inside the seed-once gate above). `bootstrapRoleAssignments` diffs
  //     the seed against the user_role_scopes view and emits role_assigned only
  //     for missing entries, so an edited seed config propagates additions on
  //     redeploy; entries removed from the config surface as drift and are NOT
  //     auto-unassigned (revoke is an explicit action). A deployed env points
  //     PORTAL_SEED_USERS_PATH at the sponsor's seed file (e.g. SystemOperator-
  //     only; operators then provision the first admins); local/test runs omit
  //     it and get the in-code convenience seed.
  // Implements: DIARY-DEV-portal-seed-config/A+B
  await bootstrapRoleAssignments(
    eventStore: eventStore,
    seed: _resolveRoleAssignmentSeed(),
  );

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

  // 6. Dispatcher (registers all portal actions). The sponsor linking-code
  //    prefix is read here at boot and injected, keeping portal_actions
  //    dart:io-free (see generateLinkingCode).
  final dispatcher = await buildPortalDispatcher(
      eventStore: eventStore,
      idempotency: idempotency,
      linkingPrefix: env['SPONSOR_LINKING_PREFIX'] ?? 'XX');

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
    validator = DevCredentialAuthValidator(backend: backend);
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

  // 7c. Password-reset collaborators (code store + email sender + router).
  //     Routes are PUBLIC — mounted outside authMiddleware on topRouter.
  // Implements: DIARY-DEV-portal-reset-code-lifecycle/D
  // Implements: DIARY-DEV-portal-reset-password-update/B
  // Implements: DIARY-DEV-portal-reset-session-termination/A
  final passwordResetStore = PasswordResetCodeStore();
  final passwordResetRouter = buildPasswordResetRouter(
    eventStore: eventStore,
    backend: backend,
    store: passwordResetStore,
    emailSender: _PasswordResetEmailSenderAdapter(
        EmailTransport.fromConfig(emailConfig)),
    updatePassword: IdentityAdmin.updatePasswordByEmail,
    portalUrl: portalUrl,
  );

  // 7d. Session cascade reactor — mirrors exact treatment of ActivationReactor:
  //     started here, retained as a local final (StreamSubscription inside keeps
  //     it alive), stopped in dispose.
  // Implements: DIARY-DEV-portal-session-lifecycle/B
  final sessionCascadeReactor =
      SessionCascadeReactor(eventStore: eventStore, backend: backend)..start();

  // 7e. Linking-code lifecycle reactor — on participant_linking_code_issued,
  //     supersedes the participant's prior active code and self-heals the rare
  //     case where two participants are issued the same code.
  // Implements: DIARY-DEV-linking-code-lifecycle/B+D
  final linkingCodeReactor = LinkingCodeLifecycleReactor(
    eventStore: eventStore,
    backend: backend,
    linkingPrefix: env['SPONSOR_LINKING_PREFIX'] ?? 'XX',
  )..start();

  // 7f. User tier reactor — keeps user_tier_index correct by emitting
  //     user_tier_changed whenever a user's SystemOperator assignment changes.
  // Implements: DIARY-DEV-operator-tier-authz/A
  final userTierReactor =
      UserTierReactor(eventStore: eventStore, backend: backend)..start();

  // viewScopeRegistry enables per-subscription row-level narrowing: a site-bound
  // Study Coordinator's participant_record subscription is restricted to the
  // participants at their own Site (expanded via the participant_site_index
  // containment in buildPortalScopeRegistry). Without it, every authenticated
  // Principal with the view permission would receive ALL rows across all sites.
  // Implements: DIARY-DEV-portal-reaction-server/C
  final handlers = ReactionHandlers(
    eventStore: eventStore,
    dispatcher: dispatcher,
    policy: policy,
    scopeClassRegistry: buildPortalScopeRegistry(),
    viewScopeRegistry: buildPortalViewScopeRegistry(),
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

  // /password-reset/request, /password-reset/<code>, /password-reset: public
  // password-reset flow (no session required).
  // Implements: DIARY-DEV-portal-reset-code-lifecycle/D
  // Implements: DIARY-DEV-portal-reset-password-update/B
  final passwordResetHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(passwordResetRouter.call);

  // Patient clinical-record ingest (public; in-handler patient-JWT auth). Seam-
  // isolated for the deferred edge/core split.
  // Implements: DIARY-DEV-participant-ingest/A
  final ingestHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(patientIngestHandler(eventStore: eventStore));

  // Patient linking-code redemption (public; validates code, mints JWT, consumes
  // code). Seam-isolated for the deferred edge/core split, like /ingest.
  // Implements: DIARY-DEV-participant-link-issuance/A
  final linkHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(patientLinkHandler(eventStore: eventStore));

  // Patient state (public; in-handler patient-JWT auth): the trial-start
  // watermark the diary gates outbound sync on, plus linking status.
  // Implements: DIARY-PRD-questionnaire-system/C
  final stateHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(patientStateHandler(eventStore: eventStore));

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
    ..post('/login/verify-otp', loginHandler)
    // Password-reset routes (public).
    ..options('/password-reset/request', passwordResetHandler)
    ..post('/password-reset/request', passwordResetHandler)
    ..get('/password-reset/<code>', passwordResetHandler)
    ..options('/password-reset', passwordResetHandler)
    ..post('/password-reset', passwordResetHandler)
    // Patient clinical-record ingest (public). One canonical path, matching the
    // diary's DiaryServerDestination and the `/api/v1/user/link` versioned
    // namespace; portal_server_evs plays the diary-server ingest role until the
    // edge/core split lands.
    // Implements: DIARY-DEV-participant-ingest/A
    ..options('/api/v1/ingest/batch', ingestHandler)
    ..post('/api/v1/ingest/batch', ingestHandler)
    // Patient linking-code redemption (public).
    ..options('/api/v1/user/link', linkHandler)
    ..post('/api/v1/user/link', linkHandler)
    // Patient state: trial-start watermark + linking status (public; JWT-gated).
    ..options('/api/v1/user/state', stateHandler)
    ..get('/api/v1/user/state', stateHandler);

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

  // Public liveness/readiness for the container start gate + deploy smoke check.
  Response healthResponse(Request _) => Response.ok(
        jsonEncode(const <String, Object?>{
          'status': 'ok',
          'service': 'portal_server_evs',
          'versions': <String, Object?>{},
        }),
        headers: const {'Content-Type': 'application/json'},
      );
  topRouter
    ..get('/health', healthResponse)
    ..get('/ready', healthResponse);

  // Catch-all authed pipeline — must come last on topRouter.
  topRouter.mount('/', httpPipeline);

  Future<void> dispose() async {
    await activationReactor.stop();
    await sessionCascadeReactor.stop();
    await linkingCodeReactor.stop();
    await userTierReactor.stop();
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

/// Resolve the role-assignment seed. A deployed environment sets
/// PORTAL_SEED_USERS_PATH to a sponsor-bundled JSON file (parsed by
/// [parseSeedUsers]); if the var is set but the file is missing we fail fast
/// rather than silently fall back to the convenience seed (which would seed an
/// insecure wildcard admin into a deployed env). Local/test runs leave the var
/// unset and get [_localConvenienceSeed].
// Implements: DIARY-DEV-portal-seed-config/A+B
RoleAssignmentSeed _resolveRoleAssignmentSeed() {
  final path = Platform.environment['PORTAL_SEED_USERS_PATH']?.trim();
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'PORTAL_SEED_USERS_PATH="$path" is set but the file does not exist',
      );
    }
    return parseSeedUsers(file.readAsStringSync());
  }
  return _localConvenienceSeed;
}

/// In-code convenience seed for LOCAL / tests (no PORTAL_SEED_USERS_PATH): an
/// Administrator (wildcard sites + staff tier), a StudyCoordinator @ site-1, and
/// a multi-role dev user for exercising the dev quick-connect Role Selector.
/// Deployed envs override this with a sponsor seed file (SystemOperator-only for
/// dev). dev-credential login resolves these userIds from user_role_scopes.
const RoleAssignmentSeed _localConvenienceSeed = RoleAssignmentSeed(
  entries: <RoleAssignmentSeedEntry>[
    RoleAssignmentSeedEntry(
      userId: 'admin-1',
      role: 'Administrator',
      scope: ValueWildcardScope(class_: 'site'),
    ),
    // Implements: DIARY-DEV-operator-tier-authz/E — Administrator tier coverage
    //   is staff-only (a second entry; one scope per assignment).
    RoleAssignmentSeedEntry(
      userId: 'admin-1',
      role: 'Administrator',
      scope: BoundScope(class_: 'tier', value: 'staff'),
    ),
    RoleAssignmentSeedEntry(
      userId: 'sc-1',
      role: 'StudyCoordinator',
      scope: BoundScope(class_: 'site', value: 'site-1'),
    ),
    RoleAssignmentSeedEntry(
      userId: 'multi-1',
      role: 'Administrator',
      scope: ValueWildcardScope(class_: 'site'),
    ),
    RoleAssignmentSeedEntry(
      userId: 'multi-1',
      role: 'Administrator',
      scope: BoundScope(class_: 'tier', value: 'staff'),
    ),
    RoleAssignmentSeedEntry(
      userId: 'multi-1',
      role: 'StudyCoordinator',
      scope: BoundScope(class_: 'site', value: 'site-1'),
    ),
    // A local SystemOperator so operator-tier flows (provisioning the first
    // Administrators, RAVE unwedge) are testable locally. Mirrors the deployed
    // sponsor seed (portal-users.json): operator-tier + site wildcard scopes.
    // Deployed envs override this whole seed via PORTAL_SEED_USERS_PATH.
    RoleAssignmentSeedEntry(
      userId: 'sysop-1',
      role: 'SystemOperator',
      scope: ValueWildcardScope(class_: 'tier'),
    ),
    RoleAssignmentSeedEntry(
      userId: 'sysop-1',
      role: 'SystemOperator',
      scope: ValueWildcardScope(class_: 'site'),
    ),
  ],
);

// Implements: DIARY-DEV-portal-durable-event-store/C
Future<bool> _portalSeedMarkerPresent(StorageBackend backend) async {
  // Targeted per-aggregate read: the seed marker is the only event written under
  // aggregate id 'singleton', so findEventsForAggregate filters at the store
  // level instead of scanning the whole log. The entryType guard keeps this
  // correct even if 'singleton' were ever reused by another aggregate type.
  final events = await backend.findEventsForAggregate('singleton');
  return events.any((e) =>
      e.entryType == 'portal_seed_marker' || e.aggregateType == 'portal_seed');
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

/// Bridges [EmailTransport] to [ResetEmailSender] declared in
/// password_reset_routes.dart, building the rendered email via
/// [buildPasswordResetEmail] from portal_identity.
// Implements: DIARY-DEV-portal-reset-password-update/B
class _PasswordResetEmailSenderAdapter implements ResetEmailSender {
  _PasswordResetEmailSenderAdapter(this._transport);
  final EmailTransport _transport;
  @override
  Future<void> sendReset(
          {required String recipientEmail, required String resetUrl}) =>
      _transport.send(
        buildPasswordResetEmail(
            recipientEmail: recipientEmail, resetUrl: resetUrl),
        to: recipientEmail,
      );
}
