import 'dart:async';
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'package:portal_screens/portal_screens.dart';

import 'activation_link.dart';
import 'activation_screen.dart';
import 'audit_log_screen_binding.dart';
import 'connect_screen.dart';
import 'firebase_auth_client.dart';
import 'identity_config.dart';
import 'login_screen.dart';
import 'nav_sections.dart';
import 'participants_screen.dart';
import 'password_reset_screen.dart';
import 'rave_sync_screen.dart';
import 'reset_link.dart';
import 'sites_screen.dart';
import 'users_screen_binding.dart';
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

/// When true, renders the firebase_auth Login + OTP screens instead of the
/// dev ConnectScreen. DEFAULT off — the existing dev path is unchanged.
/// Enable with `--dart-define=PORTAL_SESSION_AUTH=true`.
const bool _sessionAuth = bool.fromEnvironment(
  'PORTAL_SESSION_AUTH',
  defaultValue: false,
);

class PortalEvsApp extends StatefulWidget {
  const PortalEvsApp({super.key});

  @override
  State<PortalEvsApp> createState() => _PortalEvsAppState();
}

class _PortalEvsAppState extends State<PortalEvsApp> {
  late final RemoteScope _scope;
  late final StreamSubscription<AuthStatus> _authSub;
  AuthStatus _status = const NotAuthenticated();

  /// Set to true after the user taps "Back to Login" on the password-reset done
  /// view so [build] falls through to the normal auth switch instead of
  /// re-showing the reset screen (the ?reset= code is still in the URL).
  bool _resetDismissed = false;
  bool _activationDismissed = false;

  /// The current identity credential.
  ///
  /// In dev mode: the bare userId (or `userId|role` when a specific role was
  /// requested). In session mode: the opaque Firebase session token (or
  /// `token|role` with an active-role claim).
  ///
  /// Null when not authenticated.
  String? _identityCredential;

  @override
  void initState() {
    super.initState();
    _scope = RemoteScope(baseUrl: Uri.parse(_serverUrl));
    _status = _scope.authSession.current;
    _authSub = _scope.authSession.stream.listen((next) {
      if (!mounted) return;
      setState(() => _status = next);
    });
    if (_sessionAuth) {
      // Fire-and-forget: fetch /config/identity and initialise Firebase.
      // Errors are surfaced through the LoginScreen UI on first sign-in attempt.
      initFirebaseFromServer(_serverUrl).ignore();
    }
  }

  @override
  void dispose() {
    unawaited(_authSub.cancel());
    unawaited(_scope.dispose());
    super.dispose();
  }

  /// Dev connect: called by [ConnectScreen] with a bare userId (optionally
  /// `userId|role` for a power-user initial-role choice). The STORED identity
  /// credential is kept bare (role claim stripped) so a later role switch
  /// appends a single `|role`; the typed value (with any role) is used for the
  /// initial connect.
  void _onConnect(String identity) {
    setState(() => _identityCredential = identity.split('|').first);
    _scope.authSession.setCredential(identity);
  }

  /// Session auth login: called by [LoginScreen] when the user authenticates
  /// with Firebase. Stores the session token so [_HomeShell] can pass it to
  /// [RoleSelector].
  void _onSession(String token) {
    setState(() => _identityCredential = token);
    _scope.authSession.setCredential(token);
  }

  /// Switches the active role by encoding a per-request credential claim
  /// (`credential|role`) and reconnecting the WS under the new role.
  ///
  /// Works in both dev mode (credential = bare userId) and session mode
  /// (credential = session token). [setCredential] fires GET /me
  /// synchronously, updating the Principal so the header and client gating
  /// reflect the new role immediately. [_scope.reconnect()] re-authenticates
  /// the WS and re-issues all live subscribes under the new role without
  /// triggering a logout or NotAuthenticated flicker.
  ///
  // Implements: DIARY-GUI-role-switching/E+F
  Future<void> _onRoleSelected(String role) async {
    final credential = _identityCredential;
    if (credential == null) return;
    // The active role is a per-request claim carried in the credential.
    // setCredential refreshes the Principal (header + client gating) via
    // GET /me; reconnect() re-gates the live WS view subscriptions under
    // the new role. No logout, no flicker — AuthStatus stays Authenticated.
    _scope.authSession.setCredential('$credential|$role');
    await _scope.reconnect();
  }

