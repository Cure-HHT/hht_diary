// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00028: Portal Frontend Framework
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/activation_page.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../pages/analyst/analyst_dashboard_page.dart';
import '../pages/auditor/auditor_dashboard_page.dart';
import '../pages/dev_admin/dev_admin_dashboard_page.dart';
import '../pages/email_otp_page.dart';
import '../pages/investigator/investigator_dashboard_page.dart';
import '../pages/sponsor/sponsor_dashboard_page.dart';
import '../pages/forgot_password_page.dart';
import '../pages/login_page.dart';
import '../pages/reset_password_page.dart';
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
      path: '/login/email-otp',
      name: 'login-email-otp',
      builder: (context, state) => const EmailOtpPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) {
        // Support both 'oobCode' (Firebase standard) and 'code' (our API)
        final oobCode =
            state.uri.queryParameters['oobCode'] ??
            state.uri.queryParameters['code'];
        return ResetPasswordPage(oobCode: oobCode);
      },
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
    GoRoute(
      path: '/analyst',
      name: 'analyst',
      builder: (context, state) => const AnalystDashboardPage(),
    ),
    GoRoute(
      path: '/sponsor',
      name: 'sponsor',
      builder: (context, state) => const SponsorDashboardPage(),
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
