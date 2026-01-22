// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: User Management Interface
//   REQ-CAL-p00010: Schema-Driven Data Validation (EDC sites display)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';
import 'sites_tab.dart';
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

    return Scaffold(
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
                  'Logged in as ${user.role.displayName}',
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
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.location_city_outlined),
                      selectedIcon: Icon(Icons.location_city),
                      label: Text('Sites'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _buildContent(user, theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PortalUser user, ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab(user, theme);
      case 1:
        return _buildUsersTab(theme);
      case 2:
        return _buildSitesTab(theme);
      default:
        return _buildOverviewTab(user, theme);
    }
  }

  Widget _buildOverviewTab(PortalUser user, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${user.name}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clinical Trial Sponsor Portal',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          // Quick stats cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                theme,
                'Users',
                Icons.people,
                'Manage portal users and roles',
                () => setState(() => _selectedIndex = 1),
              ),
              _buildStatCard(
                theme,
                'Sites',
                Icons.location_city,
                'View clinical trial sites',
                () => setState(() => _selectedIndex = 2),
              ),
              _buildStatCard(
                theme,
                'Settings',
                Icons.settings,
                'Portal configuration',
                null, // Coming soon
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: onTap != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onTap == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Coming soon',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) => const UserManagementTab();

  Widget _buildSitesTab(ThemeData theme) => const SitesTab();

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
