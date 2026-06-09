import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_scaffold.dart';
import 'firebase_auth_client.dart';
import 'forgot_password_request_screen.dart';
import 'login_logic.dart';
import 'otp_screen.dart';

// Implements: DIARY-PRD-two-factor-authentication/A+B (client login flow)
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.serverUrl,
    required this.authClient,
    required this.onSession,
    this.httpClient,
    this.notice,
  });
  final String serverUrl;
  final FirebaseAuthClient authClient;
  final void Function(String sessionToken) onSession;
  final http.Client? httpClient;

  /// Optional non-error notice shown above the form — e.g. "Session ended —
  /// please sign in again." Rendered as an info banner inside the card.
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  String? _error;
  bool _busy = false;

  http.Client get _http => widget.httpClient ?? http.Client();

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await widget.authClient.signInAndGetIdToken(
        email: _email.text,
        password: _pw.text,
      );
      final r = await _http.post(
        Uri.parse('${widget.serverUrl}/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      if (r.statusCode != 200) {
        setState(() {
          _busy = false;
          _error = 'Sign-in failed. Check your email and password.';
        });
        return;
      }
      final body = jsonDecode(r.body) as Map<String, Object?>;
      if (!mounted) return;
      switch (loginNextStep(body)) {
        case LoginNextSession(:final token):
          widget.onSession(token);
        case LoginNextOtp(:final maskedEmail):
          // Clear the in-flight state before navigating so that returning from
          // the OTP screen ("Back to Login") lands on a usable, re-submittable
          // login form rather than one stuck disabled/loading.
          setState(() => _busy = false);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OtpScreen(
                serverUrl: widget.serverUrl,
                idToken: idToken,
                maskedEmail: maskedEmail,
                onSession: widget.onSession,
                httpClient: widget.httpClient,
              ),
            ),
          );
      }
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Sign-in failed. Check your email and password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = loginFormReady(email: _email.text, password: _pw.text);
    final emailError = _email.text.isNotEmpty && !isValidEmail(_email.text)
        ? 'Enter a valid email address.'
        : null;

    return AuthScaffold(
      semanticId: 'login-screen',
      title: 'Clinical Trial Portal',
      subtitle: 'Sign in to access your dashboard',
      banner: _error != null
          ? AppBanner(
              severity: AppBannerSeverity.error,
              message: _error!,
              semanticId: 'login-error',
            )
          : (widget.notice != null
                ? AppBanner(
                    severity: AppBannerSeverity.info,
                    message: widget.notice!,
                    semanticId: 'login-notice',
                  )
                : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _email,
            label: 'Email',
            hintText: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: emailError,
            onChanged: (_) => setState(() {}),
            semanticId: 'login-email',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _pw,
            label: 'Password',
            hintText: 'Enter your password',
            obscureText: !_showPw,
            textInputAction: TextInputAction.done,
            suffixIcon: _showPw ? Icons.visibility_off : Icons.visibility,
            onSuffixTap: () => setState(() => _showPw = !_showPw),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => (ready && !_busy) ? _submit() : null,
            semanticId: 'login-password',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign In',
            fullWidth: true,
            loading: _busy,
            onPressed: ready ? _submit : null,
            semanticId: 'login-submit',
          ),
          const SizedBox(height: 8),
          // Implements: DIARY-GUI-password-forgot-workflow/A
          AppButton(
            variant: AppButtonVariant.tertiary,
            label: 'Forgot password?',
            fullWidth: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForgotPasswordRequestScreen(
                  serverUrl: widget.serverUrl,
                  httpClient: widget.httpClient,
                ),
              ),
            ),
            semanticId: 'login-forgot',
          ),
        ],
      ),
    );
  }
}
