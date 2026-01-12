// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00032: Role-Based Access Control Implementation
//
// Role picker page - displayed when a user with multiple roles logs in

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/role_badge.dart';

/// Page for users with multiple roles to select which role to use
class RolePickerPage extends StatefulWidget {
  const RolePickerPage({super.key});

  @override
  State<RolePickerPage> createState() => _RolePickerPageState();
}

class _RolePickerPageState extends State<RolePickerPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final theme = Theme.of(context);

    // If no user or only one role, redirect
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!user.hasMultipleRoles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToRoleDashboard(context, user.activeRole);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, ${user.name}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a role to continue',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Role options
                  ...user.roles.map(
                    (role) => _RoleOption(
                      role: role,
                      isLoading: _isLoading,
                      onTap: () => _selectRole(authService, role),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can switch roles at any time using the role dropdown in the top bar.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectRole(AuthService authService, UserRole role) async {
    setState(() => _isLoading = true);

    try {
      await authService.switchRole(role);
      if (mounted) {
        _navigateToRoleDashboard(context, role);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        context.go('/admin'); // Default dashboard for now
        break;
    }
  }
}

/// Individual role option card
class _RoleOption extends StatelessWidget {
  final UserRole role;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = getRoleBadgeColor(role, theme.colorScheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getRoleIcon(role), color: bgColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getRoleDescription(role),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.developerAdmin:
        return Icons.developer_mode;
      case UserRole.administrator:
        return Icons.admin_panel_settings;
      case UserRole.investigator:
        return Icons.medical_services;
      case UserRole.auditor:
        return Icons.fact_check;
      case UserRole.sponsor:
        return Icons.business;
      case UserRole.analyst:
        return Icons.analytics;
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.developerAdmin:
        return 'System configuration and portal admin setup';
      case UserRole.administrator:
        return 'User management and portal administration';
      case UserRole.investigator:
        return 'Patient enrollment and monitoring';
      case UserRole.auditor:
        return 'Audit trails and compliance review';
      case UserRole.sponsor:
        return 'Study oversight and reporting';
      case UserRole.analyst:
        return 'Data analysis and insights';
    }
  }
}
