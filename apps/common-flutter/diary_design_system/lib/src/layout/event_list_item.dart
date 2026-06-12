import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Visual tone for [EventListItem]. Drives the row background, optional
/// border, and the secondary-text colour so all three cues stay in
/// agreement.
///
/// Maps to the three Figma variants on the notifications screen:
///   - [neutral] — node `452:9305` (and the default daily-entry row).
///   - [critical] — node `452:9323` — secondary text + border are
///     tinted critical (e.g. an over-budget duration).
///   - [warning] — node `452:9329` — warm "pending" bg used for
///     ongoing / incomplete events.
enum EventListItemTone { neutral, critical, warning }

/// A single timestamped row in an event list — the pattern that appears
/// under the "Needs your attention" tile and in standalone event feeds.
///
/// Anatomy (left to right):
///   - [leading] — typically a timestamp like "01:10 PM".
///   - [icon] (optional) — small decoration between the time and the
///     secondary text (e.g. the droplet glyph for an entry-type marker).
///   - [secondary] (optional) — descriptive text such as "6 min" or
///     "Ongoing". Coloured per [tone] (critical → `colorScheme.error`,
///     otherwise normal text).
///   - [trailing] (optional) — arbitrary widget at the end. For the
///     "Incomplete" pending pill from Figma, pass a small Row of icon +
///     text styled with `semantic.warning` (see the book gallery).
///
/// Use [EventListItem.empty] for the "No records" empty-state row.
class EventListItem extends StatelessWidget {
  final String leading;
  final IconData? icon;

  /// Bundled image asset path rendered in the icon slot. When non-null this
  /// takes precedence over [icon] — use it for richer per-row glyphs (e.g.
  /// the clinical diary's intensity PNGs) where an [IconData] isn't enough.
  /// Sized [iconImageSize] square; falls back to a small drop if missing.
  final String? iconAssetPath;

  /// Display size for [iconAssetPath]. Defaults to 20 — a touch larger than
  /// the 16-px Material glyph so coloured PNG artwork reads at the same
  /// optical weight.
  final double iconImageSize;

  final String? secondary;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EventListItemTone tone;

  /// Optional left-edge accent bar — a 4-px vertical stripe inside the row's
  /// rounded corner. Use for status cues (e.g. red bar on a finalised record,
  /// amber bar on an incomplete one) so the row reads at a glance.
  final Color? accentColor;

  /// When true, leading + secondary are rendered in
  /// `colorScheme.onSurfaceVariant` — the muted treatment used in the
  /// Figma's empty / "no activity yet" rows. Set automatically by
  /// [EventListItem.empty]; not part of the public ctor.
  final bool _muted;

  /// Test-harness locator. When set, wraps the row in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node.
  final String? semanticId;

  const EventListItem({
    super.key,
    required this.leading,
    this.icon,
    this.iconAssetPath,
    this.iconImageSize = 20,
    this.secondary,
    this.trailing,
    this.onTap,
    this.tone = EventListItemTone.neutral,
    this.accentColor,
    this.semanticId,
  }) : _muted = false;

  /// Empty-state row — a single muted line of explanatory text in place
  /// of the timestamp/duration layout. Always renders in the neutral
  /// tone (subtle surface bg, no border).
  const EventListItem.empty(String message, {super.key, this.semanticId})
    : leading = message,
      icon = null,
      iconAssetPath = null,
      iconImageSize = 20,
      secondary = null,
      trailing = null,
      onTap = null,
      tone = EventListItemTone.neutral,
      accentColor = null,
      _muted = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (background, border, secondaryColor) = _toneSurface(theme);

    final primaryTextColor = _muted ? cs.onSurfaceVariant : cs.onSurface;
    final secondaryTextColor = _muted
        ? cs.onSurfaceVariant
        : (secondaryColor ?? cs.onSurface);
    final iconColor = _muted ? cs.onSurfaceVariant : cs.onSurface;

    final primaryStyle = theme.textTheme.bodyMedium?.copyWith(
      color: primaryTextColor,
    );
    final secondaryStyle = theme.textTheme.bodyMedium?.copyWith(
      color: secondaryTextColor,
    );

    final radius = BorderRadius.circular(RadiusTokens.md);
    // Leading + secondary are loose-Flexible so large text scales wrap
    // instead of right-overflowing — the row height is a MINIMUM that grows
    // to fit. Loose fit preserves intrinsic widths when space allows, so the
    // 1.0-scale layout is unchanged. The Expanded group keeps [trailing]
    // pinned to the right edge, and [trailing] is capped to a fraction of
    // the row so its own content can wrap under large scales too.
    final rowContent = LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: Text(leading, style: primaryStyle)),
                  // Image asset wins over the IconData when both are set —
                  // used by the clinical diary's nosebleed intensity glyphs.
                  if (iconAssetPath != null) ...[
                    SizedBox(width: SpacingTokens.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RadiusTokens.sm - 1),
                      child: Image.asset(
                        iconAssetPath!,
                        width: iconImageSize,
                        height: iconImageSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ] else if (icon != null) ...[
                    SizedBox(width: SpacingTokens.sm),
                    Icon(icon, size: 16, color: iconColor),
                  ],
                  if (secondary != null) ...[
                    SizedBox(width: SpacingTokens.sm),
                    Flexible(child: Text(secondary!, style: secondaryStyle)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: SpacingTokens.sm),
              // Bounded (instead of a plain Row slot's unbounded width) so
              // Flexible/Text descendants inside the trailing widget can
              // shrink and wrap rather than force a right overflow.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.6,
                ),
                child: trailing!,
              ),
            ],
          ],
        );
      },
    );

    // Outer rounded surface. When [accentColor] is set we lay a 4-px coloured
    // bar inside the left edge (Stack overlay so the row content keeps its
    // standard horizontal padding — the bar floats on top instead of pushing
    // content in).
    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      child: rowContent,
    );

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: border == null ? null : Border.all(color: border),
      ),
      child: accentColor == null
          ? inner
          : Stack(
              children: [
                inner,
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(RadiusTokens.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );

    final Widget row = onTap == null
        ? surface
        : Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, borderRadius: radius, child: surface),
          );

    if (semanticId == null) return row;

    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }

  (Color background, Color? border, Color? secondaryColor) _toneSurface(
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (tone) {
      EventListItemTone.neutral => (cs.surfaceContainerLow, null, null),
      EventListItemTone.critical => (
        cs.surfaceContainerLow,
        cs.errorContainer,
        cs.error,
      ),
      EventListItemTone.warning => (semantic.warningContainer, null, null),
    };
  }
}
