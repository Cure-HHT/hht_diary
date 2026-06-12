import 'package:flutter/material.dart';

/// One pill in a [DashboardTabs] strip.
@immutable
class DashboardTabItem {
  /// Stable identifier used by [DashboardTabs.activeKey] and the
  /// [DashboardTabs.onTap] callback. Persistence-safe — keep it short
  /// and machine-readable.
  final String key;

  /// Display label.
  final String label;

  const DashboardTabItem({required this.key, required this.label});
}

/// Pill-style segmented tab strip for top-level dashboard navigation.
///
/// Distinct from [AppTableTabs] in the design system, which is the
/// underline-style filter strip sized for in-table use. This widget is
/// for the page-level tab bar shown beneath [PortalAppBar] in the
/// admin dashboard — chunkier pills with a tinted "active" fill.
///
/// **Controlled component, no internal state.** The owning widget
/// (typically [PortalDashboard]) holds the selected key and passes it
/// in via [activeKey]; tapping a tab fires [onTap] with that tab's
/// key. The strip never decides which tab is selected.
class DashboardTabs extends StatelessWidget {
  const DashboardTabs({
    super.key,
    required this.tabs,
    required this.activeKey,
    required this.onTap,
  }) : assert(tabs.length > 0, 'DashboardTabs needs at least one tab');

  final List<DashboardTabItem> tabs;

  /// Currently-selected tab's key. Must match one of [tabs]; otherwise
  /// every tab renders as inactive (which is harmless but probably a
  /// bug at the call site).
  final String activeKey;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Outer capsule paints the Primary Light Soft background; the inner
    // padding produces the "minor space" inset between the capsule's
    // border and the active white pill.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs)
            _Pill(
              tab: tab,
              isActive: tab.key == activeKey,
              onTap: () => onTap(tab.key),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.tab, required this.isActive, required this.onTap});

  final DashboardTabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Both states use the primary tone for the label; the active state
    // swaps the pill's background from "transparent (lets the outer
    // primaryContainer strip show through)" to "surface (the inset
    // white chip)".
    final bg = isActive ? theme.colorScheme.surface : Colors.transparent;

    return Semantics(
      // Stable Playwright handle derived from the tab's machine key
      // (`tab-users`, `tab-audit`, ...). container + explicitChildNodes
      // keep the identifier on its own node — without them the web
      // flt-semantics flattener merges it into the button node and the
      // selector disappears (see event_sourcing prd-reaction §automation).
      identifier: 'tab-${tab.key}',
      container: true,
      explicitChildNodes: true,
      button: true,
      selected: isActive,
      label: tab.label,
      child: Material(
        color: bg,
        // Inner radius is slightly smaller than the outer capsule so the
        // white chip sits cleanly inside the 4px inset without colliding
        // with the rounded corners.
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: Text(
              tab.label,
              // Inter Medium 15 / line-height 20.
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 20 / 15,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
