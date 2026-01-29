// IMPLEMENTS REQUIREMENTS:
//   REQ-p00044: Password Reset
//   REQ-p00071: Password Complexity
//   REQ-d00031: Identity Platform Integration

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/error_message.dart';

/// Page for resetting password using a reset code
///
/// This page is accessed via a link sent to the user's email.
/// The URL contains an oobCode (out-of-band code) parameter that
/// Firebase uses to verify the reset request.
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
  bool _resetComplete = false;
  String? _errorMessage;
  String? _userEmail;
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

  /// Verify the reset code is valid
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

      if (email != null) {
        setState(() {
          _userEmail = email;
          _isVerifying = false;
        });
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'This password reset link is invalid or has expired. '
              'Please request a new one.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isVerifying = false;
        _errorMessage = 'Failed to verify reset code. Please try again.';
      });
    }
  }

  /// Handle password reset submission
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final newPassword = _passwordController.text;

    try {
      final success = await authService.confirmPasswordReset(
        widget.oobCode!,
        newPassword,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _resetComplete = true;
          _isLoading = false;
        });

        // Start countdown timer for redirect
        _startRedirectTimer();
      } else {
        setState(() {
          _errorMessage =
              authService.error ??
              'Failed to reset password. The link may have expired.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Start countdown timer and redirect to login
  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _redirectCountdown--;
      });

      if (_redirectCountdown <= 0) {
        timer.cancel();
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isVerifying) {
      return _buildVerifyingView();
    } else if (_resetComplete) {
      return _buildSuccessView();
    } else if (_errorMessage != null && _userEmail == null) {
      return _buildErrorView();
    } else {
      return _buildFormView();
    }
  }

  Widget _buildVerifyingView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Verifying reset link...',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          Icon(Icons.lock_reset, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),

          // Title
          Text(
            'Create New Password',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Show email if available
          if (_userEmail != null) ...[
            Text(
              'for $_userEmail',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 24),

          // Password field
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              helperText: 'Minimum 8 characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (value.length > 64) {
                return 'Password must be less than 64 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password field
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleSubmit(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          // Password requirements
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Requirements:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRequirement('Minimum 8 characters'),
                _buildRequirement('Maximum 64 characters'),
                _buildRequirement('Any printable characters allowed'),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            ErrorMessage(
              message: _errorMessage!,
              supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
            ),
          ],
          const SizedBox(height: 24),

          // Reset button
          FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Reset Password'),
          ),
          const SizedBox(height: 16),

          // Back to login link
          TextButton(
            onPressed: _isLoading ? null : () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),

        // Title
        Text(
          'Password Reset Complete',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Success message
        Text(
          'Your password has been successfully reset.\n\n'
          'You can now sign in with your new password.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Countdown message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Redirecting to login in $_redirectCountdown seconds...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),

        // Go to login button
        FilledButton(
          onPressed: () {
            _redirectTimer?.cancel();
            context.go('/login');
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Go to Login Now'),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error icon
        Icon(Icons.error_outline, size: 64, color: colorScheme.error),
        const SizedBox(height: 16),

        // Title
        Text(
          'Invalid Reset Link',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Error message
        ErrorMessage(
          message: _errorMessage!,
          supportEmail: const String.fromEnvironment('SUPPORT_EMAIL'),
        ),
        const SizedBox(height: 24),

        // Request new link button
        FilledButton(
          onPressed: () => context.go('/forgot-password'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Request New Reset Link'),
        ),
        const SizedBox(height: 16),

        // Back to login link
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
