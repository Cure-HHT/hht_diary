import 'package:flutter/widgets.dart';

/// Standard viewport breakpoints used across the design system.
///
/// These are width thresholds, not tier sizes — a viewport "is mobile" when
/// `width < Breakpoints.mobile`. Aligned with common web conventions:
///
/// | Tier | Range | Typical devices |
/// | --- | --- | --- |
/// | `mobile` | `< 600` | Phones, narrow web views, side panels |
/// | `tablet` | `600 – 1023` | Tablets, small desktop windows, split views |
/// | `desktop` | `>= 1024` | Full desktop, large laptops |
class Breakpoints {
  Breakpoints._();

  /// Below this width the viewport is treated as mobile.
  static const double mobile = 600;

  /// Below this width the viewport is treated as tablet (and at or above
  /// [mobile] as not-mobile).
  static const double tablet = 1024;
}

/// The current viewport breakpoint tier.
enum AppBreakpoint { mobile, tablet, desktop }

extension AppBreakpointContext on BuildContext {
  /// Resolves the current viewport breakpoint from `MediaQuery`.
  AppBreakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.mobile) return AppBreakpoint.mobile;
    if (width < Breakpoints.tablet) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  bool get isMobile => breakpoint == AppBreakpoint.mobile;
  bool get isTablet => breakpoint == AppBreakpoint.tablet;
  bool get isDesktop => breakpoint == AppBreakpoint.desktop;

  /// True when the viewport is tablet OR desktop.
  bool get isAtLeastTablet => !isMobile;

  /// Pick a value based on the current breakpoint.
  ///
  /// Required [mobile] value acts as the universal fallback. Optional
  /// [tablet] and [desktop] override at their respective tiers; falling back
  /// upward when not provided — i.e., `desktop` defaults to `tablet`, which
  /// defaults to `mobile`.
  ///
  /// ```dart
  /// final padding = context.responsive(mobile: 16.0, desktop: 24.0);
  /// ```
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    switch (breakpoint) {
      case AppBreakpoint.desktop:
        return desktop ?? tablet ?? mobile;
      case AppBreakpoint.tablet:
        return tablet ?? mobile;
      case AppBreakpoint.mobile:
        return mobile;
    }
  }
}
