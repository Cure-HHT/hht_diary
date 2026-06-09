import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'activation_link.dart';
import 'auth_scaffold.dart';
import 'forgot_password_request_screen.dart';
import 'login_logic.dart';

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
  String? _formError;
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
    if (!meetsPasswordPolicy(_pw.text)) {
      setState(
        () => _formError =
            'Password must be at least $minPasswordLength characters.',
      );
      return;
    }
    if (!passwordsMatch(_pw.text, _confirm.text)) {
      setState(() => _formError = 'Passwords must match.');
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
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
          _formError = (body['message'] as String?)?.isNotEmpty == true
              ? body['message'] as String
              : 'Reset failed.';
        } else {
          _formError = 'Reset failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _formError = 'Reset failed. Please try again.';
      });
    }
  }

  void _backToLogin() {
    final cb = widget.onBackToLogin;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_done != null) {
      return AuthScaffold(
        semanticId: 'reset-done-screen',
        title: 'Password changed',
        subtitle: _done,
        child: AuthLinkButton(
          label: 'Back to Login',
          onPressed: _backToLogin,
          semanticId: 'back-to-login',
        ),
      );
    }
    if (!_valid) {
      return AuthScaffold(
        semanticId: 'reset-invalid-screen',
        title: 'Link expired',
        subtitle: 'This reset link is no longer valid.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Request a new reset',
              fullWidth: true,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ForgotPasswordRequestScreen(
                    serverUrl: widget.serverUrl,
                    httpClient: widget.httpClient,
                  ),
                ),
              ),
              semanticId: 'reset-request-new',
            ),
            const SizedBox(height: 8),
            AuthLinkButton(
              label: 'Back to Login',
              onPressed: _backToLogin,
              semanticId: 'back-to-login',
            ),
          ],
        ),
      );
    }
    return _buildResetForm();
  }

  Widget _buildResetForm() {
    final tooShort = _pw.text.isNotEmpty && !meetsPasswordPolicy(_pw.text);
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _pw.text
        ? 'Passwords do not match.'
        : null;
    final ready =
        meetsPasswordPolicy(_pw.text) &&
        passwordsMatch(_pw.text, _confirm.text);

    return AuthScaffold(
      semanticId: 'reset-screen',
      title: 'Create new password',
      subtitle:
          'Your password must be at least $minPasswordLength characters long',
      banner: _formError != null
          ? AppBanner(
              severity: AppBannerSeverity.error,
              message: _formError!,
              semanticId: 'reset-error',
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _pw,
            label: 'New Password',
            hintText: 'Enter new password',
            obscureText: !_showPw,
            textInputAction: TextInputAction.next,
            errorText: tooShort
                ? 'At least $minPasswordLength characters.'
                : null,
            suffixIcon: _showPw ? Icons.visibility_off : Icons.visibility,
            onSuffixTap: () => setState(() => _showPw = !_showPw),
            onChanged: (_) => setState(() {}),
            semanticId: 'reset-password',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _confirm,
            label: 'Confirm Password',
            hintText: 'Confirm new password',
            obscureText: !_showConfirm,
            textInputAction: TextInputAction.done,
            errorText: mismatch,
            suffixIcon: _showConfirm ? Icons.visibility_off : Icons.visibility,
            onSuffixTap: () => setState(() => _showConfirm = !_showConfirm),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => (ready && !_submitting) ? _submit() : null,
            semanticId: 'reset-confirm',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Reset Password',
            fullWidth: true,
            loading: _submitting,
            onPressed: ready ? _submit : null,
            semanticId: 'reset-submit',
          ),
          const SizedBox(height: 8),
          AuthLinkButton(
            label: 'Back to Login',
            onPressed: _backToLogin,
            semanticId: 'back-to-login',
          ),
        ],
      ),
    );
  }
}
