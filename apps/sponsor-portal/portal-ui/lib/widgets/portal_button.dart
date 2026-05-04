// Reusable button component for the sponsor portal.
// Provides consistent styling with reduced border radius.

import 'package:flutter/material.dart';

/// A reusable button with portal-consistent styling.
///
/// Supports filled (default) and outlined variants.
///
/// ```dart
/// PortalButton(
///   onPressed: () => doSomething(),
///   label: 'Send Now',
///   icon: Icons.send,
/// )
///
/// PortalButton.outlined(
///   onPressed: () => cancel(),
///   label: 'Cancel',
/// )
/// ```
class PortalButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool _outlined;

  const PortalButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  }) : _outlined = false;

  const PortalButton.outlined({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.foregroundColor,
  }) : _outlined = true,
       backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    if (_outlined) return _buildOutlined(context);
    return _buildFilled(context);
  }

  Widget _buildFilled(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.onSurface;
    final fg = foregroundColor ?? theme.colorScheme.surface;
    final style = FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg.withValues(alpha: 0.4),
      disabledForegroundColor: fg.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: style,
      );
    }

    return FilledButton(onPressed: onPressed, style: style, child: Text(label));
  }

  Widget _buildOutlined(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ?? theme.colorScheme.onSurface;
    final style = OutlinedButton.styleFrom(
      foregroundColor: fg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: Colors.grey.shade300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: style,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
