import 'package:flutter/material.dart';

import '../tokens/spacing_tokens.dart';

/// A label / value pair. Extracted from the `_buildInfoRow` pattern
/// duplicated across portal-ui dialog success states.
///
/// Example:
/// ```dart
/// AppInfoRow(label: 'Linking codes revoked', value: '3')
/// ```
// Implements: DIARY-DEV-test-instrumentation/B
class AppInfoRow extends StatelessWidget {
  final String label;

  /// String value — for richer cells use [valueWidget] instead.
  final String? value;

  /// Optional widget value, takes precedence over [value] when provided.
  final Widget? valueWidget;

  /// Label column width. Defaults to 140 px to match the portal pattern.
  final double labelWidth;

  /// Test-harness locator. When set, wraps the row in a
  /// `Semantics(identifier: ..., label: label, value: value, container: true, explicitChildNodes: true)`
  /// node so Playwright can read either side via `readSemanticValue` or
  /// the label channel.
  final String? semanticId;

  const AppInfoRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelWidth = 140,
    this.semanticId,
  }) : assert(
         value != null || valueWidget != null,
         'AppInfoRow requires either value or valueWidget',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.md),
        Expanded(
          child:
              valueWidget ??
              Text(
                value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
        ),
      ],
    );

    if (semanticId == null) return row;

    return Semantics(
      identifier: semanticId,
      label: label,
      value: value ?? '',
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }
}
