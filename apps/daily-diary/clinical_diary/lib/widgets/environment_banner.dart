// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/flavors.dart';
import 'package:flutter/material.dart';

/// A banner overlay that displays the current environment (DEV/QA).
///
/// This widget wraps the app content and displays a corner ribbon
/// indicating the environment. Only shown when [F.showBanner] is true
/// (configured via flavorizr for dev and qa environments).
///
/// Usage:
/// ```dart
/// EnvironmentBanner(
///   child: MaterialApp(...),
/// )
/// ```
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({required this.child, super.key});

  /// The app content to wrap with the banner
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Don't show banner if disabled in config
    if (!F.showBanner) {
      return child;
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            child: _EnvironmentRibbon(flavor: F.appFlavor),
          ),
        ],
      ),
    );
  }
}

/// The actual ribbon widget displayed in the corner.
class _EnvironmentRibbon extends StatelessWidget {
  const _EnvironmentRibbon({required this.flavor});

  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();

    return IgnorePointer(
      child: CustomPaint(
        painter: _RibbonPainter(color: color),
        child: SizedBox(
          width: 100,
          height: 100,
          child: Align(
            alignment: const Alignment(-0.5, -0.5),
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees in radians (for top-left)
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    return switch (flavor) {
      Flavor.local => Colors.green,
      Flavor.dev => Colors.orange,
      Flavor.qa => Colors.purple,
      Flavor.uat => Colors.blue,
      Flavor.prod => Colors.transparent,
    };
  }

  String _getLabel() {
    return switch (flavor) {
      Flavor.local => 'LOCAL',
      Flavor.dev => 'DEV',
      Flavor.qa => 'QA',
      Flavor.uat => 'UAT',
      Flavor.prod => '',
    };
  }
}

/// Custom painter to draw the corner ribbon.
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw triangle in top-left corner
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(0, size.height * 0.7)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
