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
  final void Function(String sessionToken) onSession;
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

  http.Client get _http => widget.httpClient ?? http.Client();

  @override
  void dispose() {
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
        final token =
            (jsonDecode(r.body) as Map<String, Object?>)['sessionToken']
                as String;
        widget.onSession(token);
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
      subtitle: 'We sent a 6-digit code to ${widget.maskedEmail}',
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
            hintText: 'Enter 6-digit code',
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
          const SizedBox(height: 24),
          AppButton(
            label: 'Verify',
            fullWidth: true,
            loading: _busy,
            onPressed: ready ? _submit : null,
            semanticId: 'otp-submit',
          ),
          const SizedBox(height: 8),
          AuthLinkButton(
            label: 'Resend code',
            loading: _resending,
            onPressed: _busy ? null : _resend,
            semanticId: 'otp-resend',
          ),
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
