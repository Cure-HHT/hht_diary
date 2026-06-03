import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  http.Client get _http => widget.httpClient ?? http.Client();

  @override
  void dispose() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset your password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _confirmed ? _buildConfirmation(context) : _buildRequest(),
          ),
        ),
      ),
    );
  }

  Widget _buildRequest() {
    final ready = isValidEmail(_email.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (!ready || _submitting) ? null : _submit,
          child: Text(_submitting ? 'Sending…' : 'Send reset link'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "If that email is registered, we've sent a reset link. "
          'It expires in 24 hours. '
          "Check your spam folder if you don't see it.",
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
