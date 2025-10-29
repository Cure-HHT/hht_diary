// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00025: Patient Enrollment Workflow
//   REQ-p00026: Patient Monitoring Dashboard
//   REQ-p00027: Questionnaire Management
//   REQ-p00030: Role-Based Visual Indicators
//   REQ-d00052: Role-Based Banner Component

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/portal_app_bar.dart';
import '../../widgets/portal_drawer.dart';
import '../../widgets/role_banner.dart';
import 'patient_enrollment_tab.dart';
import 'patient_monitoring_tab.dart';

class InvestigatorDashboardPage extends StatefulWidget {
  const InvestigatorDashboardPage({super.key});

  @override
  State<InvestigatorDashboardPage> createState() =>
      _InvestigatorDashboardPageState();
}

class _InvestigatorDashboardPageState
    extends State<InvestigatorDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Check authentication and role
    if (!authService.isAuthenticated ||
        !authService.hasRole(UserRole.investigator)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = [
      const PatientMonitoringTab(),
      const PatientEnrollmentTab(),
    ];

    return Scaffold(
      appBar: const PortalAppBar(title: 'Investigator Dashboard'),
      drawer: const PortalDrawer(),
      body: Column(
        children: [
          RoleBanner(role: authService.currentUser!.role),
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
                      icon: Icon(Icons.monitor_heart_outlined),
                      selectedIcon: Icon(Icons.monitor_heart),
                      label: Text('Monitor'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_add_outlined),
                      selectedIcon: Icon(Icons.person_add),
                      label: Text('Enroll'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: tabs[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
