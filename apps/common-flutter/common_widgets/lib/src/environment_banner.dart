// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:flutter/material.dart';

/// A corner-ribbon overlay that displays the current environment
/// (e.g. DEV / QA / UAT) in a colored triangle in the top-left.
///
/// Unlike Flutter's built-in `debugShowCheckedModeBanner`, this widget is a
/// plain `CustomPaint` and renders in release builds, so it can be used to
/// visually distinguish non-production deployments.
///
/// Apps own the "should this show?" decision via [show] (typically wired to
/// their own flavor config), and the widget maps the [flavorName] string to
/// a standard color and label. Unknown / production flavors render nothing.
///
/// Usage:
/// ```dart
/// EnvironmentBanner(
///   show: F.showBanner,
///   flavorName: F.name,
///   child: MaterialApp(...),
/// )
/// ```
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    required this.child,
    required this.flavorName,
    this.show = true,
    super.key,
  });

  /// The app content to wrap with the banner.
  final Widget child;

  /// Flavor identifier — one of `local`, `dev`, `qa`, `uat`, `prod`
  /// (case-insensitive). Unknown values render the child without a ribbon.
  final String flavorName;

  /// Whether the ribbon should be drawn. Apps typically wire this to their
  /// flavor config (e.g. hide in UAT/prod).
  final bool show;

  @override
  Widget build(BuildContext context) {
    final data = _EnvironmentRibbonData.forFlavor(flavorName);
    if (!show || data == null) {
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
            child: _EnvironmentRibbon(data: data),
          ),
        ],
      ),
    );
  }
}

/// Label + color for a given flavor. Null means "no ribbon" (prod/unknown).
class _EnvironmentRibbonData {
  const _EnvironmentRibbonData({required this.label, required this.color});

  final String label;
  final Color color;

  static _EnvironmentRibbonData? forFlavor(String flavorName) {
    switch (flavorName.toLowerCase()) {
      case 'local':
        return const _EnvironmentRibbonData(
          label: 'LOCAL',
          color: Colors.green,
        );
      case 'dev':
        return const _EnvironmentRibbonData(
          label: 'DEV',
          color: Colors.orange,
        );
      case 'qa':
        return const _EnvironmentRibbonData(
          label: 'QA',
          color: Colors.purple,
        );
      case 'uat':
        return const _EnvironmentRibbonData(
          label: 'UAT',
          color: Colors.blue,
        );
      case 'prod':
      default:
        return null;
    }
  }
}

/// The ribbon widget displayed in the corner.
class _EnvironmentRibbon extends StatelessWidget {
  const _EnvironmentRibbon({required this.data});

  final _EnvironmentRibbonData data;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RibbonPainter(color: data.color),
        child: SizedBox(
          width: 100,
          height: 100,
          child: Align(
            alignment: const Alignment(-0.5, -0.5),
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees
              child: Text(
                data.label,
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
}

/// Custom painter that draws a filled triangle in the top-left corner.
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

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
