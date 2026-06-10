import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_scaffold.dart';
import 'login_logic.dart';

/// Two-state screen: request (email form) → confirmation.
/// Reached by tapping "Forgot password?" on the LoginScreen.
// Implements: DIARY-GUI-password-forgot-workflow/A+B+C+D+E+F+G+H+I+J+K
class ForgotPasswordRequestScreen extends StatefulWidget {
  const ForgotPasswordRequestScreen({
    super.key,
    required this.serverUrl,
    this.httpClient,
  });
  final String serverUrl;
  final http.Client? httpClient;

  @override
  State<ForgotPasswordRequestScreen> createState() =>
      _ForgotPasswordRequestScreenState();
}

class _ForgotPasswordRequestScreenState
    extends State<ForgotPasswordRequestScreen> {
  final _email = TextEditingController();
  bool _submitting = false;
  bool _confirmed = false;

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
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Best-effort POST — always advance to confirmation regardless of result
      // to prevent account enumeration (GUI/K).
      await _http.post(
        Uri.parse('${widget.serverUrl}/password-reset/request'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email.text}),
      );
    } catch (_) {
      // Swallow errors; confirmation state is shown regardless (GUI/K).
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _confirmed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return AuthScaffold(
        semanticId: 'forgot-confirm-screen',
        title: 'Check your email',
        subtitle:
            "If that email is registered, we've sent a reset link. It expires "
            "in 24 hours. Check your spam folder if you don't see it.",
        child: AuthLinkButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
          semanticId: 'back-to-login',
        ),
      );
    }

    final ready = isValidEmail(_email.text);
    final emailError = _email.text.isNotEmpty && !ready
        ? 'Enter a valid email address.'
        : null;

    return AuthScaffold(
      semanticId: 'forgot-screen',
      title: 'Forgot your password?',
      subtitle: "Enter your email and we'll send you a link to reset it.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _email,
            label: 'Email',
            hintText: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            errorText: emailError,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => (ready && !_submitting) ? _submit() : null,
            semanticId: 'forgot-email',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Submit',
            fullWidth: true,
            loading: _submitting,
            onPressed: ready ? _submit : null,
            semanticId: 'forgot-submit',
          ),
          const SizedBox(height: 8),
          AuthLinkButton(
            label: 'Back to Login',
            onPressed: () => Navigator.of(context).pop(),
            semanticId: 'back-to-login',
          ),
        ],
      ),
    );
  }
}
