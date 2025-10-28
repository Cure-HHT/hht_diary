// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../pages/investigator/investigator_dashboard_page.dart';
import '../pages/auditor/auditor_dashboard_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/investigator',
      name: 'investigator',
      builder: (context, state) => const InvestigatorDashboardPage(),
    ),
    GoRoute(
      path: '/auditor',
      name: 'auditor',
      builder: (context, state) => const AuditorDashboardPage(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
