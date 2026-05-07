// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-d00166: Server-owned portal activation
//
// Activation page - new users activate their accounts with activation codes.
// After password creation:
// - The server creates/updates the IdP user, sets emailVerified=true, and
//   stamps portal_users.firebase_uid. The client then signs in with the
//   chosen password and lands on /common-dashboard, which resolves the
//   role-specific dashboard from AuthService.currentUser.activeRole.
// - Developer Admin TOTP enrollment-at-activation is deferred
//   (REQ-d00166-B); tracker test in
//   integration_test/portal_activation_test.dart, TODO at
//   portal_activation.dart:202. When portal_users.totp_enrolled_at lands,
//   this page will redirect Dev Admins to /activate/2fa before signing in.
// - Non-Dev-Admin users go straight to sign-in; email OTP MFA fires there.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../services/firebase_emulator_helper.dart';
import '../widgets/error_message.dart';

/// Page for users to activate their accounts using an activation code
class ActivationPage extends StatefulWidget {
  final String? code;

  /// Optional HTTP client override — injected in tests; defaults to http.Client()
  final http.Client? httpClient;

  /// Optional FirebaseAuth override — injected in tests; defaults to FirebaseAuth.instance
  final FirebaseAuth? firebaseAuth;

  const ActivationPage({
    super.key,
    this.code,
    this.httpClient,
    this.firebaseAuth,
  });

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isValidating = false;
  bool _isActivating = false;
  bool _codeValidated = false;
  String? _maskedEmail;
  String? _error;
  bool _showPassword = false;

  // Resolved lazily so tests can inject alternatives without Platform dependency.
  late final http.Client _httpClient = widget.httpClient ?? http.Client();

  late final FirebaseAuth _auth = widget.firebaseAuth ?? FirebaseAuth.instance;

