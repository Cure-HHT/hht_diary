// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: User Management Interface
//
// Per CUR-1122 / Figma, the Admin sidebar contains only Users and Audit Logs.
// Overview / Sites / Participants pages were removed; if Admin needs Sites
// or Patients views in the future they must be re-scoped via spec first.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/widgets/user_activity_listener.dart';

import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';
import 'user_management_tab.dart';

/// Admin dashboard page with navigation rail
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);

    // CUR-1118: Wait for Firebase to restore session before redirecting.
    if (!authService.isAuthenticated && !authService.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check authentication and admin role
    if (!authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authService.currentUser!;
    if (!user.role.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return UserActivityListener(
      child: Scaffold(
        appBar: const PortalAppBar(title: 'Admin Dashboard'),
        body: Column(
          children: [
            // Role banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: _getRoleBannerColor(user.role, theme),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 20,
                    color: _getRoleBannerTextColor(user.role, theme),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Logged in as ${authService.sponsorRoleName(user.role.systemName)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getRoleBannerTextColor(user.role, theme),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Main content with navigation rail
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.people_outline),
                        selectedIcon: Icon(Icons.people),
                        label: Text('Users'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('Audit Logs'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: _buildContent(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return const UserManagementTab();
      case 1:
        return _buildAuditLogsPlaceholder(theme);
      default:
        return const UserManagementTab();
    }
  }

  /// Placeholder pending the Admin audit log viewer.
  ///
  /// Mirrors the Investigator dashboard's placeholder in
  /// `investigator_dashboard_page.dart` so both roles see consistent
  /// affordances while the real viewer is being built.
  Widget _buildAuditLogsPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Audit Logs', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Audit log viewing will be available in a future update.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleBannerColor(UserRole role, ThemeData theme) {
    switch (role) {
      case UserRole.administrator:
      case UserRole.developerAdmin:
        return theme.colorScheme.primaryContainer;
      case UserRole.auditor:
        return theme.colorScheme.tertiaryContainer;
      case UserRole.sponsor:
        return theme.colorScheme.secondaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _getRoleBannerTextColor(UserRole role, ThemeData theme) {
    switch (role) {
      case UserRole.administrator:
      case UserRole.developerAdmin:
        return theme.colorScheme.onPrimaryContainer;
      case UserRole.auditor:
        return theme.colorScheme.onTertiaryContainer;
      case UserRole.sponsor:
        return theme.colorScheme.onSecondaryContainer;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
