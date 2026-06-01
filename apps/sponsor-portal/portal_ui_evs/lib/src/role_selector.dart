import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Priority order for role display; roles not in this list sort last
/// (stable relative order among unknowns).
const List<String> _priority = <String>[
  'Administrator',
  'Clinical Research Associate',
  'Study Coordinator',
];

/// Returns true when a role-switching selector should be shown.
///
// Implements: DIARY-GUI-role-switching/A+B
bool roleSelectorVisible(Set<String> roles) => roles.length >= 2;

/// A single entry in the role popup menu.
class RoleMenuItem {
  const RoleMenuItem({required this.role, required this.isActive});
  final String role;
  final bool isActive;
}

/// Returns the roles sorted by [_priority] (unknowns last), each marked
/// with whether it is the [activeRole].
///
// Implements: DIARY-GUI-role-switching/C+D
List<RoleMenuItem> roleMenuItems({
  required Set<String> roles,
  required String activeRole,
}) {
  final sorted = roles.toList()
    ..sort((a, b) {
      final ia = _priority.indexOf(a);
      final ib = _priority.indexOf(b);
      return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
    });
  return [
    for (final r in sorted) RoleMenuItem(role: r, isActive: r == activeRole),
  ];
}

/// Header widget that lets a multi-role user switch their active role
/// in-session without a confirmation step.
///
/// Hidden when the user has fewer than two roles (GUI/B). Shows the
/// active role as a labelled dropdown; selecting a different role POSTs
/// to [serverUrl]/session/active-role with the [sessionToken] Bearer
/// header, then calls [onSwitched] so the parent can refresh the
/// principal and route to the new role's landing view.
///
// Implements: DIARY-GUI-role-switching/A+B+C+D+E+G
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.serverUrl,
    required this.sessionToken,
    required this.roles,
    required this.activeRole,
    required this.onSwitched,
    this.httpClient,
  });

  final String serverUrl;
  final String sessionToken;
  final Set<String> roles;
  final String activeRole;

  /// Called after a successful role-switch so the parent can refresh the
  /// principal and reset navigation to the role's landing view.
  ///
  // Implements: DIARY-GUI-role-switching/F
  final Future<void> Function() onSwitched;

  /// Optional HTTP client; defaults to a fresh [http.Client] if omitted.
  final http.Client? httpClient;

  http.Client get _http => httpClient ?? http.Client();

  Future<void> _switch(String role) async {
    final r = await _http.post(
      Uri.parse('$serverUrl/session/active-role'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionToken',
      },
      body: jsonEncode({'role': role}),
    );
    if (r.statusCode == 200) await onSwitched();
  }

  @override
  Widget build(BuildContext context) {
    if (!roleSelectorVisible(roles)) return const SizedBox.shrink();
    final items = roleMenuItems(roles: roles, activeRole: activeRole);
    return PopupMenuButton<String>(
      tooltip: 'Switch role',
      onSelected: _switch,
      itemBuilder: (_) => [
        for (final i in items)
          PopupMenuItem<String>(
            value: i.role,
            child: Row(
              children: [
                if (i.isActive)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(i.role),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(activeRole), const Icon(Icons.arrow_drop_down)],
        ),
      ),
    );
  }
}
