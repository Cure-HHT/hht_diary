import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_message.dart';
import '../widgets/totp_input_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    setState(() => _isSubmitting = true);
    try {
      if (!mounted) return;
      if (authService.isTimedOut) {
        authService.setIsTimedOut(false);
      }

      final success = await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      // Developer Admin: TOTP MFA required.
      if (success && authService.mfaRequired) {
        await _handleMfaChallenge(authService);
        return;
      }

      // Standard users: email OTP required.
      if (success && authService.emailOtpRequired) {
        context.go('/login/email-otp');
        return;
      }

      if (success && authService.currentUser != null) {
        _navigateAfterLogin(authService);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleMfaChallenge(AuthService authService) async {
    final totpCode = await TotpInputDialog.show(context);

    if (!mounted) return;

    if (totpCode == null) {
      authService.cancelMfa();
      return;
    }

    final success = await authService.completeMfaSignIn(totpCode);

    if (!mounted) return;

    if (success && authService.currentUser != null) {
      _navigateAfterLogin(authService);
    }
  }

  void _navigateAfterLogin(AuthService authService) {
    final user = authService.currentUser!;
    if (user.hasMultipleRoles) {
      context.go('/select-role');
      return;
    }
    context.go('/common-dashboard', extra: user.activeRole);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return AuthScaffold(
      subtitle: 'Sign in to access your dashboard',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _emailController,
              label: 'Email',
              hintText: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              validator: Validators.email,
              semanticId: 'login.email',
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Enter your password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              suffixIcon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onSuffixTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: Validators.password,
              semanticId: 'login.password',
            ),

            // Session timeout + error states.
            if (authService.isTimedOut && authService.error == null) ...[
              const SizedBox(height: 16),
              const AppBanner(
                severity: AppBannerSeverity.warning,
                message: 'Your session has expired due to inactivity.',
                semanticId: 'login.session-timeout-banner',
              ),
            ],
            if (authService.error != null) ...[
              const SizedBox(height: 16),
              // ErrorMessage isn't a design-system widget yet, so wrap it
              // inline to expose the same flt-semantics-identifier contract
              // the test harness queries.
              Semantics(
                identifier: 'login.error-banner',
                value: authService.error!,
                liveRegion: true,
                container: true,
                explicitChildNodes: true,
                child: ErrorMessage(
                  message: authService.error!,
                  supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
                ),
              ),
            ],

            const SizedBox(height: 24),
            AppButton(
              label: 'Sign in',
              fullWidth: true,
              loading: _isSubmitting,
              onPressed: _handleLogin,
              semanticId: 'login.submit',
            ),
            const SizedBox(height: 12),
            Center(
              child: AppButton(
                variant: AppButtonVariant.tertiary,
                label: 'Forgot password?',
                onPressed: _isSubmitting
                    ? null
                    : () => context.go('/forgot-password'),
                semanticId: 'login.forgot-link',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
