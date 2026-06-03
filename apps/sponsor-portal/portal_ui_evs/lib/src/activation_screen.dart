import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'activation_link.dart';

/// Public activation page reached via the emailed magic link (?code=...).
/// Not part of the reactive authed shell.
// Implements: DIARY-PRD-user-account-activation-workflow/H
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    required this.serverUrl,
    required this.code,
  });
  final String serverUrl;
  final String code;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _loading = true;
  String? _maskedEmail;
  String? _error;
  String? _done;
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;

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
      final r = await http.get(
        Uri.parse('${widget.serverUrl}/activate/${widget.code}'),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      setState(() {
        _loading = false;
        if (body['valid'] == true) {
          _maskedEmail = body['maskedEmail'] as String?;
        } else {
          _error = body['message'] as String?;
        }
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Please try again.';
      });
    }
  }

  Future<void> _submit() async {
    if (!passwordsMatch(_pw.text, _confirm.text)) {
      setState(() => _error = 'Passwords must match and be non-empty.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await http.post(
        Uri.parse('${widget.serverUrl}/activate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'code': widget.code, 'password': _pw.text}),
      );
      final body = jsonDecode(r.body) as Map<String, Object?>;
      setState(() {
        _submitting = false;
        if (r.statusCode == 200 && body['ok'] == true) {
          _done = 'Account activated — you can now sign in.';
        } else {
          _error = body['message'] as String? ?? 'Activation failed.';
        }
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _error = 'Activation failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate your account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const CircularProgressIndicator()
                : _done != null
                ? Text(_done!, style: Theme.of(context).textTheme.titleMedium)
                : _maskedEmail == null
                ? Text(_error ?? 'Invalid link.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Activating $_maskedEmail'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pw,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      TextField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? 'Activating…' : 'Activate'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
