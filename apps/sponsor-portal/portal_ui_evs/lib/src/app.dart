import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'connect_screen.dart';
import 'user_role_admin_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_status) {
      Authenticated() => const UserRoleAdminScreen(),
      Expired() => const ConnectScreen(message: 'Session ended — reconnect.'),
      NotAuthenticated() => const ConnectScreen(),
    };
    return ReActionScope(
      scope: _scope,
      child: MaterialApp(
        title: 'Portal EVS Skeleton',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
        ),
        home: Scaffold(
          appBar: AppBar(
              title: const Text('Portal · User Role Admin (EVS skeleton)')),
          body: body,
        ),
      ),
    );
  }
}
