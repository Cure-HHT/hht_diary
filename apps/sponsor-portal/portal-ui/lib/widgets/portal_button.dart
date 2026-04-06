// Reusable button component for the sponsor portal.
// Provides consistent styling with reduced border radius (12px).

import 'package:flutter/material.dart';

/// A reusable filled button with portal-consistent styling.
///
/// Uses a reduced border radius (12px) and supports an optional leading icon.
///
/// ```dart
/// PortalButton(
///   onPressed: () => doSomething(),
///   label: 'Send Now',
///   icon: Icons.send,
/// )
/// ```
class PortalButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PortalButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.onSurface;
    final fg = foregroundColor ?? theme.colorScheme.surface;
    final style = FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
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
}
