import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reaction_widgets/reaction_widgets.dart';

/// The two seeded identities. The value IS the dev credential
/// ("userId:activeRole") the DevCredentialAuthValidator parses.
const Map<String, String> _identities = <String, String>{
  'admin-1 (Administrator)': 'admin-1:Administrator',
  'sc-1 (StudyCoordinator)': 'sc-1:StudyCoordinator',
};

/// A user record returned by GET /dev/users.
class _DevUser {
  _DevUser({required this.userId, required this.roles});
  final String userId;
  final List<String> roles;
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({this.message, this.serverUrl, super.key});
  final String? message;

  /// The server base URL, used to fetch /dev/users for quick-connect
  /// buttons. If null, or if the fetch fails (session mode returns 404),
  /// the screen falls back to the static dropdown.
  final String? serverUrl;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _credential = _identities.values.first;

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
        // Non-200 (e.g. 404 in session mode): fall back to static UI.
        setState(() => _devUsers = []);
      }
    } catch (_) {
      // Network error: fall back to static UI.
      setState(() => _devUsers = []);
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  void _connect([String? credential]) => ReActionScope.of(
    context,
  ).authSession.setCredential(credential ?? _credential);

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
                  for (final user in devUsers)
                    for (final role in user.roles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton(
                          onPressed: () => _connect('${user.userId}:$role'),
                          child: Text('${user.userId} — $role'),
                        ),
                      ),
                  const Divider(height: 28),
                ],
                const Text('Connect as'),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _credential,
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    for (final e in _identities.entries)
                      DropdownMenuItem<String>(
                        value: e.value,
                        child: Text(e.key),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _credential = v ?? _credential),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.login),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
