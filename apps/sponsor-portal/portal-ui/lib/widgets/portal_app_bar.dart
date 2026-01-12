// IMPLEMENTS REQUIREMENTS:
//   REQ-d00029: Portal UI Design System
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//
// Portal app bar with role switcher for multi-role users

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'role_badge.dart';

/// App bar widget for the portal with user info, role switcher, and logout
class PortalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  const PortalAppBar({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        if (user != null) ...[
          // User name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                user.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Role badge (dropdown if multiple roles)
          if (user.hasMultipleRoles)
            _RoleSwitcher(user: user, authService: authService)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: RoleBadge(role: user.activeRole)),
            ),
          // Logout button
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Role switcher dropdown for multi-role users
class _RoleSwitcher extends StatelessWidget {
  final PortalUser user;
  final AuthService authService;

  const _RoleSwitcher({required this.user, required this.authService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = getRoleBadgeColor(user.activeRole, theme.colorScheme);

    return PopupMenuButton<UserRole>(
      tooltip: 'Switch Role',
      offset: const Offset(0, 40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.activeRole.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
      onSelected: (role) async {
        if (role != user.activeRole) {
          await authService.switchRole(role);
          // Navigate to appropriate dashboard based on new role
          if (context.mounted) {
            _navigateToRoleDashboard(context, role);
          }
        }
      },
      itemBuilder: (context) {
        return user.roles.map((role) {
          final isActive = role == user.activeRole;
          return PopupMenuItem<UserRole>(
            value: role,
            child: Row(
              children: [
                RoleBadge(role: role),
                const SizedBox(width: 8),
                if (isActive)
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  void _navigateToRoleDashboard(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.developerAdmin:
        context.go('/dev-admin');
        break;
      case UserRole.administrator:
        context.go('/admin');
        break;
      case UserRole.investigator:
        context.go('/investigator');
        break;
      case UserRole.auditor:
        context.go('/auditor');
        break;
      case UserRole.sponsor:
      case UserRole.analyst:
        context.go('/admin'); // Default for now
        break;
    }
  }
}
