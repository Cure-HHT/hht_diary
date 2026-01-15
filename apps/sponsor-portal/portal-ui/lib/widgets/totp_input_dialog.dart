// IMPLEMENTS REQUIREMENTS:
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Dialog for entering TOTP verification code during MFA sign-in

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog for entering a 6-digit TOTP verification code
///
/// Used during login when MFA is required. The user enters the code
/// from their authenticator app to complete sign-in.
class TotpInputDialog extends StatefulWidget {
  /// Optional callback when user wants to cancel
  final VoidCallback? onCancel;

  const TotpInputDialog({super.key, this.onCancel});

  /// Show the TOTP input dialog and return the entered code
  ///
  /// Returns null if the user cancels.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TotpInputDialog(),
    );
  }

  @override
  State<TotpInputDialog> createState() => _TotpInputDialogState();
}

class _TotpInputDialogState extends State<TotpInputDialog> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.security, size: 48, color: theme.colorScheme.primary),
      title: const Text('Two-Factor Authentication'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the 6-digit code from your authenticator app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Code input
          TextField(
            controller: _codeController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: 'Verification Code',
              hintText: '000000',
              prefixIcon: const Icon(Icons.pin),
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              // Clear error on change
              if (_error != null) {
                setState(() => _error = null);
              }
              // Auto-submit when 6 digits entered
              if (value.length == 6) {
                _submit();
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Verify')),
      ],
    );
  }
}
