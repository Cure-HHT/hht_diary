import 'package:flutter/material.dart';

/// Priority order for role display; roles not in this list sort last
/// (stable relative order among unknowns).
const List<String> _priority = <String>[
  'SystemOperator',
  'Administrator',
  'CRA',
  'StudyCoordinator',
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
/// active role as a labelled dropdown; selecting a different role calls
/// [onRoleSelected] with the chosen role string so the parent can update
/// the credential claim and reconnect the WS.
///
// Implements: DIARY-GUI-role-switching/A+B+C+D+E+G
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.roles,
    required this.activeRole,
    required this.onRoleSelected,
  });

  final Set<String> roles;
  final String activeRole;

  /// Called with the chosen role string so the parent can encode a new
  /// credential claim (`token|role`) and reconnect the WS.
  ///
  // Implements: DIARY-GUI-role-switching/F
  final void Function(String role) onRoleSelected;

  @override
  Widget build(BuildContext context) {
    if (!roleSelectorVisible(roles)) return const SizedBox.shrink();
    final items = roleMenuItems(roles: roles, activeRole: activeRole);
    return PopupMenuButton<String>(
      tooltip: 'Switch role',
      onSelected: onRoleSelected,
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
