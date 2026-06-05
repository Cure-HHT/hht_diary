import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Visual style for [AppBadge].
enum AppBadgeVariant {
  /// Transparent fill with a colored border + colored label.
  outlined,

  /// Colored fill with a contrasting (surface) label.
  filled,

  /// Soft-filled: low-saturation tinted background derived from the tone's
  /// M3 *Container* color, with the dark accent reused for the border and
  /// label. Used by the portal's role pill (e.g. light-pink "Admin" chip
  /// with dark-red border + label).
  tinted,
}

/// Semantic tone for [AppBadge].
///
/// Drives the border / fill / label colors:
/// - [neutral] → Grey (`outline` / `outlineVariant`)
/// - [primary] → Brand primary
/// - [danger] → Critical / red (`colorScheme.error`)
/// - [warning] → Pending / amber (via [AppSemanticColors])
/// - [success] → Approved / green (via [AppSemanticColors])
enum AppBadgeTone { neutral, primary, danger, warning, success }

/// A small chip used to surface roles, tags, or status-like categories that
/// aren't covered by [StatusBadge] (which has a dot + label fixed shape).
///
/// Common usage from the User Details dialog:
/// ```dart
/// AppBadge(label: 'Admin', tone: AppBadgeTone.danger)
/// AppBadge(label: 'Site Study Coordinator', tone: AppBadgeTone.primary)
/// AppBadge(label: 'CRA', tone: AppBadgeTone.neutral)
/// ```
///
/// Pass [trailing] to add a widget (typically a dropdown caret) inside
/// the pill on the right of the label. Pass [onTap] to make the whole
/// pill tappable — used by composed widgets like the portal's role
/// switcher where the chip itself triggers a menu.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final AppBadgeTone tone;

  /// Optional widget rendered inside the pill, to the right of the label.
  /// Auto-coloured to match the foreground tone via an enclosing
  /// `IconTheme`, so callers can pass `Icon(Icons.expand_more)` without
  /// pre-tinting it.
  final Widget? trailing;

  /// When non-null, the pill becomes tappable. Material ink/ripple is
  /// clipped to the rounded rect so it doesn't paint past the border.
  /// When null, the pill is a passive label (table cells, decorative
  /// chrome).
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.outlined,
    this.tone = AppBadgeTone.neutral,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    final accent = switch (tone) {
      AppBadgeTone.neutral => theme.colorScheme.outline,
      AppBadgeTone.primary => theme.colorScheme.primary,
      AppBadgeTone.danger => theme.colorScheme.error,
      AppBadgeTone.warning => semantic.warning,
      AppBadgeTone.success => semantic.success,
    };

    // Soft "container" tint per tone — only used by the [tinted] variant.
    // M3 supplies *Container slots for primary / error; semantic colors
    // carry their own *Container; neutral has no built-in tinted slot so
    // we fall back to the standard low-emphasis surface container.
    final tintedBg = switch (tone) {
      AppBadgeTone.neutral => theme.colorScheme.surfaceContainerHighest,
      AppBadgeTone.primary => theme.colorScheme.primaryContainer,
      AppBadgeTone.danger => theme.colorScheme.errorContainer,
      AppBadgeTone.warning => semantic.warningContainer,
      AppBadgeTone.success => semantic.successContainer,
    };

    // Neutral + tinted needs special handling: the `accent` for neutral is
    // [outline] (light grey), which is the same family as the tinted bg
    // [surfaceContainerHighest]. Reusing `accent` for fg + border there
    // produces a chip where text and border vanish into the fill (the
    // "just grey container" failure). For that one cell of the matrix we
    // darken the fg to [onSurfaceVariant] and soften the border to
    // [outlineVariant] so the chip reads as "light-grey filled / grey
    // border / dark-grey text" — matches the portal's CRA pill.
    final (fg, bg, borderColor) = switch (variant) {
      AppBadgeVariant.outlined => (accent, Colors.transparent, accent),
      AppBadgeVariant.filled => (theme.colorScheme.surface, accent, accent),
      AppBadgeVariant.tinted =>
        tone == AppBadgeTone.neutral
            ? (
                theme.colorScheme.onSurfaceVariant,
                tintedBg,
                theme.colorScheme.outlineVariant,
              )
            : (accent, tintedBg, accent),
    };

    final labelText = Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: -0.15,
        color: fg,
      ),
    );

    // Row only when trailing is present — keeps the passive single-line
    // case identical to the original render tree so existing widget
    // finders / golden tests don't shift.
    final Widget content = trailing == null
        ? labelText
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText,
              SizedBox(width: SpacingTokens.xs),
              IconTheme(
                data: IconThemeData(color: fg, size: 16),
                child: trailing!,
              ),
            ],
          );

    final borderRadius = BorderRadius.circular(RadiusTokens.sm);
    final chrome = Container(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: borderRadius,
      ),
      child: content,
    );

    // Passive case: MergeSemantics keeps the visual chrome (Container)
    // from fragmenting the announcement — screen readers traverse this
    // as a single node whose label is the text content.
    if (onTap == null) {
      return MergeSemantics(child: chrome);
    }

    // Interactive case: Material + InkWell drive the ripple, clipped to
    // the same rounded rect so the ink doesn't paint past the border.
    // Semantics marks the badge as a button and announces the label so
    // assistive tech reaches it the same way as a real button.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: chrome),
      ),
    );
  }
}
