import 'package:flutter/material.dart';
import 'package:sponsor_portal_ui/pages/admin/admin_dashboard_page.dart';
import 'package:sponsor_portal_ui/pages/analyst/analyst_dashboard_page.dart';
import 'package:sponsor_portal_ui/pages/auditor/auditor_dashboard_page.dart';
import 'package:sponsor_portal_ui/pages/dev_admin/dev_admin_dashboard_page.dart';
import 'package:sponsor_portal_ui/pages/investigator/investigator_dashboard_page.dart';
import 'package:sponsor_portal_ui/pages/sponsor/sponsor_dashboard_page.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';
import 'package:sponsor_portal_ui/widgets/user_activity_listener.dart';

class CommonDashboard extends StatelessWidget {
  const CommonDashboard({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return UserActivityListener(
      child: switch (role) {
        UserRole.developerAdmin => const DevAdminDashboardPage(),
        UserRole.administrator => const AdminDashboardPage(),
        UserRole.investigator => const InvestigatorDashboardPage(),
        UserRole.auditor => const AuditorDashboardPage(),
        UserRole.analyst => const AnalystDashboardPage(),
        UserRole.sponsor => const SponsorDashboardPage(),
      },
    );
  }
}
