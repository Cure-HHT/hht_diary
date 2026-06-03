import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  bool _busy = false;

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
        _error = 'Invalid or expired code. Please restart sign-in.';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Verification failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = isValidOtp(_code.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Enter verification code')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('We sent a code to ${widget.maskedEmail}'),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: (!ready || _busy) ? null : _submit,
                child: Text(_busy ? 'Verifying…' : 'Verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
