import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Visual tone for [BrandedStatusCard]. Drives the outer fill, border,
/// and body text colour together so all three cues stay in agreement.
///
/// Maps to the three Figma sponsor-status cards on the notifications
/// screen:
///   - [success] — node `486:1801` "Connected".
///   - [neutral] — node `486:1812` "Study Participation Ended".
///   - [error]   — node `486:2575` "Disconnected".
enum BrandedStatusTone { success, neutral, error }

/// A status card with a branded white header strip on top of a
/// tone-tinted body — the sponsor-status pattern used in the linking-
/// code flows.
///
/// Anatomy (top to bottom):
///   - White 45-px header strip with [header] (typically a sponsor
///     logo image) centred inside it.
///   - Body: tone-tinted background with leading [icon] (34×34), then
///     [title] (Inter SemiBold 16) and optional [body] in a column.
///   - Optional [action] rendered below the icon/text row — e.g. an
///     outlined button matching the tone for the "Disconnected" card.
///
/// The default text style inside [body] inherits the resolved tone
/// colour so a `Text.rich` composition can override a single line (e.g.
/// the linking-code line on the success card uses Dark Grey instead of
/// Approved Dark).
class BrandedStatusCard extends StatelessWidget {
  final BrandedStatusTone tone;
  final Widget header;
  final IconData icon;
  final String title;
  final Widget? body;
  final Widget? action;

  /// Test-harness locator. When set, wraps the card in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node.
  final String? semanticId;

  const BrandedStatusCard({
    super.key,
    required this.tone,
    required this.header,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (accent, background, textColor) = _toneColors(theme);

    final card = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: accent),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // White header strip laid over the tone-tinted card body —
          // matches the Figma's `bg-white h-[45px]` rectangle drawn
          // absolutely over the tinted card.
          Container(
            height: 45,
            color: theme.colorScheme.surface,
            alignment: Alignment.center,
            child: header,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg,
              SpacingTokens.lg,
              SpacingTokens.lg,
              action == null ? SpacingTokens.lg : SpacingTokens.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 34, color: textColor),
                SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 23.8 / 16,
                      letterSpacing: -0.4316,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (body != null) ...[
                          SizedBox(height: SpacingTokens.xs),
                          body!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.lg,
                0,
                SpacingTokens.lg,
                SpacingTokens.lg,
              ),
              child: action!,
            ),
        ],
      ),
    );

    if (semanticId == null) return card;
    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: card,
    );
  }

  /// Returns `(border, background, textColor)` for the current [tone].
  /// `border` matches the Figma stroke; `background` is the tinted card
  /// fill; `textColor` is the default for body content (callers may
  /// override individual spans via a `Text.rich` composition).
  (Color border, Color background, Color textColor) _toneColors(
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    return switch (tone) {
      BrandedStatusTone.success => (
        semantic.success,
        semantic.successContainer,
        semantic.onSuccessContainer,
      ),
      // Neutral uses Material's surfaceContainer (Figma "Light Gray"
      // #ECEEF0) + outline (Figma "Grey" #A4B9C2) + onSurfaceVariant
      // (Figma "Dark Grey" #54636A) — all theme slots, all exact.
      BrandedStatusTone.neutral => (
        cs.outline,
        cs.surfaceContainer,
        cs.onSurfaceVariant,
      ),
      // Error uses `onErrorContainer` for both border and text so the
      // darker red is consistent (Figma renders both in Critical Dark).
      BrandedStatusTone.error => (
        cs.onErrorContainer,
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };
  }
}
