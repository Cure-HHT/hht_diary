import 'dart:async';
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:portal_ui_evs/src/reset_link.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'package:portal_screens/portal_screens.dart';

import 'activation_link.dart';
import 'auth_bootstrap.dart';
import 'auth_scaffold.dart';
import 'activation_screen.dart';
import 'audit_log_screen_binding.dart';
import 'connect_screen.dart';
import 'connection_status_banner.dart';
import 'firebase_auth_client.dart';
import 'identity_config.dart';
import 'login_screen.dart';
import 'nav_sections.dart';
import 'role_selection_screen.dart';
import 'role_selector.dart';
import 'password_reset_screen.dart';
import 'session_activity_listener.dart';
import 'session_config.dart';
import 'session_timeout_controller.dart';
import 'stale_client.dart';
import 'participants_screen_binding.dart';
import 'rave_sync_screen_binding.dart';
import 'sites_screen_binding.dart';
import 'study_settings_binding.dart';
import 'update_available_banner.dart';
import 'users_screen_binding.dart';
import 'web_platform.dart';
// Legacy screens still referenced for the destinations the redesign hasn't
// touched yet (Sites / Participants / RAVE Sync) — they pass through unchanged
// in this partial-integration phase (Phase 6.5).

/// Optional compile-time override for the portal server URL. Set via
/// `--dart-define=PORTAL_SERVER_URL=...` for `flutter run` local dev (points at
/// the standalone server on :8084). Empty by default.
const String _serverUrlOverride = String.fromEnvironment(
  'PORTAL_SERVER_URL',
  defaultValue: '',
);

/// The portal server base URL.
///
/// In the deployed / local-stack bundle the SPA is served by nginx and must
/// talk to its OWN browser origin: the reaction client builds WS/HTTP URLs via
/// `baseUrl.replace(...)`, which needs an absolute base carrying a host. A
/// single bundle serves every environment, so the origin is resolved at RUNTIME
/// from [Uri.base] rather than baked in. When the compile-time override is set
/// (local dev), it wins.
final String _serverUrl = _serverUrlOverride.isNotEmpty
    ? _serverUrlOverride
    : Uri.base.origin;

/// `<semver>+<build_id>` of THIS web bundle, stamped at image-build time via
/// `--dart-define=APP_VERSION` (same value as main.dart's `appVersion`). This is
/// the bundle's own full self-report — unlike `version.json`, which Flutter
/// generates from the now-bare pubspec and so omits the build id. Empty in a
/// local `flutter run` without the define.
const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '',
);

class PortalEvsApp extends StatefulWidget {
  const PortalEvsApp({super.key, this.web = const WebPlatform()});

  /// Browser seam for service-worker eviction, full-document reload, and the
  /// once-per-session auto-reload guard. Defaults to the real (web) impl;
  /// tests inject a fake to assert reload/guard behaviour without a browser.
  final WebPlatform web;

  @override
  State<PortalEvsApp> createState() => _PortalEvsAppState();
}

class _PortalEvsAppState extends State<PortalEvsApp> {
  late final RemoteScope _scope;
  late final StreamSubscription<AuthStatus> _authSub;
  AuthStatus _status = const NotAuthenticated();

  /// Root navigator handle so auth transitions can clear stacked routes.
  /// Swapping [MaterialApp.home] only replaces the root route's child —
  /// any routes pushed above it (dialogs, the OTP/forgot-password pushes,
  /// or a phantom barrier left by the reload-while-dialog-open history
  /// quirk) stay mounted ON TOP of the next session's UI and silently eat
  /// every click. Popping to the first route on each auth edge guarantees
  /// a fresh session never starts under a leftover modal barrier.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Pops every route above the root. Safe to call when nothing is
  /// stacked (no-op).
  void _popToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Server version manifest from `GET /health` `.versions`. Fetched at boot
  /// and on each transport reconnect; passed down to [_HomeShell] so the
  /// "Deploy #N" label + version popup keep working from a single source.
  Map<String, Object?> _serverVersions = const <String, Object?>{};

  /// Whether the non-blocking "new version available" banner is shown. Set only
  /// for an authenticated User (and as the login-screen loop-guard fallback);
  /// the login screen otherwise auto-reloads rather than prompting.
  bool _updateAvailable = false;

