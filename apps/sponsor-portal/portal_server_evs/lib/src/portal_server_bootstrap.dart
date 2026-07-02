// Implements: DIARY-DEV-portal-reaction-server/A — composes ReactionHandlers over
//   openPortalEventStore + buildPortalDispatcher, exposing GET /me, POST /actions,
//   and the WS /subscriptions endpoint, plus a boot seed.
import 'dart:convert';
import 'dart:io';

import 'package:comms/comms.dart';
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
import 'questionnaire_submission_reactor.dart';
import 'activation_routes.dart';
import 'audit_row.dart';
import 'dev_credential_auth_validator.dart';
import 'diary_entries_debug_handler.dart';
import 'local_push_registry.dart';
import 'local_push_ws_handler.dart';
import 'local_socket_push_channel.dart';
import 'login_routes.dart';
import 'notification_dispatch_reactor.dart';
import 'recall_reactor.dart';
import 'otp_store.dart';
import 'password_reset_code_store.dart';
import 'password_reset_routes.dart';
import 'patient_ingest_handler.dart';
import 'patient_link_handler.dart';
import 'patient_state_handler.dart';
import 'patient_tasks_handler.dart';
import 'portal_view_scopes.dart';
import 'seed_config.dart';
import 'send_questionnaire_handler.dart';
import 'session_cascade_reactor.dart';
import 'session_config.dart';
import 'session_store.dart';
import 'session_token_validator.dart';
import 'sponsor_branding_asset_handler.dart';
import 'sponsor_branding_seed.dart';
import 'sponsor_config_dir.dart';
import 'sponsor_config_seed.dart';
import 'study_config.dart';
import 'user_tier_reactor.dart';
import 'view_permission_namer.dart';
import 'ws_keepalive_interval.dart';

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
  // Test seam: override the process environment (e.g. force PUSH_MODE). null =
  // the normal Platform.environment.
  Map<String, String>? environment,
}) async {
  // 1. Event store (registers role_permission_grants, user_role_scopes,
  //    participant_site_index, portal entry types + framework types).
  final eventStore = await openPortalEventStore(backend: backend);

  // Implements: DIARY-DEV-portal-durable-event-store/C — seed once. The marker is
  //   appended LAST in the seed block under aggregate id 'singleton'; a targeted
  //   per-aggregate read finds it on a seeded store. A fresh store has no marker
  //   -> seed runs.
  final alreadySeeded = await _portalSeedMarkerPresent(backend);

  // 2. Authorization policy from the sponsor role-permissions.yaml.
  final env = environment ?? Platform.environment;
  final sponsorDir = resolveSponsorConfigDir(env);
  final roleGrantsYaml = loadRolePermissionsYaml(sponsorDir);
  final bootstrap = await buildPortalAuthorizationPolicy(
    eventStore: eventStore,
    roleGrantsYaml: roleGrantsYaml,
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

  // RAVE client resolution + ingester construction, declared at function scope
  //     (OUTSIDE the seed gate) so the on-demand /admin/rave-sync handler can
  //     reuse the same `ingester`. Uses the live RaveClient when RAVE_UAT_* env
  //     is present, else a fixed dev fixture (DevSeedRaveClient). The boot-time
  //     `syncAll` that populates the sites_index / participant_record /
  //     participant_site_index views at startup is GATED inside the
  //     `if (!alreadySeeded)` seed block below (see step 4b there).
  // Implements: DIARY-DEV-rave-edc-ingest/A
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
  //   Steps 4 (role assignments) and 4b (boot RAVE sync) are side-effecting
  //   appends; against a durable store they must run exactly once. Read gating is
  //   now modeled as Action permissions seeded from role-permissions.yaml (no
  //   per-boot view-grant appends). The `ingester` is DECLARED above this block
  //   (it is reused later by the on-demand /admin/rave-sync handler); only its
  //   boot-time
  //   `syncAll` is gated here. The marker is appended LAST under aggregate id
  //   'singleton' so the targeted read in _portalSeedMarkerPresent finds it.
  if (!alreadySeeded) {
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
  final roleSeed = _resolveRoleAssignmentSeed();
  await bootstrapRoleAssignments(
    eventStore: eventStore,
    seed: roleSeed,
  );

  // Implements: DIARY-DEV-portal-settings-store/C
  await seedRequireSecondFactor(
    eventStore: eventStore,
    backend: backend,
    raw: Platform.environment['PORTAL_SEED_REQUIRE_2FA'],
  );

  // Implements: DIARY-DEV-sponsor-config-source/A — idempotent per-deployment
  //   sponsor configuration seed (clinical.* + ui.*), like seedRequireSecondFactor.
  await seedSponsorConfig(
    eventStore: eventStore,
    backend: backend,
    // The resolved env (honours the bootstrap's `environment` test seam),
    // not Platform.environment directly — tests can seed sponsor config.
    env: env,
  );

  // Implements: DIARY-DEV-sponsor-branding-source/C+D — idempotent sponsor
  //   branding seed (reads the content overlay; appends only on absence/change).
  //   Runs every boot outside the seed-once gate, like seedRequireSecondFactor.
  await seedSponsorBranding(
    eventStore: eventStore,
    backend: backend,
    sponsorId: Platform.environment['SPONSOR_ID'],
  );

  // Implements: DIARY-DEV-portal-test-account-provisioning/A+B
  await seedTestAccountActivations(
    eventStore: eventStore,
    backend: backend,
    seed: roleSeed,
    password: Platform.environment['PORTAL_DEV_SEED_PASSWORD'],
  );

  // 5. Activation reactor + routes: durable code store (keyed-hash lifecycle
  //    in the event store, so pending links survive restarts/deploys) + email
  //    sender + reactor that watches for user_activation_code_issued events.
  //    Routes are PUBLIC (mounted outside authMiddleware on topRouter).
  // Implements: DIARY-DEV-portal-activation-email-delivery/A+B
  // Implements: DIARY-DEV-portal-activation-code-lifecycle/E+F
  final activationPepper = env['PORTAL_ACTIVATION_CODE_PEPPER'] ?? '';
  if (activationPepper.isEmpty) {
    stderr.writeln(
      '[bootstrap] PORTAL_ACTIVATION_CODE_PEPPER is not set; using the '
      'dev-only default. Deployed environments must deliver a real pepper '
      'via Doppler.',
    );
  }
  final activationStore = ActivationCodeStore(
    eventStore: eventStore,
    pepper: activationPepper.isEmpty
        ? 'dev-activation-pepper-not-for-production'
        : activationPepper,
  );
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
  // Read authMode early so it's available for both the fail-fast check and
  // section 7 below.
  // Implements: DIARY-DEV-portal-session-token/A+B
  // Implements: DIARY-DEV-portal-session-lifecycle/A
  final authMode = env['PORTAL_AUTH_MODE'] ?? 'dev';
  // Per-sponsor HMAC key for linking-code check chars (verified offline by the
  // neutral resolver service). Threaded into generation always; required only
  // in production (session auth), mirroring PORTAL_SESSION_SIGNING_KEY so dev/
  // test boots that don't set it still work.
  // Implements: DIARY-DEV-linking-code-lifecycle/E
  final sponsorResolverKey = env['SPONSOR_RESOLVER_KEY'] ?? '';
  if (authMode == 'session' && sponsorResolverKey.isEmpty) {
    throw StateError(
        'SPONSOR_RESOLVER_KEY is required when PORTAL_AUTH_MODE=session');
  }
  // The sponsor's 2-char linking-code prefix. Required in production (session
  // auth): a missing value silently falling back to a placeholder mints
  // linking codes the mobile diary's SponsorRegistry cannot resolve, so fail
  // fast at boot (serve nothing, wait for a reboot with proper config) rather
  // than come up misconfigured. Dev/test keep a placeholder default, mirroring
  // SPONSOR_RESOLVER_KEY above.
  // Implements: DIARY-DEV-linking-code-lifecycle/E
  final configuredLinkingPrefix = env['SPONSOR_LINKING_PREFIX'];
  if (authMode == 'session' &&
      (configuredLinkingPrefix == null || configuredLinkingPrefix.isEmpty)) {
    throw StateError(
        'SPONSOR_LINKING_PREFIX is required when PORTAL_AUTH_MODE=session');
  }
  final linkingPrefix =
      (configuredLinkingPrefix == null || configuredLinkingPrefix.isEmpty)
          ? 'XX'
          : configuredLinkingPrefix;
  final dispatcher = await buildPortalDispatcher(
      eventStore: eventStore,
      roleGrantsYaml: roleGrantsYaml,
      idempotency: idempotency,
      linkingPrefix: linkingPrefix,
      sponsorResolverKey: sponsorResolverKey);

  // 7. Validator selection — default is dev so the existing admin-1/sc-1
  //    workflow is unchanged. Set PORTAL_AUTH_MODE=session + PORTAL_SESSION_SIGNING_KEY
  //    to enable production session-token authentication.
  final signingKey = Platform.environment['PORTAL_SESSION_SIGNING_KEY'] ?? '';
  final sessionStore = SessionStore();
  // Implements: DIARY-DEV-portal-session-config/A — seed the two session-config
  //   keys idempotently from deployment env before resolving the effective
  //   (clamped) config used by the validator AND the /config/session surface.
  await seedSessionConfig(
    eventStore: eventStore,
    backend: backend,
    env: Platform.environment,
  );

  // Implements: DIARY-DEV-portal-session-config/A — resolve the effective
  //   session-config once at boot so the validator and the /config/session
  //   surface agree on the same values.
  final sessionConfig =
      await resolveSessionConfig(backend, Platform.environment);

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
      idleTimeout: sessionConfig.idleTimeout,
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
    // Emulator host ADVERTISED TO THE BROWSER (the SPA calls
    // FirebaseAuth.useAuthEmulator with this). It must be reachable from the
    // browser's origin, which is NOT the same as the server's reach: in the
    // local-stack the server talks to the emulator over the docker network
    // (FIREBASE_AUTH_EMULATOR_HOST=firebase-emulator:9099), but the host
    // browser can only resolve the published port (localhost:9099). So prefer
    // PORTAL_IDENTITY_EMULATOR_HOST when set (the browser-facing value),
    // falling back to FIREBASE_AUTH_EMULATOR_HOST for deployments where the two
    // coincide.
    'emulatorHost': Platform.environment['PORTAL_IDENTITY_EMULATOR_HOST'] ??
        Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] ??
        '',
    // The client resolves its login-UI mode (Firebase Login/OTP vs dev
    // ConnectScreen) at runtime from this field, so a single web image works
    // against both dev and session-auth deployments.
    // Implements: DIARY-DEV-portal-second-factor-toggle/C
    'authMode': authMode,
  };
  // Implements: DIARY-DEV-portal-login-identity-verification/A+B
  // Implements: DIARY-DEV-portal-session-lifecycle/D
  final loginRouter = buildLoginRouter(
    eventStore: eventStore,
    backend: backend,
    otpStore: otpStore,
    otpSender: otpSender,
    signingKey: signingKey.isEmpty ? 'dev-unused' : signingKey,
    verifyIdToken: verifyIdToken,
    identityConfig: identityConfig,
    sessionConfig: sessionConfig,
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
    linkingPrefix: linkingPrefix,
    sponsorResolverKey: sponsorResolverKey,
  )..start();

  // 7f. User tier reactor — keeps user_tier_index correct by emitting
  //     user_tier_changed whenever a user's SystemOperator assignment changes.
  //     The boot-time reconcile sweeps users whose events landed before the
  //     reactor was listening (the step-4 seeds), so seeded accounts get
  //     their tier row instead of failing closed on every user-scoped action.
  // Implements: DIARY-DEV-operator-tier-authz/A
  final userTierReactor =
      UserTierReactor(eventStore: eventStore, backend: backend)..start();
  await userTierReactor.reconcileAll();

  // 7f-bis. Questionnaire submission reactor — on a diary `<id>_survey`
  //     `finalized` event (whose aggregateId == the questionnaire instance id),
  //     emits a dedicated `questionnaire_submission_received` event on the
  //     instance aggregate so the questionnaire_instance row folds to Ready to
  //     Review. Filters out non-survey diary entries and guards against phantom
  //     rows / Closed-instance regressions.
  // Implements: DIARY-BASE-questionnaire-coordinator-workflow/G
  final questionnaireSubmissionReactor = QuestionnaireSubmissionReactor(
    eventStore: eventStore,
    backend: backend,
  )..start();

  // 7g. Notification dispatch reactor — on a durable portal intent event
  //     (questionnaire assignment + participant lifecycle), looks up the
  //     recipient's active routing token in participant_fcm_tokens and sends a
  //     push via the selected PushChannel directly, recording the outcome as
  //     notification_sent / notification_dispatch_failed (and
  //     fcm_token_deactivated on a dead token).
  //
  //     The transport is bootstrap-selected by PUSH_MODE, mirroring
  //     PORTAL_AUTH_MODE: `fcm` (default) drives FCM HTTP v1; `local` drives the
  //     in-process LocalSocketPushChannel over the diary's /api/v1/user/push WS
  //     (local-stack: no emulator, no live FCM). FCM_ENABLED=false skips the
  //     reactor entirely (a deploy without any push transport). An unknown
  //     PUSH_MODE fails fast at boot.
  // Implements: DIARY-DEV-outgoing-intent-correlation/B+C
  // Implements: DIARY-DEV-pluggable-push-transport/B — PUSH_MODE selects the
  //   transport; unknown value throws.
  final fcmEnabled = (env['FCM_ENABLED'] ?? 'true') != 'false';
  final pushMode = env['PUSH_MODE'] ?? 'fcm';
  FcmChannel? fcmChannel;
  // Built only for PUSH_MODE=local; shared with the /api/v1/user/push WS handler.
  LocalPushRegistry? localPushRegistry;
  PushChannel? pushChannel;
  if (fcmEnabled) {
    switch (pushMode) {
      case 'fcm':
        fcmChannel = FcmChannel(
          projectId: env['FCM_PROJECT_ID'] ?? 'cure-hht-admin',
          consoleMode: (env['FCM_CONSOLE_MODE'] ?? 'false') == 'true',
        );
        pushChannel = fcmChannel;
      case 'local':
        localPushRegistry = LocalPushRegistry();
        pushChannel = LocalSocketPushChannel(localPushRegistry);
        stdout.writeln('portal_server_evs: PUSH_MODE=local — push rides the '
            'diary /api/v1/user/push WS (no FCM)');
      default:
        throw StateError(
            'unknown PUSH_MODE=$pushMode (expected "fcm" or "local")');
    }
  }
  final notificationDispatchReactor = pushChannel != null
      ? (NotificationDispatchReactor(
          eventStore: eventStore,
          backend: backend,
          channel: pushChannel,
        )..start())
      : null;
  // Enriches questionnaire_called_back -> questionnaire_recall_notice so that
  // both the participant-facing recall projection and the push intent have a
  // participant_id + study_event. Always started (not gated on push mode).
  // Implements: DIARY-DEV-outgoing-intent-correlation/A+C
  final recallReactor = RecallReactor(
    eventStore: eventStore,
    backend: backend,
  )..start();

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
    // Implements: DIARY-DEV-view-action-permissions/A+B — read-model
    //   subscriptions gate on the Action permission governing the underlying
    //   data (via portalViewPermissionNamer), not the framework `view:<name>`
    //   default; an unregistered projection fails closed.
    viewPermissionNamer: portalViewPermissionNamer,
    // Keepalive on the /subscriptions WS so an idle/half-open connection is not
    // silently reaped (which would leave the reactive client believing it is
    // still connected and never triggering its lifecycle-driven reconnect).
    // Fixed operational constant — see kWsKeepaliveInterval.
    // Implements: DIARY-DEV-portal-reaction-server/D
    pingInterval: kWsKeepaliveInterval,
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

  // Send-orchestration: POST /admin/questionnaire/send. Reads the
  // questionnaire_instance view + cycle settings, computes the next cycle, and
  // dispatches ACT-QST-001 in-process (EVS actions cannot read projections
  // mid-execute, so the cycle decision is made here). Authorization is enforced
  // by the dispatch (site-scoped portal.questionnaire.send); the authenticated
  // Principal is attached by authMiddleware and read via principalFromContext.
  // Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/D+K
  Future<Response> sendQuestionnaireHandler(Request request) async {
    final principal = principalFromContext(request);
    if (principal == null) {
      return Response.forbidden('unauthenticated');
    }
    final Map<String, Object?> body;
    try {
      final raw = await request.readAsString();
      final decoded = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return Response(400, body: 'expected a JSON object body');
      }
      body = decoded;
    } catch (_) {
      return Response(400, body: 'invalid JSON body');
    }
    return respondToSend(eventStore, dispatcher, principal, body);
  }

  // Audit-trail read, gated to principals holding portal.audit.view. Reads the
  // event log reverse-chronological and maps each event to an audit row via the
  // shared auditRowJson mapper. The authenticated Principal is attached by
  // authMiddleware and read via principalFromContext.
  //
  // Pages server-side via the additive `offset` param (plus the existing
  // `limit`) so the oldest entry stays reachable however large the log grows,
  // and reports the true log size as `total` so the client can render honest
  // pagination. `q` filters the WHOLE log server-side (initiator label /
  // entry type) — filtering only a fetched page would silently hide matches.
  //
  // NOTE: pagination/filtering is a spec gap against DIARY-DEV-audit-log-read
  // (its assertions cover the read and the permission gate, not paging);
  // anchored to that REQ per team convention rather than minting a new one.
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
    final params = request.url.queryParameters;
    final requested = int.tryParse(params['limit'] ?? '') ?? 200;
    final limit = requested.clamp(1, 1000);
    final offset =
        (int.tryParse(params['offset'] ?? '') ?? 0).clamp(0, 1 << 52);
    final query = (params['q'] ?? '').trim();
    // Optional site filter (the Sites page drill-in): site events match by
    // aggregate, participant events join through participant_site_index.
    final siteFilter = (params['site'] ?? '').trim();
    // Optional participant-id filter — the Participant ID search input of the
    // Study Coordinator Audit Log View. Substring match on the row's
    // participant id (participant aggregate id, or the questionnaire instance's
    // participant).
    // Implements: DIARY-GUI-audit-log-study-coordinator/B
    final participantFilter = (params['participant'] ?? '').trim();
    // `view=admin` (the Administrator audit tab) scopes the log to Administrator
    // actions (ACT-USR-*/ACT-ADM-*), excluding system/automation events.
    // Omitted by the Sites drill-in, which needs site/participant events.
    // Same spec-gap anchoring as the q/site filters: scoping the read is
    // anchored to DIARY-DEV-audit-log-read rather than minting a new REQ.
    // Implements: DIARY-DEV-audit-log-read/A
    final adminView = params['view'] == 'admin';
    // `view=mine` (the Study Coordinator audit view) scopes the log to the
    // authenticated principal's OWN participant/questionnaire/site actions —
    // the separation-of-duties scope from DIARY-GUI-audit-log-study-coordinator
    // (Coordinators see only their own audit trail, not peers'). Anchored to
    // DIARY-DEV-audit-log-read like the admin scope.
    // Implements: DIARY-DEV-audit-log-read/A
    final mineView = params['view'] == 'mine';
    final principalUserId = principal is UserPrincipal ? principal.id : '';

    // Resolve email -> display name once per request from users_index, so the
    // log can show names (actor + affected account) instead of emails.
    // Implements: DIARY-GUI-audit-log-common/A
    final nameByEmail = <String, String>{
      for (final r in await backend.findViewRows('users_index'))
        if ((r['aggregateId'] ?? r['email']) is String && r['name'] is String)
          (r['aggregateId'] ?? r['email'])! as String: r['name']! as String,
    };

    final rows = <Map<String, Object?>>[];
    final int total;
    final filtering = adminView ||
        mineView ||
        query.isNotEmpty ||
        siteFilter.isNotEmpty ||
        participantFilter.isNotEmpty;
    if (!filtering) {
      // The sequence counter is the store's contiguous local append counter,
      // so it doubles as the log size without scanning the log.
      total = await backend.readSequenceCounter();
      await for (final e
          in backend.readEventsReverse().skip(offset).take(limit)) {
        rows.add(auditRowJson(e, nameByEmail: nameByEmail));
      }
    } else {
      // A filtered total requires a full reverse scan (the stream keyset-
      // pages its DB reads underneath, so memory stays bounded). Acceptable
      // at current log sizes; revisit if logs reach millions of events.
      // The participant->site lookup is resolved ONCE per request, not per
      // event.
      final participantSite = siteFilter.isEmpty
          ? const <String, String>{}
          : <String, String>{
              for (final row
                  in await backend.findViewRows('participant_site_index'))
                if (row['participant_id'] is String && row['site_id'] is String)
                  row['participant_id']! as String: row['site_id']! as String,
            };
      // Instance->participant join, resolved ONCE per request, so the Study
      // Coordinator view can stamp/filter a Participant ID on questionnaire
      // events that key on the instance id (call-back / finalize / unlock).
      final participantByInstance = (mineView || participantFilter.isNotEmpty)
          ? <String, String>{
              for (final row
                  in await backend.findViewRows('questionnaire_instance'))
                if (row['aggregateId'] is String &&
                    row['participant_id'] is String)
                  row['aggregateId']! as String:
                      row['participant_id']! as String,
            }
          : const <String, String>{};
      bool matches(StoredEvent e) =>
          (!adminView || auditEventIsAdminAction(e)) &&
          (!mineView || auditEventIsOwnActivity(e, principalUserId)) &&
          (query.isEmpty || auditEventMatchesQuery(e, query)) &&
          (siteFilter.isEmpty ||
              auditEventMatchesSite(e, siteFilter, participantSite)) &&
          (participantFilter.isEmpty ||
              auditEventMatchesParticipant(
                  e, participantFilter, participantByInstance));
      var matched = 0;
      await for (final e in backend.readEventsReverse()) {
        if (!matches(e)) continue;
        if (matched >= offset && rows.length < limit) {
          rows.add(auditRowJson(e,
              nameByEmail: nameByEmail,
              participantByInstance: participantByInstance));
        }
        matched++;
      }
      total = matched;
    }
    return Response.ok(
      jsonEncode(<String, Object?>{
        'rows': rows,
        'count': rows.length,
        'total': total,
        'offset': offset,
      }),
      headers: const {'Content-Type': 'application/json'},
    );
  }

  // Read-only study-configuration aggregate for the portal's Study
  // Settings page. Gated on the ACT-ADM-001 read permission
  // (portal.admin.view_settings — granted per the sponsor's permissions
  // matrix, e.g. Administrator + SystemOperator). Unimplemented
  // parameters are absent from the payload by design — see
  // study_config.dart.
  // Implements: DIARY-PRD-action-inventory/A
  Future<Response> studyConfigHandler(Request request) async {
    const viewSettingsPermission = 'portal.admin.view_settings';
    final principal = principalFromContext(request);
    final Iterable<String> perms;
    if (principal is UserPrincipal) {
      final eff = await policy.effectivePermissionsFor(principal);
      perms = eff.rolePermissions.map((p) => p.name);
    } else {
      perms = const <String>[];
    }
    if (!perms.contains(viewSettingsPermission)) {
      return Response.forbidden('requires $viewSettingsPermission');
    }
    final body = await studyConfigJson(
      backend: backend,
      env: env,
      otpStore: otpStore,
      passwordResetStore: passwordResetStore,
    );
    return Response.ok(
      jsonEncode(body),
      headers: const {'Content-Type': 'application/json'},
    );
  }

  // Debug-only diary-entries read, gated to portal.diary.view_entries (SC).
  Future<Response> diaryEntriesDebugHandler(Request request) async {
    final principal = principalFromContext(request);
    final Iterable<String> perms;
    if (principal is UserPrincipal) {
      final eff = await policy.effectivePermissionsFor(principal);
      perms = eff.rolePermissions.map((p) => p.name);
    } else {
      perms = const <String>[];
    }
    if (!perms.contains(diaryDebugViewPermission)) {
      return Response.forbidden('requires $diaryDebugViewPermission');
    }
    return respondWithDiaryEntries(
        eventStore, request.url.queryParameters['participant']);
  }

  final httpRouter = Router()
    ..get('/me', handlers.me)
    ..post('/actions', handlers.actions)
    // The client's permission source reads this to drive PermissionGate; without
    // it every gate fails closed (no widgets render, for any role).
    ..get('/permissions/snapshot', handlers.permissions)
    ..get('/audit', auditHandler)
    // Study Settings read — inside the authed pipeline (unlike the public
    // /config/identity + /config/session login surfaces); the /config/
    // prefix is already in the nginx proxy allow-list.
    ..get('/config/study', studyConfigHandler)
    // Under /admin/ so the reverse proxy's `^~ /admin/` block forwards it to the
    // dart backend (a bare /debug/ prefix is not in the nginx proxy allow-list,
    // so it would be served the SPA instead of reaching this handler).
    ..get('/admin/diary-entries', diaryEntriesDebugHandler)
    ..post('/admin/rave-sync', raveSyncHandler)
    // Send-orchestration for the coordinator's "Send Now" / "Start Next Cycle".
    // Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
    // Implements: DIARY-BASE-questionnaire-cycle-tracking/D+K
    ..post('/admin/questionnaire/send', sendQuestionnaireHandler)
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

  // Patient tasks (public; in-handler patient-JWT auth): the participant's active
  // assigned questionnaires, polled by the diary to discover them.
  // Implements: DIARY-PRD-questionnaire-system/B+C+D
  final tasksHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(patientTasksHandler(eventStore: eventStore));

  // Sponsor branding asset bytes (public-at-the-router; in-handler patient-JWT
  // auth, same gate as /user/state). Serves the logo bytes the diary fetches by
  // the manifest pointer; the role is resolved from the manifest + a fixed
  // role->path constant (no path is built from the request string).
  // Implements: DIARY-DEV-sponsor-branding-source/E+F+G
  final brandingAssetHandler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(sponsorBrandingAssetHandler(eventStore: eventStore));

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
    ..options('/config/session', loginHandler)
    ..get('/config/session', loginHandler)
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
    ..get('/api/v1/user/state', stateHandler)
    // Patient tasks: active assigned questionnaires (public; JWT-gated in-handler).
    ..options('/api/v1/user/tasks', tasksHandler)
    ..get('/api/v1/user/tasks', tasksHandler)
    // Sponsor branding asset bytes (public-at-the-router; JWT-gated in-handler).
    // Implements: DIARY-DEV-sponsor-branding-source/E+F+G
    ..options('/api/v1/sponsor/branding/asset/<role>', brandingAssetHandler)
    ..get('/api/v1/sponsor/branding/asset/<role>', brandingAssetHandler);

  // Local-stack push transport (PUSH_MODE=local only): the participant-scoped
  // WS the diary holds open to receive real-time pushes. In-band participant-JWT
  // auth; outside the HTTP-auth pipeline like /subscriptions.
  // Implements: DIARY-DEV-pluggable-push-transport/C
  if (localPushRegistry != null) {
    topRouter.get(
      '/api/v1/user/push',
      localPushWsHandler(registry: localPushRegistry),
    );
  }

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

  // Resolve the version manifest once at boot (not per-request): the baked
  // `/app/VERSIONS` (portal_server_evs=<semver>+N, server_commit=<sha>,
  // portal_ui_version, portal_deployment — written by the image build) plus the
  // deploy-event identity injected at deploy time as Cloud Run env vars. `/health`
  // reports ALL of it; the UI shows the deploy counter and pops the rest.
  final versions = resolveVersions();

  // Public liveness/readiness for the container start gate + deploy smoke check.
  Response healthResponse(Request _) => Response.ok(
        jsonEncode(<String, Object?>{
          'status': 'ok',
          'service': 'portal_server_evs',
          'versions': versions,
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
    await questionnaireSubmissionReactor.stop();
    await notificationDispatchReactor?.stop();
    await recallReactor.stop();
    fcmChannel?.dispose();
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

/// Build the `/health` version manifest: the build-baked `/app/VERSIONS`
/// (key=value lines: `portal_server_evs=<semver>+N`, `server_commit=<sha>`,
/// `portal_ui_version=<semver>+<sha>`, `portal_deployment=<sponsor>+<sha>`)
/// merged with the deploy-event identity injected by the sponsor deploy
/// workflow as Cloud Run env vars (`PORTAL_DEPLOY_SEQ`, `PORTAL_DEPLOY_SHA`).
/// Best-effort: a missing file or unset vars just yield a smaller map (local
/// and test runs have neither). Resolved once at boot, not per-request.
/// Public (and parameterized) so tests can exercise the parse/merge directly.
Map<String, Object?> resolveVersions({
  String manifestPath = '/app/VERSIONS',
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final out = <String, Object?>{};
  final file = File(manifestPath);
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final sep = line.indexOf('=');
      if (sep <= 0) continue;
      out[line.substring(0, sep).trim()] = line.substring(sep + 1).trim();
    }
  }
  final seq = env['PORTAL_DEPLOY_SEQ']?.trim();
  if (seq != null && seq.isNotEmpty) {
    out['deploy'] = seq;
  }
  final deploySha = env['PORTAL_DEPLOY_SHA']?.trim();
  if (deploySha != null && deploySha.isNotEmpty) {
    out['deploy_commit'] = deploySha;
  }
  return out;
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
    // CRA at site-2 (mirrors cra@reference.local in the reference sponsor
    // seed) so CRA-role flows and grants are exercisable in local/test runs.
    RoleAssignmentSeedEntry(
      userId: 'cra-1',
      role: 'CRA',
      scope: BoundScope(class_: 'site', value: 'site-2'),
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

/// Implements: DIARY-DEV-portal-test-account-provisioning/A+B — dev/test only.
///   When PORTAL_DEV_SEED_PASSWORD is set, ensure each seed-user email has an
///   Identity Platform account (idempotent provision) AND an active users_index
///   row stamped with its firebase_uid, so the account logs in under real
///   session auth without the activation magic-link. Guarded by the env (prod
///   never sets it); a provisioning failure is logged and never crashes boot.
typedef IdpProvisioner = Future<LookupOrProvisionResult> Function(
    {required String email,
    required String displayName,
    required String password});

Future<void> seedTestAccountActivations({
  required EventStore eventStore,
  required StorageBackend backend,
  required RoleAssignmentSeed seed,
  required String? password,
  IdpProvisioner? provision,
}) async {
  final pw = password?.trim();
  if (pw == null || pw.isEmpty) return;
  final provisioner = provision ?? IdentityAdmin.lookupOrProvisionByEmail;
  final emails = <String>{for (final e in seed.entries) e.userId}
    ..removeWhere((e) => !e.contains('@'));
  final userRows = await backend.findViewRows('users_index');
  for (final email in emails) {
    try {
      final prov =
          await provisioner(email: email, displayName: email, password: pw);
      final alreadyActive = userRows.any((r) =>
          r['email'] == email &&
          r['firebase_uid'] == prov.uid &&
          r['status'] == 'active');
      if (alreadyActive) continue;
      final hasRow = userRows.any((r) => r['email'] == email);
      if (!hasRow) {
        await eventStore.append(
          entryType: 'user_created',
          aggregateType: 'portal_user',
          aggregateId: email,
          eventType: 'user_created',
          data: <String, Object?>{
            'email': email,
            'name': email,
            'roles': const <String>[],
            'sites': const <String>[],
            'status': 'pending',
            'created_by': 'portal-test-seed',
          },
          initiator: const AutomationInitiator(service: 'portal-test-seed'),
        );
      }
      await eventStore.append(
        entryType: 'user_activated',
        aggregateType: 'portal_user',
        aggregateId: email,
        eventType: 'user_activated',
        data: <String, Object?>{
          'firebase_uid': prov.uid,
          'email': email,
          'status': 'active',
          'activated_at': DateTime.now().toUtc().toIso8601String(),
        },
        initiator: const AutomationInitiator(service: 'portal-test-seed'),
      );
    } catch (e, st) {
      stderr.writeln(
          'seedTestAccountActivations: provisioning $email failed (continuing): $e\n$st');
    }
  }
}

/// Implements: DIARY-DEV-portal-settings-store/C — config-driven, idempotent
///   boot seed of the require_second_factor setting. Emits a single
///   portal_setting_changed only when [raw] == 'false' AND no value exists yet.
Future<void> seedRequireSecondFactor({
  required EventStore eventStore,
  required StorageBackend backend,
  required String? raw,
}) async {
  if (raw?.trim().toLowerCase() != 'false') {
    return; // only an explicit false seeds
  }
  final rows = await backend.findViewRows('portal_settings');
  final exists = rows.any((r) => r['key'] == 'require_second_factor');
  if (exists) {
    return;
  }
  await eventStore.append(
    entryType: 'portal_setting_changed',
    aggregateType: 'portal_setting',
    aggregateId: 'require_second_factor',
    eventType: 'portal_setting_changed',
    data: const <String, Object?>{
      'key': 'require_second_factor',
      'value': false
    },
    initiator: const AutomationInitiator(service: 'portal-settings-seed'),
  );
}

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
