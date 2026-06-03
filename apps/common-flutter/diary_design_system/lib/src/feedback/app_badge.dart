import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Visual style for [AppBadge].
enum AppBadgeVariant {
  /// Transparent fill with a colored border + colored label.
  outlined,

  /// Colored fill with a contrasting label.
  filled,
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
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final AppBadgeTone tone;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.outlined,
    this.tone = AppBadgeTone.neutral,
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

    final (fg, bg, borderColor) = switch (variant) {
      AppBadgeVariant.outlined => (accent, Colors.transparent, accent),
      AppBadgeVariant.filled => (theme.colorScheme.surface, accent, accent),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(RadiusTokens.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: -0.15,
          color: fg,
        ),
      ),
    );
  }
}
