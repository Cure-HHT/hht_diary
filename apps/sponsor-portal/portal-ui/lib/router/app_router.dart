// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/activation_page.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../pages/dev_admin/dev_admin_dashboard_page.dart';
import '../pages/login_page.dart';
import '../pages/role_picker_page.dart';
import '../pages/two_factor_setup_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/select-role',
      name: 'select-role',
      builder: (context, state) => const RolePickerPage(),
    ),
    GoRoute(
      path: '/activate',
      name: 'activate',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return ActivationPage(code: code);
      },
    ),
    GoRoute(
      path: '/activate/2fa',
      name: 'activate-2fa',
      builder: (context, state) {
        // Get activation code from extra data passed from ActivationPage
        final extra = state.extra as Map<String, dynamic>?;
        final code = extra?['code'] as String? ?? '';
        return TwoFactorSetupPage(activationCode: code);
      },
    ),
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/dev-admin',
      name: 'dev-admin',
      builder: (context, state) => const DevAdminDashboardPage(),
    ),
    // Placeholder routes for other roles - redirect to login for now
    GoRoute(
      path: '/investigator',
      name: 'investigator',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/auditor',
      name: 'auditor',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/analyst',
      name: 'analyst',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/sponsor',
      name: 'sponsor',
      redirect: (context, state) => '/login',
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${state.uri}'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    ),
  ),
);
