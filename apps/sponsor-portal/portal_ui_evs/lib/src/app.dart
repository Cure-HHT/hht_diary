import 'dart:async';

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
    // instead of the normal authed shell.
    final activationCode = activationCodeFromUri(Uri.base);
    if (activationCode != null) {
      return MaterialApp(
        home: ActivationScreen(serverUrl: _serverUrl, code: activationCode),
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
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
        ),
        home: home,
      ),
    );
  }
}

/// Nav shell shown once connected. A [NavigationRail] swaps between four
/// independent reactive screens. Each screen self-gates with its own
/// `PermissionGate` (view permission), so the nav labels are always shown
/// for all four destinations — an unauthorized screen renders its own
/// clean "no access" fallback. No per-item permission hiding here.
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

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

class _HomeShellState extends State<_HomeShell> {
  int _selected = 0;

  String _credentialLabel() {
    final p = widget.principal;
    if (p is UserPrincipal) return '${p.userId}:${p.activeRole}';
    return p.id;
  }

  @override
  Widget build(BuildContext context) {
    // Built here (not static) so AuditLogScreen can receive widget.identityCredential.
    // Each destination builds an independent reactive widget gated by its
    // own view permission (the screen, not the nav item, enforces access).
    final destinations = <_NavDestination>[
      _NavDestination(
        'User Accounts',
        Icons.manage_accounts,
        UserAccountsScreen.new,
      ),
      _NavDestination('Sites', Icons.location_city, SitesScreen.new),
      _NavDestination('Participants', Icons.groups, ParticipantsScreen.new),
      _NavDestination('RAVE Sync', Icons.sync, RaveSyncScreen.new),
      _NavDestination(
        'Audit Log',
        Icons.receipt_long,
        () =>
            AuditLogScreen(identityCredential: widget.identityCredential ?? ''),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal (EVS skeleton)'),
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
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _selected = i),
            destinations: <NavigationRailDestination>[
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: destinations[_selected].builder()),
        ],
      ),
    );
  }
}
