// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00029: Create User Account
//   REQ-CAL-p00033: Resend Activation Email
//
// Reusable widget for displaying activation codes with copy functionality

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable widget to display activation/linking codes with copy functionality.
///
/// Features:
/// - Monospace font for code display
/// - Copy icon that copies code to clipboard
/// - Optional label
/// - Configurable styling
///
/// Usage:
/// ```dart
/// ActivationCodeDisplay(
///   code: 'ABCDE-12345',
///   label: 'Activation Code',
/// )
/// ```
class ActivationCodeDisplay extends StatelessWidget {
  final String code;
  final String? label;
  final bool showLabel;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const ActivationCodeDisplay({
    super.key,
    required this.code,
    this.label,
    this.showLabel = true,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fgColor = textColor ?? colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel && label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize ?? 16,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              _CopyButton(code: code, color: fgColor),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact version for use in tables or lists
class ActivationCodeChip extends StatelessWidget {
  final String code;

  const ActivationCodeChip({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          _CopyButton(code: code, color: colorScheme.onSurface, size: 14),
        ],
      ),
    );
  }
}

/// Copy button with tooltip and feedback
class _CopyButton extends StatelessWidget {
  final String code;
  final Color color;
  final double size;

  const _CopyButton({required this.code, required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy code',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code copied: $code'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.copy_outlined,
            size: size,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
