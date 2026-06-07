import 'dart:async';
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'activation_link.dart';
import 'activation_screen.dart';
import 'password_reset_screen.dart';
import 'reset_link.dart';
import 'audit_log_screen.dart';
import 'connect_screen.dart';
import 'firebase_auth_client.dart';
import 'identity_config.dart';
import 'login_screen.dart';
import 'nav_sections.dart';
import 'participants_screen.dart';
import 'rave_sync_screen.dart';
import 'role_selector.dart';
import 'sites_screen.dart';
import 'user_accounts_screen.dart';

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

class PortalEvsApp extends StatefulWidget {
  const PortalEvsApp({super.key});

  @override
  State<PortalEvsApp> createState() => _PortalEvsAppState();
}

class _PortalEvsAppState extends State<PortalEvsApp> {
  late final RemoteScope _scope;
  late final StreamSubscription<AuthStatus> _authSub;
  AuthStatus _status = const NotAuthenticated();

  /// Login-UI mode, resolved at runtime from `GET /config/identity` (`authMode`).
  /// Null while the config is still loading; `true` renders the Firebase
  /// Login/OTP screens, `false` renders the dev ConnectScreen. Resolving at
  /// runtime lets one web image serve both dev and session-auth deployments.
  // Implements: DIARY-DEV-portal-second-factor-toggle/C
  bool? _sessionAuth;

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
    _resolveAuthMode();
  }

  /// Resolves the login-UI mode from the server's identity config. When the
  /// server reports `authMode == 'session'`, initialises Firebase from the same
  /// config so [LoginScreen] can authenticate. Falls back to dev mode if the
  /// config can't be fetched. Firebase init errors are swallowed here and
  /// surface through the LoginScreen UI on the first sign-in attempt.
  // Implements: DIARY-DEV-portal-second-factor-toggle/C
  Future<void> _resolveAuthMode() async {
    var session = false;
    final cfg = await fetchIdentityConfig(_serverUrl);
    if (cfg != null) {
      session = cfg['authMode'] == 'session';
      if (session) {
        await initFirebaseWithConfig(cfg).catchError((Object _) {});
      }
    }
    if (!mounted) return;
    setState(() => _sessionAuth = session);
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
    setState(() => _identityCredential = null);
    _scope.authSession.setCredential(null);
  }

  /// Shown while the login-UI mode is still being resolved from the server.
  Widget _loadingScaffold() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  /// The Firebase email/password login surface (session-auth mode).
  Widget _loginScreen() => LoginScreen(
    serverUrl: _serverUrl,
    authClient: RealFirebaseAuthClient(),
    onSession: _onSession,
  );

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
      Expired() => switch (_sessionAuth) {
        null => _loadingScaffold(),
        true => Scaffold(
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Session ended — please sign in again.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              Expanded(child: _loginScreen()),
            ],
          ),
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
        true => Scaffold(body: _loginScreen()),
        false => Scaffold(
          body: ConnectScreen(onConnect: _onConnect, serverUrl: _serverUrl),
        ),
      },
    };
    return ReActionScope(
      scope: _scope,
      child: MaterialApp(
        title: 'Portal EVS Skeleton',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
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

  /// Server-reported version manifest from `GET /health` `.versions`:
  /// `portal_server_evs` (semver+N), `server_commit`, `portal_ui_version`,
  /// `portal_deployment`, `deploy` (the deploy counter), `deploy_commit`.
  /// The app-bar shows only the deploy counter; the rest live in the popup.
  Map<String, Object?> _serverVersions = const <String, Object?>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
    unawaited(_loadServerVersions());
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

  /// Presentation for a nav section, keyed by its [NavSectionSpec.label]; the
  /// gating spec (label + permission + order) is the single source in
  /// [kNavSections], so only icon/builder live here.
  IconData _iconFor(String label) => switch (label) {
    'User Accounts' => Icons.manage_accounts,
    'Sites' => Icons.location_city,
    'Participants' => Icons.groups,
    'RAVE Sync' => Icons.sync,
    'Audit Log' => Icons.receipt_long,
    _ => Icons.help_outline,
  };

  Widget _screenFor(String label) => switch (label) {
    'User Accounts' => const UserAccountsScreen(),
    'Sites' => const SitesScreen(),
    'Participants' => const ParticipantsScreen(),
    'RAVE Sync' => const RaveSyncScreen(),
    'Audit Log' => AuditLogScreen(
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

  Future<void> _loadServerVersions() async {
    try {
      // /health is public + same-origin-reachable; .versions carries the
      // server binary id, deploy counter, and the rest of the manifest.
      final res = await http.get(Uri.parse('$_serverUrl/health'));
      if (!mounted || res.statusCode != 200) return;
      final json = jsonDecode(res.body) as Map<String, Object?>;
      final v = json['versions'];
      if (v is Map) {
        setState(() => _serverVersions = Map<String, Object?>.from(v));
      }
    } catch (_) {
      // Best-effort: if /health is unreachable, the label falls back to the
      // bundle version and the popup just shows fewer rows.
    }
  }

  /// The compact label under the app-bar title: the deploy counter when the
  /// server reports one ("Deploy #47"), else the bundle version, else nothing.
  String _versionLabel() {
    final deploy = _serverVersions['deploy'];
    if (deploy is String && deploy.isNotEmpty) return 'Deploy #$deploy';
    return _version;
  }

  /// Popup listing the full version/provenance manifest. Bundle version is the
  /// UI's own self-report (version.json); the rest come from the server /health.
  void _showVersionsDialog() {
    final rows = <MapEntry<String, String>>[
      if (_version.isNotEmpty) MapEntry('App (this bundle)', _version),
      for (final e in const <String, String>{
        'portal_server_evs': 'Portal server',
        'server_commit': 'Server commit',
        'portal_ui_version': 'Portal UI (served)',
        'portal_deployment': 'Deployment',
        'deploy': 'Deploy #',
        'deploy_commit': 'Deploy commit',
      }.entries)
        if (_serverVersions[e.key] case final String val when val.isNotEmpty)
          MapEntry(e.value, val),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Version details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (rows.isEmpty)
                const Text('No version information available.')
              else
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 150,
                          child: Text(
                            '${r.key}:',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(child: SelectableText(r.value)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _credentialLabel() {
    final p = widget.principal;
    if (p is UserPrincipal) return '${p.userId}:${p.activeRole}';
    return p.id;
  }

  @override
  Widget build(BuildContext context) {
    // Hide sections the active role can't use; a hidden section's screen is
    // never built, so it never opens a (denied) subscription. Until the first
    // permission snapshot loads, `held` is empty and the body shows a loader
    // rather than flashing a forbidden section. Gating spec + order live in
    // kNavSections (single source); the screen self-gates on the same name.
    final held = <String>{
      for (final p in _auth?.rolePermissions ?? const <Permission>{}) p.name,
    };
    final visible = visibleSections(held);
    final selectedIndex = resolveSelectedIndex(visible, _selectedLabel);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Portal (EVS skeleton)'),
            if (_versionLabel().isNotEmpty)
              InkWell(
                onTap: _showVersionsDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _versionLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: <Widget>[
          if (widget.principal is UserPrincipal)
            RoleSelector(
              roles: (widget.principal as UserPrincipal).roles,
              activeRole: (widget.principal as UserPrincipal).activeRole,
              onRoleSelected: widget.onRoleSelected,
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Connected as ${_credentialLabel()}'),
            ),
          ),
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.logout),
            onPressed: widget.onDisconnect,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(visible, selectedIndex),
    );
  }

  Widget _buildBody(List<NavSectionSpec> visible, int selectedIndex) {
    // Permission snapshot not loaded yet: don't guess at visibility.
    if (_auth == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No sections are available for your current role.'),
        ),
      );
    }
    final content = Expanded(child: _screenFor(visible[selectedIndex].label));
    // NavigationRail requires >= 2 destinations; with a single visible section
    // render it full-width without the rail.
    if (visible.length < 2) {
      return Row(children: <Widget>[content]);
    }
    return Row(
      children: <Widget>[
        NavigationRail(
          selectedIndex: selectedIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) =>
              setState(() => _selectedLabel = visible[i].label),
          destinations: <NavigationRailDestination>[
            for (final s in visible)
              NavigationRailDestination(
                icon: Icon(_iconFor(s.label)),
                // CUR-1307: identified for Playwright web automation.
                label: Semantics(
                  identifier:
                      'nav-${s.label.toLowerCase().replaceAll(' ', '-')}',
                  child: Text(s.label),
                ),
              ),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        content,
      ],
    );
  }
}
