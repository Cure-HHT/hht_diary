import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_scaffold.dart';

/// Page for requesting password reset.
///
/// Always shows a generic success message after submit, regardless of whether
/// the email exists — prevents email enumeration attacks.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final email = _emailController.text.trim();

    try {
      final success = await authService.requestPasswordReset(email);

      if (!mounted) return;

      if (success) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              authService.error ?? 'Failed to send password reset email';
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

  @override
  Widget build(BuildContext context) {
    if (_emailSent) return const _CheckEmailScaffold();
    return AuthScaffold(
      title: 'Forgot your password?',
      subtitle: 'Enter your email and we will send you a link to reset it.',
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
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              validator: Validators.email,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AppBanner(
                severity: AppBannerSeverity.error,
                message: _errorMessage!,
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Submit',
              fullWidth: true,
              loading: _isLoading,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 12),
            Center(
              child: AppButton(
                variant: AppButtonVariant.tertiary,
                label: 'Back to Login',
                onPressed: _isLoading ? null : () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckEmailScaffold extends StatelessWidget {
  const _CheckEmailScaffold();

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Check your email',
      subtitle:
          'If an account exists with that email, you will receive a password '
          'reset link within a few minutes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Back to Login',
            fullWidth: true,
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
