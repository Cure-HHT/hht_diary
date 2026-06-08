import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A small heading used to label a section inside a dialog or page —
/// "Assigned Sites (2)", "Actions", "Recent Activity", etc.
///
/// Optional [count] renders as a muted pill next to the title; [trailing]
/// sits at the far end (useful for "Edit", "See all" affordances).
// Implements: DIARY-DEV-test-instrumentation/B
class AppSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  /// Test-harness locator. When set, wraps the header in a
  /// `Semantics(identifier: ..., header: true, label: title, container: true, explicitChildNodes: true)`
  /// node so Playwright can locate it and assertive tech announces it as
  /// a heading.
  final String? semanticId;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: SpacingTokens.sm),
          _CountBadge(count: count!),
        ],
        const Spacer(),
        ?trailing,
      ],
    );

    if (semanticId == null) return row;

    return Semantics(
      identifier: semanticId,
      header: true,
      label: title,
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(RadiusTokens.full),
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
