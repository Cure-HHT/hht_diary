import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
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
    this.appVersion = '',
  });
  final String serverUrl;
  final FirebaseAuthClient authClient;

  /// Called when a session is established. [displayName] is the user's human
  /// name when the server supplied one — used to greet them by name on the
  /// role-selection screen; null falls back to the email.
  // Implements: DIARY-GUI-role-switching/H
  final void Function(String sessionToken, {String? displayName}) onSession;
  final http.Client? httpClient;

  /// Optional non-error notice shown above the form — e.g. "Session ended —
  /// please sign in again." Rendered as an info banner inside the card.
  final String? notice;

  /// This bundle's full `<semver>+<build_id>` (APP_VERSION) — the value
  /// that gets the per-build random `+local-XXXXXX` id on local-stack
  /// builds. Rendered as a discreet centered footer under the form so a
  /// glance at the login screen identifies the exact running build.
  /// Empty (local `flutter run` without the define) renders nothing.
  final String appVersion;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  String? _error;
  bool _busy = false;

  /// Lazily-created client owned by this state when none is injected —
  /// one client for the screen's lifetime, closed in [dispose]. An
  /// injected client is the owner's to close.
  http.Client? _ownedClient;

  http.Client get _http =>
      widget.httpClient ?? (_ownedClient ??= http.Client());

  @override
  void dispose() {
    _ownedClient?.close();
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
        // Trimmed: a trailing space from autofill/paste must not turn into
        // an opaque sign-in failure.
        email: _email.text.trim(),
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
          _error = signInErrorForLoginStatus(r.statusCode);
        });
        return;
      }
      final body = jsonDecode(r.body) as Map<String, Object?>;
      if (!mounted) return;
      switch (loginNextStep(body)) {
        case LoginNextSession(:final token, :final displayName):
          widget.onSession(token, displayName: displayName);
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
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = signInErrorForAuthCode(e.code);
      });
    } on http.ClientException {
      // The POST /login transport failed — the portal itself was
      // unreachable, not a credential problem.
      setState(() {
        _busy = false;
        _error = unreachableSignInError;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = credentialSignInError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    final ready = loginFormReady(email: email, password: _pw.text);
    final emailError = email.isNotEmpty && !isValidEmail(email)
        ? 'Enter a valid email address.'
        : null;

    return AuthScaffold(
      semanticId: 'login-screen',
      title: 'Sponsor Portal',
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
          if (widget.appVersion.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              identifier: 'login-version',
              container: true,
              explicitChildNodes: true,
              child: Text(
                'Version ${widget.appVersion}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  height: 16 / 11,
                  letterSpacing: -0.1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
