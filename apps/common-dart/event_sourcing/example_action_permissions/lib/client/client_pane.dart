// lib/client/client_pane.dart
//
// Left pane of the dual-pane app. Holds the snapshot cache, the user
// selector, and (in later tasks) the action button panel and request
// history. For Task 21 it just exercises session/start.

import 'package:action_permissions_demo/client/hacker_mode_toggle.dart';
import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:action_permissions_demo/client/userid_selector.dart';
import 'package:flutter/material.dart';

class ClientPane extends StatefulWidget {
  const ClientPane({super.key, this.httpClient});

  /// Injected for tests. When omitted, a default `DemoHttpClient` pointing
  /// at `localhost:8080` is created.
  final DemoHttpClient? httpClient;

  @override
  State<ClientPane> createState() => _ClientPaneState();
}

class _ClientPaneState extends State<ClientPane> {
  late final DemoHttpClient _http;
  late final bool _ownsHttp;
  final PermissionSnapshotCache _cache = PermissionSnapshotCache();
  final HackerMode _hackerMode = HackerMode();

  /// The userIds the demo's user-directory seed knows about. Hard-coded
  /// to match `tool/users.yaml`. The server is the source of truth — if
  /// the user types a different value, /session/start returns the Anon
  /// principal.
  static const List<String> _knownUserIds = <String>[
    'admin-user',
    'green-user-1',
    'green-user-2',
    'blue-user',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.httpClient != null) {
      _http = widget.httpClient!;
      _ownsHttp = false;
    } else {
      _http = DemoHttpClient();
      _ownsHttp = true;
    }
    // Fire-and-forget initial session as Anon. Errors land on the console
    // for the demo; production would surface in the UI.
    _refreshSession(null);
  }

  @override
  void dispose() {
    if (_ownsHttp) {
      _http.close();
    }
    _cache.dispose();
    _hackerMode.dispose();
    super.dispose();
  }

  Future<void> _refreshSession(String? userId) async {
    try {
      final resp = await _http.sessionStart(userId: userId);
      if (!mounted) return;
      _cache.update(
        userId: userId,
        principalRole: resp.principalRole,
        principalUserId: resp.principalUserId,
        principalActiveSite: resp.principalActiveSite,
        permissions: resp.snapshotPermissions.toSet(),
      );
    } on Object catch (e) {
      if (!mounted) return;
      // Server unavailable in widget tests / cold boot — show Anon and
      // an error hint.
      _cache.update(
        userId: userId,
        principalRole: 'Anon',
        principalUserId: null,
        principalActiveSite: null,
        permissions: const <String>{},
      );
      debugPrint('session/start failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cache,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UserIdSelector(
                currentUserId: _cache.userId,
                knownUserIds: _knownUserIds,
                onChanged: _refreshSession,
              ),
              const SizedBox(height: 16),
              Text('Role: ${_cache.principalRole}'),
              Text('userId: ${_cache.principalUserId ?? '(none)'}'),
              Text('activeSite: ${_cache.principalActiveSite ?? '(none)'}'),
              const SizedBox(height: 8),
              HackerModeToggle(mode: _hackerMode),
              const Divider(),
              const Text('Permissions:'),
              if (_cache.permissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '(none — anonymous principals get no grants)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else
                for (final p in _cache.permissions.toList()..sort())
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• $p'),
                  ),
            ],
          ),
        );
      },
    );
  }
}
