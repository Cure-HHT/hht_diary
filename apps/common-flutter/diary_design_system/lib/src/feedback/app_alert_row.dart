import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Visual tone for [AppAlertRow]. Drives the background tint + border +
/// leading-icon + chevron colour together so all four cues stay in
/// agreement.
enum AppAlertRowTone {
  /// Soft brand-blue — for routine prompts ("Complete X").
  primary,

  /// Amber — for items needing attention ("1 incomplete record").
  warning,

  /// Critical / red — for blocking errors surfaced inline.
  error,

  /// Green — for completed / acknowledged states.
  success,
}

/// A tinted, tappable row — the action / alert pattern shown inside the
/// "Needs your attention" expansion tile.
///
/// Anatomy: leading [icon] · [label] · trailing chevron (rendered only
/// when [onTap] is non-null, since the chevron is a tap affordance).
///
/// Per the Figma spec the row has no border — just a tone-tinted fill
/// with rounded corners. Colour is resolved once via [_toneColors] so
/// the bg, icon and chevron always derive from the same swatch.
class AppAlertRow extends StatelessWidget {
  final AppAlertRowTone tone;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  /// Test-harness locator. When set, wraps the row in a
  /// `Semantics(identifier: ..., button: <onTap != null>, container: true, explicitChildNodes: true)`
  /// node.
  final String? semanticId;

  const AppAlertRow({
    super.key,
    required this.tone,
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.semanticId,
  });

  /// "N incomplete record(s)" row — Figma node `452:9374`. Warning tone
  /// (amber pending bg), info-circle leading icon. [count] drives the
  /// label's singular/plural form so callers don't repeat that logic.
  factory AppAlertRow.incompleteRecord({
    Key? key,
    required int count,
    VoidCallback? onTap,
    bool enabled = true,
    String? semanticId,
  }) {
    final noun = count == 1 ? 'record' : 'records';
    return AppAlertRow(
      key: key,
      tone: AppAlertRowTone.warning,
      icon: Icons.info_outlined,
      label: '$count incomplete $noun',
      onTap: onTap,
      enabled: enabled,
      semanticId: semanticId,
    );
  }

  /// "Available questionnaire" prompt row — Figma node `452:9363`.
  /// Primary-light tone, clipboard-with-check leading icon. The [label]
  /// is the questionnaire title (e.g. "Complete Quality of Life Survey").
  factory AppAlertRow.availableQuestionnaire({
    Key? key,
    required String label,
    IconData icon = Icons.assignment_turned_in_outlined,
    VoidCallback? onTap,
    bool enabled = true,
    String? semanticId,
  }) {
    return AppAlertRow(
      key: key,
      tone: AppAlertRowTone.primary,
      icon: icon,
      label: label,
      onTap: onTap,
      enabled: enabled,
      semanticId: semanticId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (accent, background) = _toneColors(theme);

    final radius = BorderRadius.circular(RadiusTokens.md);
    final effectiveOnTap = enabled ? onTap : null;

    final content = Padding(
      padding: EdgeInsets.all(SpacingTokens.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (effectiveOnTap != null) ...[
            SizedBox(width: SpacingTokens.sm),
            Icon(Icons.chevron_right, size: 20, color: accent),
          ],
        ],
      ),
    );

    final row = Material(
      color: background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: radius,
        child: content,
      ),
    );

    if (semanticId == null) return row;

    return Semantics(
      identifier: semanticId,
      button: effectiveOnTap != null,
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }

  (Color accent, Color background) _toneColors(ThemeData theme) {
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (tone) {
      // Brand "Primary Light" — the medium-light primary the Figma uses
      // for non-critical action rows. Bound via AppSemanticColors so
      // sponsor brand overrides can flow through.
      AppAlertRowTone.primary => (
        semantic.primaryLight,
        semantic.primaryLightSoft,
      ),
      AppAlertRowTone.warning => (semantic.warning, semantic.warningContainer),
      AppAlertRowTone.error => (cs.error, cs.errorContainer),
      AppAlertRowTone.success => (semantic.success, semantic.successContainer),
    };
  }
}