  /// Transport-status subscription used to re-check the deployed version on
  /// each reconnect — a deploy drains the old Cloud Run revision, dropping the
  /// WS; the reconnect lands on the new revision, where `/health` reports the
  /// new `portal_ui_version`. No polling timer is needed.
  StreamSubscription<ConnectionStatus>? _connSub;
  ConnectionStatus _lastConn = const Disconnected();

  /// Login-UI mode, resolved at runtime from `GET /config/identity` (`authMode`).
  /// Null while the config is still loading; `true` renders the Firebase
  /// Login/OTP screens, `false` renders the dev ConnectScreen. Resolving at
  /// runtime lets one web image serve both dev and session-auth deployments.
  // Implements: DIARY-DEV-portal-emulator-bootstrap/C
  bool? _sessionAuth;

  /// True when session-mode Firebase/emulator init failed. Renders an explicit
  /// error+reload rather than a login pointed at the wrong (production)
  /// Firebase — a silently-failed emulator connect was the root cause of the
  /// flaky local-stack logins. See [_resolveAuthMode].
  // Implements: DIARY-DEV-portal-emulator-bootstrap/C
  bool _authInitFailed = false;

  /// Set to true after the user taps "Back to Login" on the password-reset done
  /// view so [build] falls through to the normal auth switch instead of
  /// re-showing the reset screen (the ?reset= code is still in the URL).
  bool _resetDismissed = false;
  bool _activationDismissed = false;

  /// True once a multi-role user has picked their starting role on the
  /// post-login role-selection step. Single-role users never see that step.
  /// Reset on every fresh login / disconnect so the choice is per-session.
  // Implements: DIARY-GUI-role-switching/A
  bool _roleConfirmed = false;

  /// The current identity credential.
  ///
  /// In dev mode: the bare userId (or `userId|role` when a specific role was
  /// requested). In session mode: the opaque Firebase session token (or
  /// `token|role` with an active-role claim).
  ///
  /// Null when not authenticated.
  String? _identityCredential;

  /// The authenticated user's human name, supplied by the login response so the
  /// role-selection screen can greet them by name rather than by email (the
  /// session principal carries only the email). Null when the server supplied
  /// no name or the session was restored without a fresh login — the welcome
  /// line then falls back to the email. Reset on disconnect.
  // Implements: DIARY-GUI-role-switching/H
  String? _displayName;

  /// The client soft-timer mirroring the server idle window. Non-null only in
  /// session-auth mode while Authenticated.
  SessionTimeoutController? _timeoutController;

  /// Guards [_syncTimeoutController]'s async create branch: it awaits
  /// `fetchSessionConfig` while `_timeoutController` is still null, so without
  /// this flag two rapid `Authenticated` emissions could each pass the
  /// null-check and create (and leak) a second controller + its timers.
  bool _timerInitInFlight = false;

  @override
  void initState() {
    super.initState();
    _scope = RemoteScope(baseUrl: Uri.parse(_serverUrl));
    _status = _scope.authSession.current;
    _authSub = _scope.authSession.stream.listen((next) {
      if (!mounted) return;
      // Auth edge (login OR logout/expiry): clear any routes stacked
      // above home before the new surface renders, so leftover dialog
      // barriers can never block the next session.
      if ((next is Authenticated) != (_status is Authenticated)) {
        _popToRoot();
      }
      setState(() => _status = next);
      unawaited(_syncTimeoutController(next));
    });
    // Re-check the deployed version whenever the transport (re)connects. A
    // deploy drops the WS (old revision drains); the reconnect lands on the new
    // revision and a `/health` read surfaces the new `portal_ui_version`.
    _lastConn = _scope.connectionStatus;
    _connSub = _scope.connectionStatusStream.listen((status) {
      final reconnected = status is Connected && _lastConn is! Connected;
      _lastConn = status;
      if (reconnected) unawaited(_checkServerVersion());
    });
    // One-shot boot check: catches a stale bundle already loaded (e.g. served
    // by a legacy service worker) and seeds the version manifest for the popup.
    // The ONLY call site allowed to auto-reload — nothing can have been typed
    // this early. Later checks (reconnect, sign-in) banner instead.
    unawaited(_checkServerVersion(atBoot: true));
    _resolveAuthMode();
  }

