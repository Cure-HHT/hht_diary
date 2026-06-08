import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A single tab in an [AppTableTabs] strip.
@immutable
class AppTableTab {
  /// Stable identifier — what the caller uses as [AppTableTabs.activeKey]
  /// and what gets emitted by [AppTableTabs.onTap]. Persistence-safe.
  final String key;

  /// Display label.
  final String label;

  /// Optional count badge (e.g. "Active (12)"). Null hides the badge.
  final int? count;

  const AppTableTab({required this.key, required this.label, this.count});
}

/// Table-scoped filter tabs (e.g. "All Users / Active / Pending" above a
/// User Management table).
///
/// **Controlled component, no internal state.** The caller passes [tabs],
/// the currently-active [activeKey], and reacts to [onTap]. Selecting a tab
/// is the app's responsibility (refetch rows, update filter, etc.).
// Implements: DIARY-DEV-test-instrumentation/A
class AppTableTabs extends StatelessWidget {
  final List<AppTableTab> tabs;
  final String activeKey;
  final ValueChanged<String> onTap;

  /// Leading horizontal padding before the first tab. Used inside
  /// [AppDataTable] to align the first tab label with the table's other
  /// content (search field, column headers, row cells). The underline still
  /// extends edge-to-edge regardless of this offset.
  final double leadingPadding;

  /// Test-harness locator. When set, wraps the tab strip in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node.
  final String? semanticId;

  const AppTableTabs({
    super.key,
    required this.tabs,
    required this.activeKey,
    required this.onTap,
    this.leadingPadding = 0,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strip = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: leadingPadding),
          child: Row(
            children: [
              for (final tab in tabs)
                _TabPill(
                  tab: tab,
                  isActive: tab.key == activeKey,
                  onTap: () => onTap(tab.key),
                ),
            ],
          ),
        ),
        // Bottom divider, inset by leadingPadding on each side so it matches
        // the table's content indent in AppDataTable, while staying
        // edge-to-edge when AppTableTabs is used standalone (padding == 0).
        Padding(
          padding: EdgeInsets.symmetric(horizontal: leadingPadding),
          child: ColoredBox(
            color: theme.colorScheme.outlineVariant,
            child: const SizedBox(height: 1, width: double.infinity),
          ),
        ),
      ],
    );

    if (semanticId == null) return strip;

    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: strip,
    );
  }
}

// Inter Medium 14 / line-height 20 / letter-spacing -0.15.
const _tabLabelStyle = TextStyle(
  fontWeight: FontWeight.w500,
  fontSize: 14,
  height: 20 / 14,
  letterSpacing: -0.15,
);

class _TabPill extends StatelessWidget {
  final AppTableTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _TabPill({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected: primary. Unselected: Grey (#A4B9C2 — outline slot).
    final labelColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg,
          vertical: SpacingTokens.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tab.label, style: _tabLabelStyle.copyWith(color: labelColor)),
            if (tab.count != null) ...[
              SizedBox(width: SpacingTokens.sm),
              _CountBadge(count: tab.count!, isActive: isActive),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool isActive;
  const _CountBadge({required this.count, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selected: primary tint background + primary text.
    // Unselected: Light Gray background + Grey text.
    final bg = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.outlineVariant;
    final fg = isActive ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RadiusTokens.full),
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
