import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Picks one of three widget builders based on the current viewport tier.
///
/// Use when the **layout itself** differs across tiers — e.g., a dashboard
/// with a persistent sidebar on desktop and a drawer on mobile, or a table
/// that becomes a card list on phones. For simple value changes (paddings,
/// font sizes) prefer `context.responsive(mobile: ..., desktop: ...)`.
///
/// ```dart
/// ResponsiveBuilder(
///   mobile: (ctx) => MobileDashboard(),
///   desktop: (ctx) => DesktopDashboardWithSidebar(),
/// )
/// ```
///
/// [mobile] is required; [tablet] and [desktop] fall back upward when
/// omitted (desktop → tablet → mobile).
class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    switch (context.breakpoint) {
      case AppBreakpoint.desktop:
        return (desktop ?? tablet ?? mobile)(context);
      case AppBreakpoint.tablet:
        return (tablet ?? mobile)(context);
      case AppBreakpoint.mobile:
        return mobile(context);
    }
  }
}