  /// Fetch `/health`, update the version manifest, and act on a version
  /// mismatch. Event-driven (boot, reconnect, login attempt) — there is no
  /// polling timer. Only the boot call site sets [atBoot]: an automatic
  /// reload is free only before the *User* could have typed anything. A
  /// deploy landing under an open login tab (reconnect) or discovered at
  /// sign-in must never reload — it would wipe typed credentials or discard
  /// the just-established session, making the deploy look like a failed
  /// login (the repeatedly-reported "can't log in: version out of date").
  // Implements: DIARY-BASE-portal-stale-client-reload/A+B+C
  Future<void> _checkServerVersion({bool atBoot = false}) async {
    Map<String, Object?>? versions;
    try {
      // /health is public + same-origin; `.versions` carries portal_ui_version
      // (the deployed bundle id), the deploy counter, and the rest.
      final res = await http.get(Uri.parse('$_serverUrl/health'));
      if (res.statusCode != 200) return;
      final json = jsonDecode(res.body) as Map<String, Object?>;
      final v = json['versions'];
      if (v is Map) versions = Map<String, Object?>.from(v);
    } catch (_) {
      // Best-effort: an unreachable /health leaves the popup on the bundle
      // version and never trips the (empty-guarded) staleness check.
      return;
    }
    if (versions == null || !mounted) return;
    final action = decideStaleClientAction(
      clientVersion: _appVersion,
      serverVersions: versions,
      authenticated: _status is Authenticated,
      atBoot: atBoot,
      autoReloadAlreadyTried: widget.web.autoReloadAlreadyTried,
    );
    switch (action) {
      case StaleClientAction.none:
        // Matched (or post-reload) build: re-arm the auto-reload guard so a
        // later deploy in the same tab can auto-reload again.
        widget.web.clearAutoReloadGuard();
        setState(() {
          _serverVersions = versions!;
          _updateAvailable = false;
        });
      case StaleClientAction.banner:
        setState(() {
          _serverVersions = versions!;
          _updateAvailable = true;
        });
      case StaleClientAction.reload:
        setState(() => _serverVersions = versions!);
        widget.web.markAutoReloadTried();
        widget.web.reloadPage();
    }
  }

  /// User-initiated reload from the update banner (authenticated path). Not
  /// guarded — the User chose to reload, so it should always proceed.
  // Implements: DIARY-BASE-portal-stale-client-reload/A
  void _reloadForUpdate() => widget.web.reloadPage();

