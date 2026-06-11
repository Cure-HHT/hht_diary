import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'activation_link.dart';
import 'auth_scaffold.dart';

/// Minimum password length, mirrored (not imported) from the server's
/// authoritative rule in portal_server_evs's activation route — the
/// packages sit on opposite sides of the trust boundary, and the server
/// enforces it regardless of what any client does.
const int kMinActivationPasswordLength = 8;

/// Public activation page reached via the emailed magic link (?code=...).
/// Not part of the reactive authed shell. Renders on the design-kit auth
/// card (Figma: Activate Your Account): sponsor logo, title, the password
/// rule as the subtitle, New/Confirm password fields with visibility
/// toggles, Verify, and Back to Login.
// Implements: DIARY-PRD-user-account-activation-workflow/H
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    required this.serverUrl,
    required this.code,
    this.onBackToLogin,
    this.httpClient,
  });
  final String serverUrl;
  final String code;

  /// Called from "Back to Login" (and the success view), so the app leaves
  /// the public activation page and shows the login screen. If null, falls
  /// back to [Navigator.maybePop].
  final VoidCallback? onBackToLogin;

  /// Injection point for tests; production uses a real client.
  final http.Client? httpClient;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _loading = true;
  bool _valid = false;
  String? _error;
  bool _done = false;
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPw = false;
  bool _showConfirm = false;
  bool _submitting = false;

  /// Lazily-created client owned by this state when none is injected —
  /// closed in [dispose]. An injected client is the owner's to close.
  http.Client? _ownedClient;

  http.Client get _http =>
      widget.httpClient ?? (_ownedClient ??= http.Client());

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    try {
      final r = await _http.get(
        Uri.parse('${widget.serverUrl}/activate/${widget.code}'),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (body['valid'] == true) {
          _valid = true;
        } else {
          _error = body['message'] as String?;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Please try again.';
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final r = await _http.post(
        Uri.parse('${widget.serverUrl}/activate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.code, 'password': _pw.text}),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (r.statusCode == 200 && body['ok'] == true) {
          _done = true;
        } else {
          _error = body['message'] as String? ?? 'Activation failed.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Activation failed. Please try again.';
      });
    }
  }

  void _backToLogin() =>
      (widget.onBackToLogin ?? () => Navigator.of(context).maybePop())();

  @override
  Widget build(BuildContext context) {
    final pwTooShort =
        _pw.text.isNotEmpty && _pw.text.length < kMinActivationPasswordLength;
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _pw.text;
    final ready =
        !_loading &&
        _valid &&
        !_done &&
        _pw.text.length >= kMinActivationPasswordLength &&
        passwordsMatch(_pw.text, _confirm.text);

    return AuthScaffold(
      semanticId: 'activation-screen',
      title: 'Activate your account',
      subtitle:
          'Your password must be at least $kMinActivationPasswordLength '
          'characters long',
      banner: _error != null
          ? AppBanner(
              severity: AppBannerSeverity.error,
              message: _error!,
              semanticId: 'activation-error',
            )
          : (_done
                ? const AppBanner(
                    severity: AppBannerSeverity.success,
                    message: 'Account activated — you can now sign in.',
                    semanticId: 'activation-done',
                  )
                : null),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_valid && !_done) ...[
                  AppTextField(
                    controller: _pw,
                    label: 'New Password',
                    hintText: 'Enter your password',
                    obscureText: !_showPw,
                    textInputAction: TextInputAction.next,
                    errorText: pwTooShort
                        ? 'At least $kMinActivationPasswordLength characters.'
                        : null,
                    suffixIcon: _showPw
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () => setState(() => _showPw = !_showPw),
                    onChanged: (_) => setState(() {}),
                    semanticId: 'activation-password',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirm,
                    label: 'Confirm Your Password',
                    hintText: 'Enter your password',
                    obscureText: !_showConfirm,
                    textInputAction: TextInputAction.done,
                    errorText: mismatch ? 'Passwords do not match.' : null,
                    suffixIcon: _showConfirm
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) =>
                        (ready && !_submitting) ? _submit() : null,
                    semanticId: 'activation-confirm',
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Verify',
                    fullWidth: true,
                    loading: _submitting,
                    onPressed: ready ? _submit : null,
                    semanticId: 'activation-submit',
                  ),
                  const SizedBox(height: 8),
                ],
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
