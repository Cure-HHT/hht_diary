import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A disclosure tile — the "Needs your attention" pattern from the
/// notifications / alerts screens.
///
/// The outer card is white. Border colour follows the [count] signal:
/// when there are items ([count] > 0) the border picks up the brand's
/// "Primary Light" accent (`AppSemanticColors.primaryLight`); otherwise
/// it falls back to `colorScheme.outline` so an empty tile reads as
/// inert. The chevron tracks the same accent.
///
/// The header carries [title] (Inter Medium 16 / `titleSmall`) and an
/// optional [count] pill (primary-light fill, primary-light-soft text —
/// Figma exact). Children render stacked with a consistent inter-row
/// gap — pair with `AppAlertRow.incompleteRecord(...)` and
/// `AppAlertRow.availableQuestionnaire(...)` for the two action-row
/// variants shown in the Figma, or `AppAlertRow(...)` for a custom tone.
class AppExpansionTile extends StatelessWidget {
  final String title;
  final int? count;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  /// Vertical gap inserted between consecutive [children]. Defaults to
  /// [SpacingTokens.md] (12) — the Figma rhythm between action rows.
  final double childGap;

  /// Test-harness locator. When set, wraps the tile in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node so Playwright can scope sub-tree queries inside the tile.
  final String? semanticId;

  const AppExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.count,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.childGap = SpacingTokens.md,
    this.semanticId,
  });

  bool get _hasData => (count ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final accent = _hasData ? semantic.primaryLight : cs.outline;

    final spacedChildren = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: childGap),
        children[i],
      ],
    ];

    final tile = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: accent),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Suppress ExpansionTile's hairline dividers so the tile reads
        // as one continuous surface; recolour the built-in chevron to
        // the resolved accent.
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: theme.expansionTileTheme.copyWith(
            iconColor: accent,
            collapsedIconColor: accent,
            shape: const Border(),
            collapsedShape: const Border(),
          ),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: SpacingTokens.xl,
            vertical: SpacingTokens.xs,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            SpacingTokens.md,
            0,
            SpacingTokens.md,
            SpacingTokens.lg,
          ),
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: SpacingTokens.sm),
                _HeaderCountBadge(
                  count: count!,
                  fill: semantic.primaryLight,
                  foreground: semantic.primaryLightSoft,
                ),
              ],
            ],
          ),
          children: spacedChildren,
        ),
      ),
    );

    if (semanticId == null) return tile;

    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: tile,
    );
  }
}

/// Pill counter shown beside the tile title — Figma "Primary Light" fill
/// with "Primary Light Soft" text. Kept private to the tile because the
/// visual recipe (filled accent + soft label inside a pill) is specific
/// to this header pattern; the broader `AppBadge` covers chips elsewhere.
class _HeaderCountBadge extends StatelessWidget {
  final int count;
  final Color fill;
  final Color foreground;

  const _HeaderCountBadge({
    required this.count,
    required this.fill,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(RadiusTokens.full),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w500,
          fontSize: 14,
          height: 19 / 14,
        ),
      ),
    );
  }
}