  /// Resolves the login-UI mode from the server's identity config. In session
  /// mode, Firebase (and, when the deployment reports one, the auth emulator)
  /// MUST be wired before the login surface renders. On an emulator deployment
  /// the persisted Firebase Auth IndexedDB is wiped BEFORE init so the emulator
  /// connect binds cleanly instead of silently falling through to production —
  /// the flaky-local-login root cause (flutterfire #9528). The login appears
  /// only on `sessionReady`; a genuine init failure surfaces an explicit error
  /// rather than a prod-pointed login.
  // Implements: DIARY-DEV-portal-emulator-bootstrap/A+B+C
  Future<void> _resolveAuthMode() async {
    final outcome = await resolveAuthBootstrap(
      fetchConfig: () => fetchIdentityConfig(_serverUrl),
      initFirebase: initFirebaseWithConfig,
      clearAuthDb: widget.web.clearFirebaseAuthDb,
    );
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case AuthBootstrapOutcome.dev:
          _sessionAuth = false;
        case AuthBootstrapOutcome.sessionReady:
          _sessionAuth = true;
        case AuthBootstrapOutcome.failed:
          _authInitFailed = true;
      }
    });
  }

  @override
  void dispose() {
    _timeoutController?.dispose();
    unawaited(_authSub.cancel());
    unawaited(_connSub?.cancel());
    unawaited(_scope.dispose());
    super.dispose();
  }

  /// Dev connect: called by [ConnectScreen] with a bare userId (optionally
  /// `userId|role` for a power-user initial-role choice). The STORED identity
  /// credential is kept bare (role claim stripped) so a later role switch
  /// appends a single `|role`; the typed value (with any role) is used for the
  /// initial connect.
  void _onConnect(String identity) {
    // Sign-in on a stale bundle completes; staleness surfaces via the
    // banner only (a reload here would discard this very login).
    // Implements: DIARY-BASE-portal-stale-client-reload/B
    unawaited(_checkServerVersion());
    setState(() {
      _identityCredential = identity.split('|').first;
      _roleConfirmed = false;
    });
    _scope.authSession.setCredential(identity);
    // Re-auth the WS under the new identity. A logout leaves the previous
    // user's socket open until its idle-close grace; logging straight back in
    // as a DIFFERENT user would otherwise subscribe on that stale-principal
    // socket and be denied (view_permission_denied). reconnect() is a no-op
    // when no socket is open (fresh load), so this is safe on first login too.
    unawaited(_scope.reconnect());
  }

  /// Session auth login: called by [LoginScreen] when the user authenticates
  /// with Firebase. Stores the session token so [_HomeShell] can pass it to
  /// [RoleSelector].
  void _onSession(String token, {String? displayName}) {
    // Sign-in on a stale bundle completes; staleness surfaces via the
    // banner only (a reload here would discard this very login).
    // Implements: DIARY-BASE-portal-stale-client-reload/B
    unawaited(_checkServerVersion());
    setState(() {
      _identityCredential = token;
      // Implements: DIARY-GUI-role-switching/H
      _displayName = displayName;
      _roleConfirmed = false;
    });
    _scope.authSession.setCredential(token);
    // Re-auth the WS under the new identity — see [_onConnect]. Without this, a
    // logout→login as a different user can subscribe on the previous user's
    // still-open socket and be denied (view_permission_denied).
    unawaited(_scope.reconnect());
  }

  /// Switches the active role by encoding a per-request claim into the
  /// credential (`credential|role`) and re-establishing the authorization
  /// context — both the read-side snapshot AND the live WS data scope — under
  /// it. Works in dev mode (credential = bare userId) and session mode
  /// (credential = session token).
  ///
  /// Three ordered steps, each load-bearing:
  ///
  /// 1. [setCredential] swaps the credential the client sends and fires GET /me,
  ///    updating the [Principal] so the header reflects the new active role.
  /// 2. [PermissionSource.refresh] re-reads `/permissions/snapshot` under the
  ///    new claim and emits it IN PLACE (no transient `null`), so the nav tabs
  ///    and every `PermissionGate` re-gate WITHOUT a "not-loaded" flash. Being
  ///    an AWAITED authenticated HTTP round-trip, it also refreshes the server
  ///    idle window — so the reconnect below re-auths against a freshly-touched,
  ///    live session and can't race the idle check into a spurious 4001 close
  ///    (the original bug: GET /me fired unawaited and reconnect raced ahead).
  /// 3. [reconnect] re-auths the WS under the new role so live view
  ///    subscriptions (e.g. participants) re-scope to the new role's row-level
  ///    access. Without it the socket keeps the previous role's principal and
  ///    the server denies / over-filters the new role's data.
  ///
  // Implements: DIARY-GUI-role-switching/E+F
  Future<void> _onRoleSelected(String role) async {
    final credential = _identityCredential;
    if (credential == null) return;
    _scope.authSession.setCredential('$credential|$role');
    await _scope.permissionSource.refresh();
    await _scope.reconnect();
  }

  // Implements: DIARY-DEV-portal-session-lifecycle/A
  Future<void> _disconnect() async {
    // POST /logout only in session mode — the dev credential is a bare userId,
    // not a parseable session token, and there is no server-side session to
    // terminate.
    if (_sessionAuth == true) {
      final credential = _identityCredential;
      if (credential != null) {
        try {
          await http.post(
            Uri.parse('$_serverUrl/logout'),
            headers: {'Authorization': 'Bearer $credential'},
          );
        } catch (_) {
          // best-effort: clear locally even if the server call fails
        }
      }
    }
    setState(() {
      _identityCredential = null;
      _displayName = null;
      _roleConfirmed = false;
    });
    _scope.authSession.setCredential(null);
  }

  /// Creates the soft-timer on first Authenticated (session mode), tears it down
  /// otherwise. Idempotent per status edge.
  // Implements: DIARY-GUI-portal-session-expiry/A
  Future<void> _syncTimeoutController(AuthStatus status) async {
    final wantTimer = status is Authenticated && _sessionAuth == true;
    if (wantTimer && _timeoutController == null && !_timerInitInFlight) {
      _timerInitInFlight = true;
      try {
        final cfg = await fetchSessionConfig(_serverUrl);
        if (!mounted || _scope.authSession.current is! Authenticated) return;
        final c = SessionTimeoutController(
          idleTimeout: cfg.idle,
          warningLead: cfg.warning,
          onKeepAlive: _keepAlive,
          onExpired: _onSessionExpired,
        )..start();
        setState(() => _timeoutController = c);
      } finally {
        _timerInitInFlight = false;
      }
    } else if (!wantTimer && _timeoutController != null) {
      _timeoutController!.dispose();
      setState(() => _timeoutController = null);
    }
  }

  /// Throttled keep-alive: any authed request resets the server idle window; a
  /// dedicated lightweight endpoint keeps the intent explicit.
  // Implements: DIARY-DEV-portal-session-lifecycle/E
  Future<void> _keepAlive() async {
    final credential = _identityCredential;
    if (credential == null) return;
    try {
      await http.post(
        Uri.parse('$_serverUrl/keepalive'),
        headers: {'Authorization': 'Bearer $credential'},
      );
    } catch (_) {
      // Best-effort; the server stays authoritative on the next real request.
    }
  }

  /// Countdown hit zero: force a reconnect so the server's idle check trips and
  /// the existing Expired() surface shows (the controller's expiry grace
  /// guarantees we are past the server's strict idle boundary).
  // Implements: DIARY-GUI-portal-session-expiry/C
  Future<void> _onSessionExpired() async {
    try {
      await _scope.reconnect();
    } catch (_) {
      // If reconnect can't run, the next real request still trips the server.
    }
  }

  /// Wraps [child] in the activity listener when the soft-timer is active;
  /// otherwise returns it unchanged (dev mode / timer still loading). The
  /// in-dialog "Sign out" cancels the timer (reactively dismissing the dialog)
  /// then disconnects.
  Widget _wrapWithTimeout(Widget child) {
    final c = _timeoutController;
    if (c == null) return child;
    return SessionActivityListener(
      controller: c,
      onSignOut: () {
        c.cancel();
        _disconnect();
      },
      child: child,
    );
  }

  /// Shown while the login-UI mode is still being resolved from the server.
  Widget _loadingScaffold() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  /// Shown when session-mode auth init exhausted its retries: an explicit,
  /// recoverable error instead of a login pointed at the wrong Firebase.
  Widget _authInitFailedScaffold() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBanner(
              severity: AppBannerSeverity.error,
              message:
                  "Couldn't reach the authentication service. Check your "
                  'connection and reload.',
              semanticId: 'auth-init-failed',
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Reload',
              onPressed: widget.web.reloadPage,
              semanticId: 'auth-init-reload',
            ),
          ],
        ),
      ),
    ),
  );

  /// The Firebase email/password login surface (session-auth mode).
  /// [notice] surfaces a non-error message inside the card (e.g. the
  /// session-ended prompt).
  Widget _loginScreen({String? notice}) => LoginScreen(
    serverUrl: _serverUrl,
    authClient: RealFirebaseAuthClient(),
    onSession: _onSession,
    notice: notice,
    // The bundle's own APP_VERSION — carries the +local-XXXXXX build id
    // on local-stack builds, so the login screen names the exact build.
    appVersion: _appVersion,
  );

  /// Builds the authenticated home. A multi-role user first sees the
  /// role-selection step (until they pick a starting role); single-role users
  /// and users who've already chosen go straight to the dashboard shell.
  // Implements: DIARY-GUI-role-switching/A+B
  Widget _authenticatedHome(Principal principal) {
    if (principal is UserPrincipal &&
        roleSelectorVisible(principal.roles) &&
        !_roleConfirmed) {
      // Greet by name when the login response supplied one; otherwise fall
      // back to the account identifier (the email the principal carries).
      // Implements: DIARY-GUI-role-switching/H
      return RoleSelectionScreen(
        userName: (_displayName?.trim().isNotEmpty ?? false)
            ? _displayName!.trim()
            : principal.userId,
        roles: principal.roles,
        activeRole: principal.activeRole,
        onRoleSelected: (role) async {
          await _onRoleSelected(role);
          if (mounted) setState(() => _roleConfirmed = true);
        },
        onBackToLogin: _disconnect,
      );
    }
    return _wrapWithTimeout(
      _HomeShell(
        principal: principal,
        identityCredential: _identityCredential,
        serverVersions: _serverVersions,
        onDisconnect: _disconnect,
        onRoleSelected: _onRoleSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the browser URL carries ?code=, show the public activation screen
    // instead of the normal authed shell. _activationDismissed is flipped when
    // the user finishes activating (onBackToLogin), so build() falls through to
    // the normal auth switch — i.e. the login screen — rather than getting
    // stuck on the activation page (the ?code stays in the URL).
    final activationCode = activationCodeFromUri(Uri.base);
    if (activationCode != null && !_activationDismissed) {
      return MaterialApp(
        // The public pages render design-kit widgets, whose theme
        // extensions (AppSemanticColors etc.) exist only on buildAppTheme —
        // a bare default-theme MaterialApp grey-boxes them in release.
        theme: buildAppTheme(
          font: AppFontFamily.inter,
          brightness: Brightness.light,
        ),
        home: ActivationScreen(
          serverUrl: _serverUrl,
          code: activationCode,
          onBackToLogin: () => setState(() => _activationDismissed = true),
        ),
      );
    }

    // If the browser URL carries ?reset=, show the public password-reset screen.
    // _resetDismissed is flipped by onBackToLogin so build() falls through to
    // the normal auth switch after the user confirms the password change.
    final resetCode = resetCodeFromUri(Uri.base);
    if (resetCode != null && !_resetDismissed) {
      return MaterialApp(
        // Same theme requirement as the activation mount above.
        theme: buildAppTheme(
          font: AppFontFamily.inter,
          brightness: Brightness.light,
        ),
        home: PasswordResetScreen(
          serverUrl: _serverUrl,
          code: resetCode,
          onBackToLogin: () => setState(() => _resetDismissed = true),
        ),
      );
    }

    final Widget home = _authInitFailed
        ? _authInitFailedScaffold()
        : switch (_status) {
            Authenticated(:final principal) => _authenticatedHome(principal),
            Expired() => switch (_sessionAuth) {
              null => _loadingScaffold(),
              true => _loginScreen(
                notice: 'Session ended — please sign in again.',
              ),
              false => Scaffold(
                body: ConnectScreen(
                  onConnect: _onConnect,
                  message: 'Session ended — reconnect.',
                  serverUrl: _serverUrl,
                ),
              ),
            },
            NotAuthenticated() => switch (_sessionAuth) {
              null => _loadingScaffold(),
              true => _loginScreen(),
              false => Scaffold(
                body: ConnectScreen(
                  onConnect: _onConnect,
                  serverUrl: _serverUrl,
                ),
              ),
            },
          };
    return ReActionScope(
      scope: _scope,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Cure HHT Study Portal',
        // CUR-1450: adopt the diary_design_system brand (Carina blue +
        // Inter typography). Sites / Participants / RAVE Sync re-theme
        // passively; their layouts stay until they get their own redesign
        // round.
        theme: buildAppTheme(
          font: AppFontFamily.inter,
          brightness: Brightness.light,
        ),
        // Non-blocking "new version available" strip above whatever home is
        // showing (authenticated shell, or the login screen as a loop-guard
        // fallback). Authenticated users are prompted, never auto-reloaded.
        // Implements: DIARY-BASE-portal-stale-client-reload/A
        home: UpdateAvailableBanner(
          visible: _updateAvailable,
          onReload: _reloadForUpdate,
          child: home,
        ),
      ),
    );
  }
}

