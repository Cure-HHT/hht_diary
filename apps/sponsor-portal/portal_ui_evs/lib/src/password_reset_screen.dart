import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'activation_link.dart';
import 'forgot_password_request_screen.dart';

/// Public password-reset page reached via the emailed magic link (?reset=...).
/// Not part of the reactive authed shell.
// Implements: DIARY-GUI-password-forgot-workflow/L+M+N+O+P+Q+R+S+T+U
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    required this.serverUrl,
    required this.code,
    this.httpClient,
    this.onBackToLogin,
  });
  final String serverUrl;
  final String code;
  final http.Client? httpClient;

  /// Called when the user taps "Back to Login" on the success (done) view.
  /// If null, falls back to [Navigator.maybePop].
  final VoidCallback? onBackToLogin;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  bool _loading = true;
  bool _valid = false;
  String? _inlineError;
  String? _done;
  bool _submitting = false;

  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPw = false;
  bool _showConfirm = false;

  http.Client get _http => widget.httpClient ?? http.Client();

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    try {
      final r = await _http.get(
        Uri.parse('${widget.serverUrl}/password-reset/${widget.code}'),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      setState(() {
        _loading = false;
        _valid = r.statusCode == 200 && body['valid'] == true;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _valid = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!passwordsMatch(_pw.text, _confirm.text)) {
      setState(() => _inlineError = 'Passwords must match and be non-empty.');
      return;
    }
    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    try {
      final r = await _http.post(
        Uri.parse('${widget.serverUrl}/password-reset'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.code, 'password': _pw.text}),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      setState(() {
        _submitting = false;
        if (r.statusCode == 200 && body['ok'] == true) {
          _done = 'Password changed — you can now sign in.';
        } else if (r.statusCode == 400) {
          _inlineError = (body['message'] as String?)?.isNotEmpty == true
              ? body['message'] as String
              : 'Reset failed.';
        } else {
          _inlineError = 'Reset failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _inlineError = 'Reset failed. Please try again.';
      });
    }
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
            child: _loading
                ? const CircularProgressIndicator()
                : _done != null
                ? _buildDone(context)
                : !_valid
                ? _buildInvalidLink(context)
                : _buildResetForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_done!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        TextButton(
          onPressed:
              widget.onBackToLogin ?? () => Navigator.of(context).maybePop(),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  Widget _buildInvalidLink(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('This reset link is no longer valid.'),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ForgotPasswordRequestScreen(
                serverUrl: widget.serverUrl,
                httpClient: widget.httpClient,
              ),
            ),
          ),
          child: const Text('Request a new reset'),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    final ready = passwordsMatch(_pw.text, _confirm.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pw,
          obscureText: !_showPw,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New password',
            suffixIcon: IconButton(
              icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPw = !_showPw),
            ),
          ),
        ),
        TextField(
          controller: _confirm,
          obscureText: !_showConfirm,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Confirm password',
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_inlineError != null)
          Text(_inlineError!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: (!ready || _submitting) ? null : _submit,
          child: Text(_submitting ? 'Resetting…' : 'Reset password'),
        ),
      ],
    );
  }
}
