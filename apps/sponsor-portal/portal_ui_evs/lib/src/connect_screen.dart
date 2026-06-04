import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A user record returned by GET /dev/users.
class _DevUser {
  _DevUser({required this.userId, required this.roles});
  final String userId;
  final List<String> roles;
}

/// Dev quick-connect screen. The dev credential is now a bare [userId] (or
/// optionally `userId|role`), which the server's DevCredentialAuthValidator
/// resolves against the event-derived `user_role_scopes` view. The active role
/// is switched in-app via the header Role Selector after connecting — no
/// per-role quick-connect rows are needed.
///
/// In session mode (PORTAL_SESSION_AUTH=true) this screen is not shown; the
/// Firebase login screen is used instead.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    required this.onConnect,
    this.message,
    this.serverUrl,
    super.key,
  });

  /// Called with the identity string (bare userId or typed value) when the
  /// user initiates a connection. The parent widget (app.dart) sets the
  /// credential and drives the ReActionScope.
  final void Function(String identity) onConnect;

  final String? message;

  /// The server base URL, used to fetch /dev/users for quick-connect buttons.
  /// If null, or if the fetch fails (session mode returns 404), the screen
  /// shows only the manual-entry field.
  final String? serverUrl;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _controller = TextEditingController();

  /// Null = not yet attempted; empty list = fetch failed / no users.
  List<_DevUser>? _devUsers;
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    final url = widget.serverUrl;
    if (url != null) {
      _fetchDevUsers(url);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDevUsers(String serverUrl) async {
    setState(() => _loadingUsers = true);
    try {
      final res = await http.get(Uri.parse('$serverUrl/dev/users'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, Object?>;
        final list = (body['users'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() {
          _devUsers = [
            for (final u in list)
              _DevUser(
                userId: u['userId'] as String,
                roles: (u['roles'] as List<dynamic>).cast<String>(),
              ),
          ];
        });
      } else {
        // Non-200 (e.g. 404 in session mode): fall back to manual entry only.
        setState(() => _devUsers = []);
      }
    } catch (_) {
      // Network error: fall back to manual entry only.
      setState(() => _devUsers = []);
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devUsers = _devUsers;
    final showDevList = devUsers != null && devUsers.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.message != null) ...<Widget>[
                  Text(widget.message!),
                  const SizedBox(height: 12),
                ],
                if (_loadingUsers)
                  const Center(child: CircularProgressIndicator())
                else if (showDevList) ...[
                  const Text(
                    'Dev quick-connect',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // One button per user. The role is shown as info only;
                  // switching roles happens in-app via the header Role Selector.
                  for (final user in devUsers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      // CUR-1307: identified for Playwright web automation.
                      child: Semantics(
                        identifier: 'connect-as-${user.userId}',
                        button: true,
                        container: true,
                        explicitChildNodes: true,
                        child: OutlinedButton(
                          onPressed: () => widget.onConnect(user.userId),
                          child: Text(
                            '${user.userId}  (${user.roles.join(', ')})',
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 28),
                ],
                const Text('Connect as (userId or userId|role)'),
                const SizedBox(height: 8),
                // CUR-1307: identified for Playwright web automation.
                Semantics(
                  identifier: 'connect-userid',
                  textField: true,
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. admin-1 or admin-1|StudyCoordinator',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) widget.onConnect(v.trim());
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'connect-button',
                  button: true,
                  container: true,
                  explicitChildNodes: true,
                  child: FilledButton.icon(
                    onPressed: () {
                      final v = _controller.text.trim();
                      if (v.isNotEmpty) widget.onConnect(v);
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Connect'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