/// Nav shell shown once connected. A [NavigationRail] swaps between the
/// reactive screens the ACTIVE ROLE may use. Each destination declares the same
/// permission its screen self-gates on; the nav item is shown only when the
/// active role's effective permissions hold it, so a role never sees — nor
/// subscribes to — a section it cannot use. Visibility reacts to a role switch
/// via the same `PermissionSource` stream `PermissionGate` consumes.
class _HomeShell extends StatefulWidget {
  const _HomeShell({
    required this.principal,
    required this.onDisconnect,
    required this.onRoleSelected,
    required this.serverVersions,
    this.identityCredential,
  });

  final Principal principal;
  final VoidCallback onDisconnect;

  /// Server `/health` `.versions` manifest, fetched + kept fresh by
  /// [_PortalEvsAppState] (boot + each reconnect). Drives the "Deploy #N"
  /// app-bar label and the version-details popup.
  final Map<String, Object?> serverVersions;

  /// Called with the chosen role string so the parent can update the
  /// credential claim (`credential|role`) and reconnect the WS.
  final Future<void> Function(String role) onRoleSelected;

  /// The bare identity credential passed down from [_PortalEvsAppState].
  /// Session token in session mode; bare userId in dev mode. Forwarded to
  /// [AuditLogScreen] so it can build the correct `<identity>|<role>` Bearer.
  final String? identityCredential;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  /// True while the app-bar Settings link's Study Settings page overlays
  /// the active tab's body. Cleared by any tab tap (PortalDashboard fires
  /// onDestinationChanged even for the already-active tab while an
  /// override is showing).
  bool _showSettings = false;

