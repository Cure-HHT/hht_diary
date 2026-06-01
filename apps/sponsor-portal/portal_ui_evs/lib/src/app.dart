import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'connect_screen.dart';
import 'participants_screen.dart';
import 'rave_sync_screen.dart';
import 'sites_screen.dart';
import 'user_accounts_screen.dart';

const String _serverUrl = String.fromEnvironment(
  'PORTAL_SERVER_URL',
  defaultValue: 'http://localhost:8084',
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

  @override
  void initState() {
    super.initState();
    _scope = RemoteScope(baseUrl: Uri.parse(_serverUrl));
    _status = _scope.authSession.current;
    _authSub = _scope.authSession.stream.listen((next) {
      if (!mounted) return;
      setState(() => _status = next);
    });
  }

  @override
  void dispose() {
    unawaited(_authSub.cancel());
    unawaited(_scope.dispose());
    super.dispose();
  }

  void _disconnect() => _scope.authSession.setCredential(null);

  @override
  Widget build(BuildContext context) {
    final Widget home = switch (_status) {
      Authenticated(:final principal) =>
        _HomeShell(principal: principal, onDisconnect: _disconnect),
      Expired() => const Scaffold(
          body: ConnectScreen(message: 'Session ended — reconnect.'),
        ),
      NotAuthenticated() => const Scaffold(body: ConnectScreen()),
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
  const _HomeShell({required this.principal, required this.onDisconnect});

  final Principal principal;
  final VoidCallback onDisconnect;

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

  // Each destination builds an independent reactive widget gated by its
  // own view permission (the screen, not the nav item, enforces access).
  static final List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
        'User Accounts', Icons.manage_accounts, UserAccountsScreen.new),
    _NavDestination('Sites', Icons.location_city, SitesScreen.new),
    _NavDestination('Participants', Icons.groups, ParticipantsScreen.new),
    _NavDestination('RAVE Sync', Icons.sync, RaveSyncScreen.new),
  ];

  String _credentialLabel() {
    final p = widget.principal;
    if (p is UserPrincipal) return '${p.userId}:${p.activeRole}';
    return p.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal (EVS skeleton)'),
        actions: <Widget>[
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
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _destinations[_selected].builder()),
        ],
      ),
    );
  }
}