  String get _apiBaseUrl {
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kDebugMode) return 'http://localhost:8084';
    // Use the current host origin in production (same-origin API)
    return Uri.base.origin;
  }

  @override
  void initState() {
    super.initState();
    if (widget.code != null && widget.code!.isNotEmpty) {
      _codeController.text = widget.code!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateCode();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    // Close the internally-created http.Client to avoid socket leaks.
    // When widget.httpClient is provided (test injection), the test owns
    // the client's lifecycle.
    if (widget.httpClient == null) {
      _httpClient.close();
    }
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an activation code');
      return;
    }

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate/$code'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // CUR-1296: server returns {email: '...'} on a valid code.
        // Accept both the old {valid: true, maskedEmail: '...'} and the new
        // {email: '...'} shapes so the page works with Tasks 8/9 servers.
        final email = data['email'] as String?;
        final maskedEmail = data['maskedEmail'] as String? ?? email;
        setState(() {
          _codeValidated = true;
          _maskedEmail = maskedEmail;
          _isValidating = false;
        });
      } else {
        setState(() {
          _error = data['error'] as String? ?? 'Invalid activation code';
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to validate code. Please try again.';
          _isValidating = false;
        });
      }
    }
  }

  // Implements: REQ-d00166-A — POST {code, password} to server; server creates
  // the IdP user; client signs in with that password on 2xx.
  Future<void> _activateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isActivating = true;
      _error = null;
    });

    final code = _codeController.text.trim();
    final password = _passwordController.text;

    try {
      // Get the actual email from the code-validation endpoint so we can
      // sign in after the server-side activation succeeds.
      final email = await _getEmailFromCode(code);
      if (email == null) {
        setState(() {
          _error = 'Failed to retrieve email. Please contact support.';
          _isActivating = false;
        });
        return;
      }

      // CUR-1296: single server-side POST. Server creates/updates the IdP
      // user, sets emailVerified=true, and stamps portal_users.firebase_uid.
      //
      // Implements: REQ-d00166-A
      final activateRes = await _httpClient.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'password': password}),
      );

      if (!mounted) return;

      if (activateRes.statusCode != 200) {
        // Reverse proxies / gateways may return non-JSON error bodies (HTML
        // 502 pages, plain-text gateway errors). Guard the decode so a
        // malformed body lands on the generic message rather than throwing
        // into the catch-all below. Same pattern as AuthService's 401
        // branch.
        Map<String, dynamic>? errBody;
        try {
          final decoded = jsonDecode(activateRes.body);
          if (decoded is Map<String, dynamic>) errBody = decoded;
        } catch (_) {
          // Non-JSON body — fall through with errBody=null; the default
          // branch in _mapServerErrorCode renders a generic message.
        }
        final errCode = errBody?['code'] as String?;
        setState(() {
          _error = _mapServerErrorCode(errCode, errBody?['error'] as String?);
          _isActivating = false;
        });
        return;
      }

      // Sign in with the password the user just typed.
      // CUR-1280: ensure local-flavor builds route to the emulator.
      await ensureAuthEmulatorBound();
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!mounted) return;
      // No `extra` — CommonDashboard resolves the role from
      // AuthService.currentUser.activeRole. Activated users may be CRA,
      // Investigator, Study Coordinator, etc.; hard-coding administrator
      // here would route them to the wrong dashboard.
      context.go('/common-dashboard');
    } catch (e) {
      debugPrint('Activation error: $e');
      if (mounted) {
        setState(() {
          _error = 'An error occurred. Please try again.';
          _isActivating = false;
        });
      }
    }
  }

  Future<String?> _getEmailFromCode(String code) async {
    try {
      // Call validation endpoint to get the email for this activation code
      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate/$code'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns the full email (not masked) since activation code
        // provides security. Accept {email: '...'} (CUR-1296) and legacy shape.
        return data['email'] as String?;
      }
    } catch (e) {
      debugPrint('Get email error: $e');
    }
    return null;
  }

  /// CUR-1296: map server-side error codes to user-facing messages.
  /// Replaces the old _mapFirebaseError which handled client-side
  /// FirebaseAuthException codes from createUserWithEmailAndPassword.
  ///
  /// Implements: REQ-d00166-B
  String _mapServerErrorCode(String? code, String? humanError) {
    switch (code) {
      case 'code_invalid':
        return 'That activation link is invalid.';
      case 'code_expired':
        return 'That link has expired. Ask for a new one.';
      case 'password_too_weak':
        return humanError ?? 'Password is too weak. Try a stronger one.';
      case 'mfa_required':
        return 'MFA enrollment required. Please complete authenticator setup.';
      case 'idp_unavailable':
        return "Couldn't reach Identity Platform. Please retry in a moment.";
      default:
        return humanError ?? 'Activation failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Icon(
                        _codeValidated ? Icons.verified_user : Icons.vpn_key,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _codeValidated
                            ? 'Create Your Password'
                            : 'Activate Account',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _codeValidated
                            ? 'Set a password for your account'
                            : 'Enter your activation code to get started',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Error message
                      if (_error != null) ...[
                        ErrorMessage(
                          message: _error!,
                          supportEmail: const String.fromEnvironment(
                            'SUPPORT_EMAIL',
                          ),
                          onDismiss: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (!_codeValidated) ...[
                        // Activation code input
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Activation Code',
                            hintText: 'XXXXX-XXXXX',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Activation code is required';
                            }
                            if (!RegExp(
                              r'^[A-Z0-9]{5}-[A-Z0-9]{5}$',
                            ).hasMatch(v.trim().toUpperCase())) {
                              return 'Invalid format. Use XXXXX-XXXXX';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isValidating ? null : _validateCode,
                          child: _isValidating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Validate Code'),
                        ),
                      ] else ...[
                        // Email display
                        if (_maskedEmail != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Account: $_maskedEmail',
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Password fields
                        TextFormField(
                          key: const Key('passwordField'),
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('confirmPasswordField'),
                          controller: _confirmPasswordController,
                          obscureText: !_showPassword,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('activateButton'),
                          onPressed: _isActivating ? null : _activateAccount,
                          child: _isActivating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Activate Account'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _codeValidated = false;
                              _maskedEmail = null;
                              _error = null;
                            });
                          },
                          child: const Text('Use Different Code'),
                        ),
                      ],

                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