  /// The label of the selected nav destination. Tracked by label (not index)
  /// so the selection survives the visible set changing on a role switch — a
  /// raw index would point at a different (or hidden) section. Null until the
  /// first build resolves it to the first visible destination.
  String? _selectedLabel;

  /// Latest effective-authorization snapshot for the active role, used to hide
  /// nav destinations the role cannot use. Mirrors `PermissionGate`'s source so
  /// nav visibility and per-screen gating react identically to a role switch.
  EffectiveAuthorization? _auth;
  StreamSubscription<EffectiveAuthorization?>? _permSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe once to the permission snapshot (needs context for the scope,
    // so it can't go in initState). Same source PermissionGate listens to.
    if (_permSub != null) return;
    final scope = ReActionScope.of(context);
    _auth = scope.permissionSource.current;
    _permSub = scope.permissionSource.stream.listen((auth) {
      if (!mounted) return;
      setState(() => _auth = auth);
    });
  }

  @override
  void dispose() {
    unawaited(_permSub?.cancel());
    super.dispose();
  }

  /// Builder for each nav section's screen. Two of the destinations now
  /// route through the redesigned `portal_screens` widgets via thin
  /// reactive bindings (Phase 6.5); the rest still mount their legacy
  /// widgets pending their own redesign.
  Widget _screenFor(String label) => switch (label) {
    'User Accounts' => UsersScreenBinding(
      currentUserId: switch (widget.principal) {
        UserPrincipal(:final userId) => userId,
        final p => p.id,
      },
      activeRole: switch (widget.principal) {
        UserPrincipal(:final activeRole) => activeRole,
        _ => null,
      },
    ),
    'Sites' => SitesScreenBinding(
      identityCredential: widget.identityCredential ?? '',
      serverUrl: _serverUrl,
    ),
    'Participants' => ParticipantsScreenBinding(
      identityCredential: widget.identityCredential ?? '',
      serverUrl: _serverUrl,
    ),
    'RAVE Sync' => const RaveSyncScreenBinding(),
    'Audit Log' => AuditLogScreenBinding(
      identityCredential: widget.identityCredential ?? '',
      serverUrl: _serverUrl,
      // Administrator audit tab: scope to Administrator actions (view=admin),
      // excluding system/automation events. Search is kept.
      // Implements: DIARY-DEV-audit-log-read/A
      adminActionsOnly: true,
    ),
    _ => const SizedBox.shrink(),
  };

