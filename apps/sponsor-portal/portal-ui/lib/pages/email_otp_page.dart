// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Email OTP verification page for non-Developer-Admin users
// Users enter the 6-digit code sent to their email after password auth

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/error_message.dart';

class EmailOtpPage extends StatefulWidget {
  const EmailOtpPage({super.key});

  @override
  State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isSendingCode = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the code input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // Send OTP code on page load
    _sendOtpCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtpCode() async {
    if (_isSendingCode || _resendCooldown > 0) return;

    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.sendEmailOtp();

    if (!mounted) return;

    setState(() {
      _isSendingCode = false;
      if (!result.success) {
        _error = result.error ?? 'Failed to send verification code';
      }
      // Start cooldown for resend button
      _startResendCooldown();
    });
  }

  void _startResendCooldown() {
    _resendCooldown = 60; // 60 seconds cooldown
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final result = await authService.verifyEmailOtp(
      _codeController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      // Navigate to dashboard
      _navigateAfterVerification(authService);
    } else {
      setState(() {
        _error = result.error ?? 'Invalid verification code';
        // Clear the code input on error
        _codeController.clear();
        _focusNode.requestFocus();
      });
    }
  }

  void _navigateAfterVerification(AuthService authService) {
    final user = authService.currentUser!;

    // If user has multiple roles, go to role picker
    if (user.hasMultipleRoles) {
      context.go('/select-role');
      return;
    }

    // Navigate based on active role
    switch (user.activeRole) {
      case UserRole.developerAdmin:
        context.go('/dev-admin');
      case UserRole.administrator:
        context.go('/admin');
      case UserRole.investigator:
        context.go('/investigator');
      case UserRole.auditor:
        context.go('/auditor');
      case UserRole.analyst:
        context.go('/analyst');
      case UserRole.sponsor:
        context.go('/sponsor');
    }
  }

  void _cancelAndGoBack() {
    final authService = context.read<AuthService>();
    authService.cancelEmailOtp();
    authService.signOut();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final maskedEmail = authService.maskedEmail ?? 'your email';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email icon
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Check your email',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a verification code to\n$maskedEmail',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Code input
                      TextFormField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                          hintText: '000000',
                          prefixIcon: Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: 8,
                        ),
                        textAlign: TextAlign.center,
                        onFieldSubmitted: (_) => _verifyCode(),
                        onChanged: (value) {
                          // Auto-submit when 6 digits entered
                          if (value.length == 6) {
                            _verifyCode();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the verification code';
                          }
                          if (value.length != 6) {
                            return 'Code must be 6 digits';
                          }
                          return null;
                        },
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ErrorMessage(
                          message: _error!,
                          supportEmail: const String.fromEnvironment(
                            'SUPPORT_EMAIL',
                          ),
                          onDismiss: () => setState(() => _error = null),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Verify button
                      FilledButton(
                        onPressed: _isLoading ? null : _verifyCode,
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
                            : const Text('Verify'),
                      ),
                      const SizedBox(height: 16),

                      // Resend code button
                      TextButton(
                        onPressed: (_isSendingCode || _resendCooldown > 0)
                            ? null
                            : _sendOtpCode,
                        child: _isSendingCode
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sending...',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _resendCooldown > 0
                                    ? 'Resend code in $_resendCooldown s'
                                    : 'Resend code',
                              ),
                      ),
                      const SizedBox(height: 8),

                      // Cancel / back to login
                      TextButton(
                        onPressed: _cancelAndGoBack,
                        child: const Text('Cancel'),
                      ),

                      // Timer info
                      const SizedBox(height: 16),
                      Text(
                        'Code expires in 10 minutes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
