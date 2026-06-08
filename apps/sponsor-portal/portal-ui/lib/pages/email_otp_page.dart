// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Email OTP verification page for non-Developer-Admin users
// Users enter the 6-digit code sent to their email after password auth

import 'dart:async';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/auth_scaffold.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _sendOtpCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Default cooldown after a successful send, to discourage spam.
  static const int _successCooldownSeconds = 60;

  Future<void> _sendOtpCode() async {
    if (_isSendingCode || _resendCooldown > 0) return;

    setState(() {
      _isSendingCode = true;
      _error = null;
      // Optimistic cooldown — locks the resend button the moment the request
      // goes out so the page-load auto-send and any slow-reply race can't
      // produce duplicate sends. Adjusted below based on the response.
      _startResendCooldown(_successCooldownSeconds);
    });

    final authService = context.read<AuthService>();
    final result = await authService.sendEmailOtp();

    if (!mounted) return;

    setState(() {
      _isSendingCode = false;
      if (result.success) {
        // Optimistic cooldown already running — nothing more to do.
      } else if (result.retryAfter != null && result.retryAfter! > 0) {
        final waitSeconds = result.retryAfter!;
        final baseError = result.error ?? 'Too many OTP requests.';
        _error =
            '$baseError Please wait ${_formatWaitDuration(waitSeconds)} '
            'before trying again.';
        _startResendCooldown(waitSeconds);
      } else {
        // Transient failure: keep the optimistic cooldown so the user can't
        // hammer the button while server state is unknown.
        _error = result.error ?? 'Failed to send verification code';
      }
    });
  }

  void _startResendCooldown(int seconds) {
    _resendCooldown = seconds;
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

  /// Formats the resend countdown for the button label.
  ///   < 60s → "12 s"
  ///   ≥ 60s → "mm:ss" (e.g. "14:59")
  String _formatCooldown(int seconds) {
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  /// Formats the wait time for the human-readable error message.
  String _formatWaitDuration(int seconds) {
    if (seconds < 60) {
      return seconds == 1 ? '1 second' : '$seconds seconds';
    }
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    final minutesPart = minutes == 1 ? '1 minute' : '$minutes minutes';
    if (remainder == 0) return minutesPart;
    final secondsPart = remainder == 1 ? '1 second' : '$remainder seconds';
    return '$minutesPart $secondsPart';
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
      _navigateAfterVerification(authService);
    } else {
      setState(() {
        _error = result.error ?? 'Invalid verification code';
        _codeController.clear();
        _focusNode.requestFocus();
      });
    }
  }

  void _navigateAfterVerification(AuthService authService) {
    final user = authService.currentUser!;
    if (user.hasMultipleRoles) {
      context.go('/select-role');
      return;
    }
    context.go('/common-dashboard', extra: user.activeRole);
  }

  Future<void> _backToLogin() async {
    final authService = context.read<AuthService>();
    authService.cancelEmailOtp();
    await authService.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the verification code';
    }
    if (value.length != 6) {
      return 'Code must be 6 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_isSendingCode && _resendCooldown == 0;
    final resendLabel = _resendCooldown > 0
        ? 'Resend code in ${_formatCooldown(_resendCooldown)}'
        : 'Resend code';

    return AuthScaffold(
      title: 'Enter verification code',
      subtitle: 'We sent a 6-digit code to your email.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _codeController,
              focusNode: _focusNode,
              label: 'Verification Code',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _verifyCode(),
              onChanged: (value) {
                if (value.length == 6) _verifyCode();
              },
              validator: _validateCode,
              semanticId: 'email-otp.code',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                variant: AppButtonVariant.tertiary,
                label: resendLabel,
                loading: _isSendingCode,
                onPressed: canResend ? _sendOtpCode : null,
                semanticId: 'email-otp.resend',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppBanner(
                severity: AppBannerSeverity.error,
                message: _error!,
                semanticId: 'email-otp.error-banner',
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Verify',
              fullWidth: true,
              loading: _isLoading,
              onPressed: _verifyCode,
              semanticId: 'email-otp.submit',
            ),
            const SizedBox(height: 12),
            Center(
              child: AppButton(
                variant: AppButtonVariant.tertiary,
                label: 'Back to Login',
                onPressed: _isLoading ? null : _backToLogin,
                semanticId: 'email-otp.back',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
