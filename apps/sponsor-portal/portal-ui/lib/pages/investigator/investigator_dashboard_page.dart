// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-CAL-p00073: Patient Status Definitions
//
// Investigator (Study Coordinator) dashboard with patients and audit logs tabs

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';
import 'patients_tab.dart';

/// Investigator dashboard page with navigation rail
class InvestigatorDashboardPage extends StatefulWidget {
  const InvestigatorDashboardPage({super.key});

  @override
  State<InvestigatorDashboardPage> createState() =>
      _InvestigatorDashboardPageState();
}

class _InvestigatorDashboardPageState extends State<InvestigatorDashboardPage> {
  int _selectedIndex = 0;

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

    final user = authService.currentUser!;

    return Scaffold(
      appBar: const PortalAppBar(title: 'Study Coordinator Dashboard'),
      body: Column(
        children: [
          // Role banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: theme.colorScheme.secondaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Logged in as ${user.role.displayName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
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
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt),
                      label: Text('Patients'),
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
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return const StudyCoordinatorPatientsTab();
      case 1:
        return _buildAuditLogsPlaceholder(theme);
      default:
        return const StudyCoordinatorPatientsTab();
    }
  }

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
}
