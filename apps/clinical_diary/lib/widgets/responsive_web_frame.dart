// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Single App Architecture
//   REQ-d00006: Mobile App Build and Release Process

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that constrains the app width on web to simulate a
/// mobile phone viewport, preventing the UI from becoming too wide.
///
/// On mobile platforms (iOS, Android), this widget passes through
/// the child unchanged. On web, it centers the content and constrains
/// it to a maximum width resembling a large phone screen.
class ResponsiveWebFrame extends StatelessWidget {
  /// Creates a responsive web frame that constrains width on web.
  const ResponsiveWebFrame({
    required this.child,
    this.maxWidth = 430,
    this.backgroundColor,
    super.key,
  });

  /// The child widget to display (typically the app's main content).
  final Widget child;

  /// Maximum width for the content on web. Defaults to 430px which
  /// corresponds to a large phone like iPhone 14 Pro Max (430pt).
  final double maxWidth;

  /// Background color for the area outside the constrained content.
  /// Defaults to the scaffold background color from the theme.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // On mobile platforms, just return the child as-is
    if (!kIsWeb) {
      return child;
    }

    // On web, constrain the width and center the content
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.scaffoldBackgroundColor;

    return ColoredBox(
      color: bgColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
