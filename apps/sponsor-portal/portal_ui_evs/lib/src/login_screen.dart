import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  });
  final String serverUrl;
  final FirebaseAuthClient authClient;
  final void Function(String sessionToken) onSession;
  final http.Client? httpClient;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
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
          _error = 'Sign-in failed.';
        });
        return;
      }
      final body = jsonDecode(r.body) as Map<String, Object?>;
      if (!mounted) return;
      switch (loginNextStep(body)) {
        case LoginNextSession(:final token):
          widget.onSession(token);
        case LoginNextOtp(:final maskedEmail):
          Navigator.of(context).push(
            MaterialPageRoute(
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
        _error = 'Sign-in failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = loginFormReady(email: _email.text, password: _pw.text);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _pw,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: (!ready || _busy) ? null : _submit,
              child: Text(_busy ? 'Signing in…' : 'Sign in'),
            ),
            // Implements: DIARY-GUI-password-forgot-workflow/A
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ForgotPasswordRequestScreen(serverUrl: widget.serverUrl),
                ),
              ),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}
