// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00062: Support Contact Information
//   REQ-p00010: FDA 21 CFR Part 11 Compliance (audit support)
//
// Reusable error message component with copy and support features

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable error message component with:
/// - Selectable text
/// - Copy icon to copy the message
/// - Support icon that shows email on hover and opens mail client
///
/// Usage:
/// ```dart
/// ErrorMessage(
///   message: 'Invalid activation code',
///   supportEmail: 'support@example.com',
/// )
/// ```
class ErrorMessage extends StatelessWidget {
  final String message;
  final String? supportEmail;
  final VoidCallback? onDismiss;

  const ErrorMessage({
    super.key,
    required this.message,
    this.supportEmail,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMultiline = message.contains('\n') || message.length > 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isMultiline
          ? _buildMultilineLayout(context, colorScheme)
          : _buildSingleLineLayout(context, colorScheme),
    );
  }

  Widget _buildSingleLineLayout(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          color: colorScheme.onErrorContainer,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            message,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
        _buildCopyButton(context, colorScheme),
        _buildSupportButton(context, colorScheme),
        if (onDismiss != null) _buildDismissButton(context, colorScheme),
      ],
    );
  }

  Widget _buildMultilineLayout(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildCopyButton(context, colorScheme),
            _buildSupportButton(context, colorScheme),
            if (onDismiss != null) _buildDismissButton(context, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildCopyButton(BuildContext context, ColorScheme colorScheme) {
    return Tooltip(
      message: 'Copy error message',
      child: IconButton(
        icon: Icon(
          Icons.copy_outlined,
          size: 18,
          color: colorScheme.onErrorContainer,
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: message));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error message copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSupportButton(BuildContext context, ColorScheme colorScheme) {
    if (supportEmail == null || supportEmail!.isEmpty) {
      return Tooltip(
        message: 'Ask system admin to configure support email',
        child: IconButton(
          icon: Icon(
            Icons.support_agent_outlined,
            size: 18,
            color: colorScheme.onErrorContainer.withValues(alpha: 0.5),
          ),
          onPressed: null,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      );
    }

    return Tooltip(
      message: 'Contact support: $supportEmail',
      child: IconButton(
        icon: Icon(
          Icons.support_agent_outlined,
          size: 18,
          color: colorScheme.onErrorContainer,
        ),
        onPressed: () => _launchSupportEmail(context),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDismissButton(BuildContext context, ColorScheme colorScheme) {
    return IconButton(
      icon: Icon(Icons.close, size: 18, color: colorScheme.onErrorContainer),
      onPressed: onDismiss,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _launchSupportEmail(BuildContext context) async {
    final subject = Uri.encodeComponent('Portal Error Report');
    final body = Uri.encodeComponent(
      'Error Message:\n$message\n\n'
      'Please describe what you were doing when this error occurred:\n\n',
    );
    final uri = Uri.parse('mailto:$supportEmail?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open email client. Support: $supportEmail',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email: $supportEmail'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
