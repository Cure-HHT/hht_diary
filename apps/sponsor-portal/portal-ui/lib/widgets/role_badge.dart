// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//
// Role badge widget - displays a role with color coding

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Pairs a sponsor display name with its system role for correct color mapping
class RoleDisplayData {
  final String displayName;
  final String systemRole;

  const RoleDisplayData({required this.displayName, required this.systemRole});
}

/// Role-to-color mapping for visual role indication
/// Colors selected for accessibility (WCAG AA contrast)
Color getRoleBadgeColor(UserRole role, ColorScheme colorScheme) {
  switch (role) {
    case UserRole.developerAdmin:
      return const Color(0xFF7C3AED); // Purple
    case UserRole.administrator:
      return const Color(0xFFDC2626); // Red
    case UserRole.sponsor:
      return const Color(0xFF2563EB); // Blue
    case UserRole.auditor:
      return const Color(0xFFD97706); // Amber
    case UserRole.analyst:
      return const Color(0xFF059669); // Emerald
    case UserRole.investigator:
      return const Color(0xFF0891B2); // Cyan
  }
}

/// A colored badge for displaying a user role
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool compact;
  final String? _displayNameOverride;

  const RoleBadge({
    super.key,
    required this.role,
    this.compact = false,
    String? displayName,
  }) : _displayNameOverride = displayName;

  /// Create from a system role string (e.g., 'Administrator')
  factory RoleBadge.fromString(String roleString, {bool compact = false}) {
    return RoleBadge(role: UserRole.fromString(roleString), compact: compact);
  }

  /// Create from paired display data (sponsor name + system role for color)
  factory RoleBadge.fromDisplayData(
    RoleDisplayData data, {
    bool compact = false,
  }) {
    return RoleBadge(
      role: UserRole.fromString(data.systemRole),
      compact: compact,
      displayName: data.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = getRoleBadgeColor(role, colorScheme);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _displayNameOverride ?? role.displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// A row of role badges for users with multiple roles
class RoleBadgeList extends StatelessWidget {
  final List<RoleDisplayData> roles;
  final bool compact;
  final int maxVisible;

  const RoleBadgeList({
    super.key,
    required this.roles,
    this.compact = false,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Text(
        'No roles',
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final visibleRoles = roles.take(maxVisible).toList();
    final remainingCount = roles.length - maxVisible;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visibleRoles.map(
          (role) => RoleBadge.fromDisplayData(role, compact: compact),
        ),
        if (remainingCount > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
