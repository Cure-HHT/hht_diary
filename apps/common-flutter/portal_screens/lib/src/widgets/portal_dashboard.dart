import 'package:flutter/material.dart';

import 'dashboard_tabs.dart';

/// One destination in a [PortalDashboard].
///
/// The dashboard renders [body] when the tab keyed by [key] is active.
/// Bodies are built lazily — the builder runs only when the tab is
/// selected — so destinations that subscribe to projections or fetch
/// data don't do that work until the user navigates to them.
@immutable
class DashboardDestination {
  /// Stable identifier emitted by [DashboardTabs.onTap] and held as
  /// the dashboard's selected key.
  final String key;

  /// Display label for the tab pill.
  final String label;

  /// Builder for the destination's body widget. Re-runs each time the
  /// tab gets selected; cache state externally if a build is
  /// expensive.
  final WidgetBuilder body;

  const DashboardDestination({
    required this.key,
    required this.label,
    required this.body,
  });

  DashboardTabItem get _asTab => DashboardTabItem(key: key, label: label);
}

/// Top-level portal page shell — a fixed [appBar], a row of pill tabs
/// underneath, and the selected destination's [DashboardDestination.body]
/// filling the rest of the page.
///
/// Stateful — the dashboard owns the selected key internally so callers
/// don't have to manage it for the common case. Pass [initialKey] to
/// pre-select a tab on first build; pass [onDestinationChanged] to
/// observe selection changes (e.g. to drive URL routing in
/// `portal_ui_evs`).
///
/// The dashboard owns no data — every destination renders its own
/// content and is the right surface to subscribe to reactive views,
/// run permission gates, etc. This widget is purely chrome.
class PortalDashboard extends StatefulWidget {
  const PortalDashboard({
    super.key,
    required this.appBar,
    required this.destinations,
    this.initialKey,
    this.onDestinationChanged,
  }) : assert(
         destinations.length > 0,
         'PortalDashboard needs at least one destination',
       );

  /// Top header — typically a [PortalAppBar].
  final PreferredSizeWidget appBar;

  /// Tab destinations, rendered in order. The first entry is selected
  /// on first build unless [initialKey] points at a different one.
  final List<DashboardDestination> destinations;

  /// Key of the destination to show on first build. When null or no
  /// destination has this key, the first destination is selected.
  final String? initialKey;

  /// Fired after the selected destination changes. The value passed is
  /// the new selected key (matches [DashboardDestination.key]).
  final ValueChanged<String>? onDestinationChanged;

  @override
  State<PortalDashboard> createState() => _PortalDashboardState();
}

class _PortalDashboardState extends State<PortalDashboard> {
  late String _activeKey;

  @override
  void initState() {
    super.initState();
    _activeKey = _resolveInitialKey();
  }

  @override
  void didUpdateWidget(covariant PortalDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the destinations list shrank or got renamed such that the
    // active key no longer exists, gracefully fall back to the first
    // entry rather than blanking the body.
    final hasActive = widget.destinations.any((d) => d.key == _activeKey);
    if (!hasActive) {
      _activeKey = widget.destinations.first.key;
    }
  }

  String _resolveInitialKey() {
    final requested = widget.initialKey;
    if (requested != null) {
      for (final d in widget.destinations) {
        if (d.key == requested) return requested;
      }
    }
    return widget.destinations.first.key;
  }

  void _select(String key) {
    if (key == _activeKey) return;
    setState(() => _activeKey = key);
    widget.onDestinationChanged?.call(key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.destinations.firstWhere(
      (d) => d.key == _activeKey,
      // didUpdateWidget keeps _activeKey valid; this orElse is defence-in-
      // depth in case a destination list mutates mid-frame.
      orElse: () => widget.destinations.first,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: widget.appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DashboardTabs(
                tabs: [for (final d in widget.destinations) d._asTab],
                activeKey: _activeKey,
                onTap: _select,
              ),
            ),
          ),
          Expanded(child: active.body(context)),
        ],
      ),
    );
  }
}
