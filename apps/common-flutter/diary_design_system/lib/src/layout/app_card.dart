import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A bordered content group with rounded corners — the design system's
/// "card" primitive. Used for grouping related content inside a dialog body
/// (e.g., the user-info card in the User Details dialog) or anywhere a soft
/// visual container is needed.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool noBorder;

  /// Card fill colour. Defaults to [ColorScheme.surface]. Pass a tinted fill
  /// for emphasized panels (Figma: the User Details identity card), or
  /// [Colors.transparent] to render an unfilled card whose interior matches
  /// the page background (the "Join the Study" card on the profile screen
  /// uses this).
  final Color? color;

  /// Optional title rendered above the child with a small bottom margin.
  final String? title;

  /// Test-harness locator. When set, wraps the card in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node so Playwright can scope sub-tree queries.
  final String? semanticId;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SpacingTokens.lg),
    this.color,
    this.title,
    this.semanticId,
    this.noBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final container = Container(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        border: noBorder
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
      ),
      padding: padding,
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!, style: theme.textTheme.titleSmall),
                const SizedBox(height: SpacingTokens.sm),
                child,
              ],
            ),
    );

    if (semanticId == null) return container;

    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: container,
    );
  }
}