  // Implements: DIARY-DEV-portal-session-lifecycle/A
  Future<void> _disconnect() async {
    // POST /logout only in session mode — the dev credential is a bare userId,
    // not a parseable session token, and there is no server-side session to
    // terminate.
    if (_sessionAuth) {
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
    setState(() => _identityCredential = null);
    _scope.authSession.setCredential(null);
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
        home: PasswordResetScreen(
          serverUrl: _serverUrl,
          code: resetCode,
          onBackToLogin: () => setState(() => _resetDismissed = true),
        ),
      );
    }

    final Widget home = switch (_status) {
      Authenticated(:final principal) => _HomeShell(
        principal: principal,
        identityCredential: _identityCredential,
        onDisconnect: () {
          _disconnect();
        },
        onRoleSelected: _onRoleSelected,
      ),
      Expired() => Scaffold(
        body: _sessionAuth
            ? Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Session ended — please sign in again.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  Expanded(
                    child: LoginScreen(
                      serverUrl: _serverUrl,
                      authClient: RealFirebaseAuthClient(),
                      onSession: _onSession,
                    ),
                  ),
                ],
              )
            : ConnectScreen(
                onConnect: _onConnect,
                message: 'Session ended — reconnect.',
                serverUrl: _serverUrl,
              ),
      ),
      NotAuthenticated() => Scaffold(
        body: _sessionAuth
            ? LoginScreen(
                serverUrl: _serverUrl,
                authClient: RealFirebaseAuthClient(),
                onSession: _onSession,
              )
            : ConnectScreen(onConnect: _onConnect, serverUrl: _serverUrl),
      ),
    };
    return ReActionScope(
      scope: _scope,
      child: MaterialApp(
        title: 'Portal EVS Skeleton',
        // CUR-1450: adopt the diary_design_system brand (Carina blue +
        // Inter typography). Sites / Participants / RAVE Sync re-theme
        // passively; their layouts stay until they get their own redesign
        // round.
        theme: buildAppTheme(
          font: AppFontFamily.inter,
          brightness: Brightness.light,
        ),
        home: home,
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
    this.identityCredential,
  });

  final Principal principal;
  final VoidCallback onDisconnect;

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

  /// `vX.Y.Z+build` of the deployed web bundle, shown under the app-bar title
  /// so a running deployment self-identifies its build. Empty until resolved
  /// (or if the fetch fails). Sourced from the `version.json` that
  /// `flutter build web` emits at the web origin — the authoritative version of
  /// the actual built artifact, no extra dependency or build-time define.
  String _version = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

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
    'User Accounts' => const UsersScreenBinding(),
    'Sites' => const SitesScreen(),
    'Participants' => const ParticipantsScreen(),
    'RAVE Sync' => const RaveSyncScreen(),
    'Audit Log' => AuditLogScreenBinding(
      identityCredential: widget.identityCredential ?? '',
      serverUrl: _serverUrl,
    ),
    _ => const SizedBox.shrink(),
  };

  Future<void> _loadVersion() async {
    try {
      // version.json is served by the WEB origin (Uri.base), which in the
      // deployed bundle and in `flutter run` both serve it — unlike the portal
      // API base, which may be a different host in local dev.
      final res = await http.get(Uri.base.resolve('version.json'));
      if (!mounted || res.statusCode != 200) return;
      final json = jsonDecode(res.body) as Map<String, Object?>;
      final v = json['version'];
      final b = json['build_number'];
      if (v is! String || v.isEmpty) return;
      setState(
        () => _version = (b is String && b.isNotEmpty) ? 'v$v+$b' : 'v$v',
      );
    } catch (_) {
      // Best-effort: a missing/unservable version.json just hides the label.
    }
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
    return _buildBody(visible);
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
        title: 'Clinical Trial Portal',
        // Subtitle follows the active role's dashboard label so the
        // header reads "Administrator Dashboard" / "CRA Dashboard" / etc.
        subtitle: activeRole.isEmpty
            ? (_version.isEmpty ? 'Portal (EVS)' : 'Portal (EVS) — $_version')
            : '$activeRole Dashboard',
        userName: userName,
        activeRole: activeRole,
        availableRoles: availableRoles,
        onRoleSelected: isUser ? widget.onRoleSelected : null,
        onLogout: widget.onDisconnect,
        // Help icon isn't wired anywhere yet — Phase 8 polish.
      ),
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
            setState(() => _selectedLabel = s.label);
            return;
          }
        }
      },
    );
  }
}
