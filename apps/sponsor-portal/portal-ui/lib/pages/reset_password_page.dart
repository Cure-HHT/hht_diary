// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00071: Password Complexity
//   REQ-d00031: Identity Platform Integration

import 'dart:async';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_scaffold.dart';

/// Page for resetting password using a reset code from a magic link.
///
/// The URL carries an oobCode (Firebase out-of-band code) we verify on mount.
/// On success the user enters a new password; we then bounce to /login after
/// a short countdown.
class ResetPasswordPage extends StatefulWidget {
  final String? oobCode;

  const ResetPasswordPage({super.key, this.oobCode});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isVerifying = true;
  bool _codeVerified = false;
  bool _resetComplete = false;
  String? _errorMessage;
  int _redirectCountdown = 3;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    if (widget.oobCode == null || widget.oobCode!.isEmpty) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or missing reset code';
      });
      return;
    }

    final authService = context.read<AuthService>();

    try {
      final email = await authService.verifyPasswordResetCode(widget.oobCode!);
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        if (email != null) {
          _codeVerified = true;
        } else {
          _errorMessage =
              'This password reset link is invalid or has expired. '
              'Please request a new one.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Failed to verify reset code. Please try again.';
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();

    try {
      final success = await authService.confirmPasswordReset(
        widget.oobCode!,
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _resetComplete = true;
          _isLoading = false;
        });
        _startRedirectTimer();
      } else {
        setState(() {
          _errorMessage =
              authService.error ??
              'Failed to reset password. The link may have expired.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _redirectCountdown--);
      if (_redirectCountdown <= 0) {
        timer.cancel();
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) return const _VerifyingScaffold();
    if (_resetComplete) {
      return _SuccessScaffold(
        countdown: _redirectCountdown,
        onGoToLogin: () {
          _redirectTimer?.cancel();
          context.go('/login');
        },
      );
    }
    if (!_codeVerified) {
      return _InvalidLinkScaffold(
        message: _errorMessage ?? 'Invalid reset link',
      );
    }
    return AuthScaffold(
      title: 'Create new password',
      subtitle: 'Your password must be at least 8 characters long',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _passwordController,
              label: 'New Password',
              hintText: 'Enter your password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
              suffixIcon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onSuffixTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: Validators.newPassword,
              semanticId: 'reset-password.new',
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hintText: 'Enter your password',
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              suffixIcon: _obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onSuffixTap: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              onSubmitted: (_) => _handleSubmit(),
              validator: Validators.confirmPassword(
                () => _passwordController.text,
              ),
              semanticId: 'reset-password.confirm',
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AppBanner(
                severity: AppBannerSeverity.error,
                message: _errorMessage!,
                semanticId: 'reset-password.error-banner',
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Verify',
              fullWidth: true,
              loading: _isLoading,
              onPressed: _handleSubmit,
              semanticId: 'reset-password.submit',
            ),
            const SizedBox(height: 12),
            Center(
              child: AppButton(
                variant: AppButtonVariant.tertiary,
                label: 'Back to Login',
                onPressed: _isLoading ? null : () => context.go('/login'),
                semanticId: 'reset-password.back',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyingScaffold extends StatelessWidget {
  const _VerifyingScaffold();

  @override
  Widget build(BuildContext context) {
    return const AuthScaffold(
      title: 'Verifying reset link',
      subtitle: 'Please wait while we verify your reset link.',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SuccessScaffold extends StatelessWidget {
  final int countdown;
  final VoidCallback onGoToLogin;

  const _SuccessScaffold({required this.countdown, required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Password reset complete',
      subtitle:
          'Your password has been reset. Redirecting to login in '
          '$countdown seconds.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Go to Login Now',
            fullWidth: true,
            onPressed: onGoToLogin,
            semanticId: 'reset-password.go-to-login',
          ),
        ],
      ),
    );
  }
}

class _InvalidLinkScaffold extends StatelessWidget {
  final String message;

  const _InvalidLinkScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Invalid reset link',
      subtitle:
          'We could not verify this reset link. You can request a new one '
          'from the forgot-password screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBanner(
            severity: AppBannerSeverity.error,
            message: message,
            semanticId: 'reset-password.invalid-link-banner',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Request New Reset Link',
            fullWidth: true,
            onPressed: () => context.go('/forgot-password'),
            semanticId: 'reset-password.request-new-link',
          ),
          const SizedBox(height: 12),
          Center(
            child: AppButton(
              variant: AppButtonVariant.tertiary,
              label: 'Back to Login',
              onPressed: () => context.go('/login'),
              semanticId: 'reset-password.back',
            ),
          ),
        ],
      ),
    );
  }
}