  /// Popup listing the full version/provenance manifest. "Portal UI" is this
  /// bundle's own full version (APP_VERSION); the rest come from `/health` —
  /// including `diary_app`, the diary mobile-app version in the source this
  /// portal build was cut from (NOT a mobile deployment; iOS + Android share
  /// this one source version).
  void _showVersionsDialog() {
    final rows = <MapEntry<String, String>>[
      if (_appVersion.isNotEmpty) MapEntry('Portal UI', _appVersion),
      for (final e in const <String, String>{
        'portal_server_evs': 'Portal server',
        'server_commit': 'Server commit',
        'diary_app': 'Diary app',
        'portal_deployment': 'Deployment',
        // 'deploy' (the run-number counter) is now the modal topline above,
        // so it is intentionally omitted from the detail rows to avoid
        // duplicating it.
        'deploy_commit': 'Deploy commit',
      }.entries)
        if (widget.serverVersions[e.key] case final String val
            when val.isNotEmpty)
          MapEntry(e.value, val),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        size: AppDialogSize.small,
        title: 'Version details',
        semanticId: 'version-details-dialog',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Deploy counter (the deploy workflow's GitHub Actions
            // run_number, global across dev/qa/uat) as the modal's topline —
            // the "v XX" the app bar used to show pre-makeover. Deployed-only:
            // PORTAL_DEPLOY_SEQ is unset off Cloud Run, so hide when absent.
            if (widget.serverVersions['deploy'] case final String deploy
                when deploy.isNotEmpty) ...[
              Text(
                'Deploy #$deploy',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            if (rows.isEmpty)
              const Text('No version information available.')
            else
              for (final r in rows)
                AppInfoRow(label: r.key, valueWidget: SelectableText(r.value)),
            const SizedBox(height: 8),
          ],
        ),
        actions: <Widget>[
          AppButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide sections the active role can't use; a hidden section's screen is
    // never built, so it never opens a (denied) subscription. Until the first
    // permission snapshot loads, `held` is empty and the dashboard shows a
    // loader rather than flashing a forbidden section. Gating spec + order
    // live in kNavSections (single source); the screen self-gates on the same
    // name.
    final held = <String>{
      for (final p in _auth?.rolePermissions ?? const <Permission>{}) p.name,
    };
    final visible = visibleSections(held);
    return Scaffold(
      // Surface transport-connection state: when the reactive WS is
      // reconnecting/disconnected, a banner tells the user the data shown is the
      // last received (lists keep their last rows via the ViewBuilder Stale
      // state). Self-clears on reconnect.
      // Implements: DIARY-BASE-portal-transport-status/A+B
      body: ConnectionStatusBanner(
        statusStream: ReActionScope.of(context).connectionStatusStream,
        initial: ReActionScope.of(context).connectionStatus,
        child: _buildBody(visible),
      ),
    );
  }

  Widget _buildBody(List<NavSectionSpec> visible) {
    // Permission snapshot not loaded yet: don't guess at visibility.
    if (_auth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (visible.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No sections are available for your current role.'),
          ),
        ),
      );
    }
    // Phase 6.5: PortalDashboard replaces the NavigationRail. The shell
    // header doubles as the role switcher + user identity + logout
    // affordances; the dashboard's top-tab strip replaces the rail.
    final principal = widget.principal;
    final isUser = principal is UserPrincipal;
    final userName = isUser ? principal.userId : principal.id;
    final activeRole = isUser ? principal.activeRole : '';
    final availableRoles = isUser
        ? principal.roles.toList(growable: false)
        : const <String>[];

    return PortalDashboard(
      appBar: PortalAppBar(
        title: 'Sponsor Portal',
        // Subtitle follows the active role's dashboard label so the
        // header reads "Administrator Dashboard" / "CRA Dashboard" / etc.
        subtitle: '$activeRole Dashboard',
        userName: userName,
        activeRole: activeRole,
        availableRoles: availableRoles,
        onRoleSelected: isUser ? widget.onRoleSelected : null,
        onLogout: widget.onDisconnect,
        // Help icon opens the version/provenance dialog. Same manifest
        // (`portal_server_evs` / `server_commit` / `diary_app` /
        // `deploy` / `deploy_commit`) we used to surface via the
        // app-bar deploy-counter tap, now hung off the help affordance
        // so the chrome above doesn't need its own version label.
        onHelp: _showVersionsDialog,
        // Same sponsor-served logo the auth cards use (CUR-1483 Figma:
        // logo sits left of the title block).
        // Figma: hard-coded CureHHT brand mark on the top header.
        logo: Image.asset(
          'assets/icons/curehht_logo.png',
          height: 40,
        ),
        // Opens the read-only Study Settings page over the active tab.
        // Visible only to roles holding the ACT-ADM-001 read permission
        // (Administrator + SystemOperator per the sponsor matrix); the
        // server enforces the same gate on GET /config/study.
        onSettings:
            (_auth?.rolePermissions.any(
                  (p) => p.name == 'portal.admin.view_settings',
                ) ??
                false)
            ? () => setState(() => _showSettings = true)
            : null,
      ),
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            Text(
              'Sponsored by',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: const Color(0xFFA4B9C2), // Figma: Grey
              ),
            ),
            const SizedBox(width: 8),
            const SponsorBrandMark(maxHeight: 50),
          ],
        ),
      ),
      // Study Settings isn't a tab: it overlays the body while the strip
      // shows no active pill; any tab tap below dismisses it.
      bodyOverride: _showSettings
          ? StudySettingsBinding(
              identityCredential: widget.identityCredential ?? '',
              serverUrl: _serverUrl,
              activeRole: switch (widget.principal) {
                UserPrincipal(:final activeRole) => activeRole,
                _ => null,
              },
            )
          : null,
      destinations: <DashboardDestination>[
        for (final s in visible)
          DashboardDestination(
            key: s.label.toLowerCase().replaceAll(' ', '-'),
            label: s.label,
            body: (_) => _screenFor(s.label),
          ),
      ],
      initialKey: _selectedLabel?.toLowerCase().replaceAll(' ', '-'),
      onDestinationChanged: (key) {
        // Reverse key → label so kNavSections stays the single source of
        // truth for the label text (and _selectedLabel survives role
        // switches that change which sections are visible).
        for (final s in visible) {
          if (s.label.toLowerCase().replaceAll(' ', '-') == key) {
            setState(() {
              _selectedLabel = s.label;
              _showSettings = false;
            });
            return;
          }
        }
      },
    );
  }
}
