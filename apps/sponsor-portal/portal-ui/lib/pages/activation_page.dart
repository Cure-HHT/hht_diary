// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Activation page - new users activate their accounts with activation codes
// After password creation:
// - Developer Admins: redirects to 2FA (TOTP) setup
// - All other users: account activates directly (will use email OTP on login)

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../widgets/error_message.dart';

/// Page for users to activate their accounts using an activation code
class ActivationPage extends StatefulWidget {
  final String? code;

  const ActivationPage({super.key, this.code});

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

  String get _apiBaseUrl {
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kDebugMode) return 'http://localhost:8080';
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
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate/$code'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['valid'] == true) {
        setState(() {
          _codeValidated = true;
          _maskedEmail = data['email'] as String?;
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

  Future<void> _activateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isActivating = true;
      _error = null;
    });

    try {
      // Get the actual email from code validation
      // For Firebase, we need the real email, not masked
      // We'll use a workaround - the user enters their email
      final code = _codeController.text.trim();

      // First, sign in with Firebase Auth (create account)
      // Since activation codes are tied to emails, user needs to know their email
      final email = await _getEmailFromCode(code);
      if (email == null) {
        setState(() {
          _error = 'Failed to retrieve email. Please contact support.';
          _isActivating = false;
        });
        return;
      }

      // Create Firebase account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          );

      if (credential.user == null) {
        setState(() {
          _error = 'Failed to create account. Please try again.';
          _isActivating = false;
        });
        return;
      }

      // Try to activate the account directly
      // Backend will check if TOTP is required based on user role
      final activationResult = await _tryActivation(code);

      if (!mounted) return;

      if (activationResult['success'] == true) {
        // Account activated successfully - redirect directly to dashboard
        // The user is already authenticated via Firebase from account creation
        // Per REQ-CAL-p00029: "redirected to admin dashboard"
        context.go('/admin');
        return;
      }

      // Check if TOTP MFA is required (Developer Admin)
      if (activationResult['mfa_required'] == true &&
          activationResult['mfa_type'] == 'totp') {
        // Redirect to 2FA setup page for Developer Admins
        context.go('/activate/2fa', extra: {'code': code});
        return;
      }

      // Some other error occurred
      setState(() {
        _error =
            activationResult['error'] as String? ??
            'Activation failed. Please try again.';
        _isActivating = false;
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _mapFirebaseError(e.code);
          _isActivating = false;
        });
      }
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

  /// Try to activate the account by calling the backend API
  /// Returns a map with 'success', 'mfa_required', 'mfa_type', and 'error' keys
  Future<Map<String, dynamic>> _tryActivation(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'Not authenticated'};
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, ...data};
      } else if (response.statusCode == 403) {
        // Could be MFA required or other authorization error
        return {
          'success': false,
          'mfa_required': data['mfa_required'] ?? false,
          'mfa_type': data['mfa_type'],
          'error': data['error'],
        };
      } else {
        return {'error': data['error'] ?? 'Activation failed'};
      }
    } catch (e) {
      debugPrint('Activation API error: $e');
      return {'error': 'Failed to connect to server'};
    }
  }

  Future<String?> _getEmailFromCode(String code) async {
    try {
      // Call validation endpoint to get the email for this activation code
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate/$code'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns the full email (not masked) since activation code provides security
        return data['email'] as String?;
      }
    } catch (e) {
      debugPrint('Get email error: $e');
    }
    return null;
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Account creation is not enabled. Contact support.';
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
      case 'api-key-not-valid':
        return 'Firebase configuration error. Please ensure the Firebase Auth '
            'emulator is running (port 9099) for local development.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
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
                                    color: theme.colorScheme.onPrimaryContainer,
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
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
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
    );
  }
}
