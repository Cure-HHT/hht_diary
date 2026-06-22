import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'auth_scaffold.dart';
import 'login_logic.dart';

// Implements: DIARY-PRD-two-factor-authentication/B+F (client OTP entry)
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.serverUrl,
    required this.idToken,
    required this.maskedEmail,
    required this.onSession,
    this.httpClient,
  });
  final String serverUrl;
  final String idToken;
  final String maskedEmail;

  /// Called when OTP verification establishes a session. [displayName] is the
  /// user's human name when the server supplied one (greets them by name on
  /// the role-selection screen); null falls back to the email.
  // Implements: DIARY-GUI-role-switching/H
  final void Function(String sessionToken, {String? displayName}) onSession;
  final http.Client? httpClient;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _resending = false;

  /// Lazily-created client owned by this state when none is injected —
  /// one client for the screen's lifetime, closed in [dispose]. An
  /// injected client is the owner's to close.
  http.Client? _ownedClient;

  http.Client get _http =>
      widget.httpClient ?? (_ownedClient ??= http.Client());

  @override
  void dispose() {
    _ownedClient?.close();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final r = await _http.post(
        Uri.parse('${widget.serverUrl}/login/verify-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': widget.idToken, 'code': _code.text}),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, Object?>;
        final token = body['sessionToken'] as String;
        widget.onSession(token, displayName: body['displayName'] as String?);
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Invalid or expired code. Please try again.';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Verification failed.';
      });
    }
  }

  /// Re-issue the OTP by replaying the original `/login` call with the stored
  /// idToken — the same request that triggered the first code. No new endpoint
  /// or API contract change.
  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      final r = await _http.post(
        Uri.parse('${widget.serverUrl}/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': widget.idToken}),
      );
      if (!mounted) return;
      // Claim success only on 200, matching the /login contract used
      // throughout this flow; a non-200 (e.g. expired idToken) means no new
      // code was issued, so surface an error instead of a misleading notice.
      setState(() {
        _resending = false;
        if (r.statusCode == 200) {
          _notice = 'A new code has been sent to your email.';
        } else {
          _error = "Couldn't resend the code. Please restart sign-in.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = "Couldn't resend the code. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = isValidOtp(_code.text);

    return AuthScaffold(
      semanticId: 'otp-screen',
      title: 'Enter verification code',
      // Figma copy is the generic phrase; the masked address still rides on
      // [OtpScreen.maskedEmail] for logs/tests but isn't displayed.
      subtitle: 'We sent a 6-digit code to your email.',
      banner: _error != null
          ? AppBanner(
              severity: AppBannerSeverity.error,
              message: _error!,
              semanticId: 'otp-error',
            )
          : (_notice != null
                ? AppBanner(
                    severity: AppBannerSeverity.info,
                    message: _notice!,
                    semanticId: 'otp-notice',
                  )
                : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _code,
            label: 'Verification Code',
            hintText: '******',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => (ready && !_busy) ? _submit() : null,
            semanticId: 'otp-code',
          ),
          const SizedBox(height: 8),
          // Figma: a left-aligned underlined text link directly under the
          // field, not a full-width button.
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              identifier: 'otp-resend',
              button: true,
              container: true,
              explicitChildNodes: true,
              child: InkWell(
                onTap: (_busy || _resending) ? null : _resend,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Text(
                    _resending ? 'Sending…' : 'Resend code',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.15,
                      decoration: TextDecoration.underline,
                      color: Theme.of(context).colorScheme.primary,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Verify',
            fullWidth: true,
            loading: _busy,
            onPressed: ready ? _submit : null,
            semanticId: 'otp-submit',
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
