// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00080: Web Session Management Implementation

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sponsor_portal_ui/widgets/user_activity_listener.dart';

import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';

class SponsorDashboardPage extends StatelessWidget {
  const SponsorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);

    if (!authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // REQ-d00080-B, REQ-d00080-C: track user activity to reset inactivity timer.
    return UserActivityListener(
      child: Scaffold(
        appBar: const PortalAppBar(title: 'Sponsor Dashboard'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text('Sponsor Dashboard', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Study oversight and management features coming soon.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
