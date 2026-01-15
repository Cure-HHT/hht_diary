// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Two-factor authentication setup page for new user activation
// Uses TOTP (Time-based One-Time Password) with authenticator apps

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

/// Page for setting up two-factor authentication during account activation
///
/// This page is shown after the user creates their password and before
/// their account activation is finalized. MFA enrollment is required
/// for FDA 21 CFR Part 11 compliance.
class TwoFactorSetupPage extends StatefulWidget {
  /// The activation code from the activation flow
  final String activationCode;

  const TwoFactorSetupPage({super.key, required this.activationCode});

  @override
  State<TwoFactorSetupPage> createState() => _TwoFactorSetupPageState();
}

class _TwoFactorSetupPageState extends State<TwoFactorSetupPage> {
  // MFA enrollment state
  TotpSecret? _totpSecret;
  String? _qrCodeUrl;
  String? _secretKey;
  bool _isGeneratingSecret = true;
  bool _isVerifying = false;
  bool _isActivating = false;
  String? _error;

  // Verification code input
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  String get _apiBaseUrl {
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kDebugMode) return 'http://localhost:8080';
    return Uri.base.origin;
  }

  @override
  void initState() {
    super.initState();
    _generateTotpSecret();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  /// Generate TOTP secret for MFA enrollment
  Future<void> _generateTotpSecret() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in. Please restart the activation process.';
        _isGeneratingSecret = false;
      });
      return;
    }

    try {
      // Get MFA session from current user
      final session = await user.multiFactor.getSession();

      // Generate TOTP secret
      final totpSecret = await TotpMultiFactorGenerator.generateSecret(session);

      // Generate QR code URL for authenticator apps
      final qrCodeUrl = await totpSecret.generateQrCodeUrl(
        accountName: user.email ?? 'user',
        issuer: 'Clinical Trial Portal',
      );

      if (mounted) {
        setState(() {
          _totpSecret = totpSecret;
          _qrCodeUrl = qrCodeUrl;
          _secretKey = totpSecret.secretKey;
          _isGeneratingSecret = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('MFA secret generation error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _error = _mapFirebaseError(e.code);
          _isGeneratingSecret = false;
        });
      }
    } catch (e) {
      debugPrint('MFA secret generation error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to generate 2FA secret. Please try again.';
          _isGeneratingSecret = false;
        });
      }
    }
  }

  /// Verify the TOTP code and enroll MFA
  Future<void> _verifyAndEnroll() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    if (_totpSecret == null) {
      setState(() => _error = 'No secret available. Please refresh the page.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Session expired. Please restart activation.';
          _isVerifying = false;
        });
        return;
      }

      // Create assertion for enrollment
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
            _totpSecret!,
            code,
          );

      // Enroll the second factor
      await user.multiFactor.enroll(
        assertion,
        displayName: 'Authenticator App',
      );

      if (mounted) {
        // MFA enrolled successfully - now complete activation
        await _completeActivation();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('MFA enrollment error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _error = _mapFirebaseError(e.code);
          _isVerifying = false;
        });
      }
    } catch (e) {
      debugPrint('MFA enrollment error: $e');
      if (mounted) {
        setState(() {
          _error = 'Verification failed. Please check your code and try again.';
          _isVerifying = false;
        });
      }
    }
  }

  /// Complete the account activation after MFA enrollment
  Future<void> _completeActivation() async {
    setState(() {
      _isVerifying = false;
      _isActivating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Session expired. Please restart activation.';
          _isActivating = false;
        });
        return;
      }

      // Get fresh ID token (will now include MFA claims)
      final idToken = await user.getIdToken(true);

      // Call activation endpoint
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/activate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'code': widget.activationCode}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Success - show message and redirect to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account activated with 2FA! Please sign in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Sign out and redirect to login
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.go('/login');
        }
      } else {
        // Check if it's still an MFA required error (shouldn't happen)
        if (data['mfa_required'] == true) {
          setState(() {
            _error = 'MFA verification failed. Please try again.';
            _isActivating = false;
          });
        } else {
          setState(() {
            _error = data['error'] as String? ?? 'Activation failed';
            _isActivating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Activation error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to complete activation. Please try again.';
          _isActivating = false;
        });
      }
    }
  }

  /// Copy secret key to clipboard
  Future<void> _copySecretKey() async {
    if (_secretKey != null) {
      await Clipboard.setData(ClipboardData(text: _secretKey!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret key copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Session expired. Please restart the activation process.';
      case 'requires-recent-login':
        return 'Please sign in again to complete 2FA setup.';
      case 'second-factor-already-in-use':
        return 'This authenticator is already registered.';
      case 'maximum-second-factor-count-exceeded':
        return 'Maximum number of authenticators reached.';
      default:
        return 'An error occurred: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Icon(
                      Icons.security,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Up Two-Factor Authentication',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan the QR code with your authenticator app '
                      '(Google Authenticator, Authy, etc.)',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Loading state
                    if (_isGeneratingSecret) ...[
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Generating secure key...'),
                          ],
                        ),
                      ),
                    ] else if (_qrCodeUrl != null) ...[
                      // QR Code
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: QrImageView(
                            data: _qrCodeUrl!,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Manual entry option
                      ExpansionTile(
                        title: Text(
                          "Can't scan? Enter manually",
                          style: theme.textTheme.bodyMedium,
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _secretKey ?? '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: _copySecretKey,
                                  tooltip: 'Copy to clipboard',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Verification code input
                      Text(
                        'Enter the 6-digit code from your authenticator app:',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        focusNode: _codeFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Verification Code',
                          hintText: '000000',
                          prefixIcon: const Icon(Icons.pin),
                          border: const OutlineInputBorder(),
                          counterText: '',
                          errorText: null,
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          // Auto-submit when 6 digits entered
                          if (value.length == 6 && !_isVerifying) {
                            _verifyAndEnroll();
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Verify button
                      FilledButton.icon(
                        onPressed: (_isVerifying || _isActivating)
                            ? null
                            : _verifyAndEnroll,
                        icon: _isVerifying || _isActivating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user),
                        label: Text(
                          _isActivating
                              ? 'Activating Account...'
                              : _isVerifying
                              ? 'Verifying...'
                              : 'Verify & Activate',
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Help text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Two-factor authentication is required for '
                              'regulatory compliance (FDA 21 CFR Part 11).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cancel link
                    TextButton(
                      onPressed: () async {
                        // Sign out and go back to activation
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          context.go('/activate');
                        }
                      },
                      child: const Text('Cancel and Start Over'),
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
