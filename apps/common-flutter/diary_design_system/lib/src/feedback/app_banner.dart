import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

enum AppBannerSeverity { success, warning, error, info }

/// Inline status / severity banner.
///
/// Replaces the ad-hoc `Container` + `Icon.warning_amber` + tinted border
/// pattern that was duplicated across the portal dialogs. Each severity binds
/// to its semantic color pair (foreground + container background) plus a
/// canonical Material icon.
///
/// The [trailing] slot is for caller-supplied actions — a dismiss `AppButton`,
/// a "Retry" button, an external link, etc. Keep it small; the banner is
/// inline, not a full alert.
class AppBanner extends StatelessWidget {
  final AppBannerSeverity severity;
  final String? title;

  /// Plain-text body. Optional when [body] is provided.
  final String? message;

  /// Rich body slot rendered where [message] would go — for content a
  /// single Text can't express (Figma: the "Effects of this action"
  /// panels' bullet lists). Takes precedence over [message].
  final Widget? body;

  /// Overrides the severity's canonical icon (Figma: the deactivate
  /// panel's block glyph, the reactivate panel's circled info glyph).
  final IconData? icon;
  final Widget? trailing;

  /// Override the default severity icon. When null, the severity's canonical
  /// glyph is used. Ignored when [showIcon] is false.
  final IconData? icon;

  /// When false, no leading icon is rendered — for the soft info note
  /// pattern in the Figma where the message stands alone.
  final bool showIcon;

  /// Test-harness locator. When set, wraps the banner in a
  /// `Semantics(identifier: ..., value: message, liveRegion: true, container: true)`
  /// node so Playwright's `readSemanticValue` can read the banner's message
  /// directly (critical for error-state assertions).
  final String? semanticId;

  const AppBanner({
    super.key,
    required this.severity,
    this.message,
    this.body,
    this.icon,
    this.title,
    this.trailing,
    this.icon,
    this.showIcon = true,
    this.semanticId,
  }) : assert(
         message != null || body != null,
         'AppBanner requires message and/or body',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (foreground, background, defaultIcon) = _resolveSeverity(
      theme,
      semantic,
    );

    final container = Container(
      padding: EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: foreground.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon) ...[
            Icon(icon ?? defaultIcon, size: 20, color: foreground),
            SizedBox(width: SpacingTokens.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: SpacingTokens.xxs),
                ],
                if (body != null)
                  body!
                else
                  Text(message!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: SpacingTokens.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (semanticId == null) return container;

    return Semantics(
      identifier: semanticId,
      value: message ?? title ?? '',
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: container,
    );
  }

  (Color foreground, Color background, IconData icon) _resolveSeverity(
    ThemeData theme,
    AppSemanticColors semantic,
  ) {
    return switch (severity) {
      AppBannerSeverity.success => (
        semantic.success,
        semantic.successContainer,
        Icons.check_circle_outline,
      ),
      AppBannerSeverity.warning => (
        semantic.warning,
        semantic.warningContainer,
        Icons.warning_amber_outlined,
      ),
      AppBannerSeverity.error => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer,
        Icons.error_outline,
      ),
      AppBannerSeverity.info => (
        semantic.info,
        semantic.infoContainer,
        Icons.info_outline,
      ),
    };
  }
}
