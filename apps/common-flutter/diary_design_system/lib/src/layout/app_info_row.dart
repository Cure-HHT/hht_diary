import 'package:flutter/material.dart';

import '../tokens/spacing_tokens.dart';

/// A label / value pair. Extracted from the `_buildInfoRow` pattern
/// duplicated across portal-ui dialog success states.
///
/// Example:
/// ```dart
/// AppInfoRow(label: 'Linking codes revoked', value: '3')
/// ```
class AppInfoRow extends StatelessWidget {
  final String label;

  /// String value — for richer cells use [valueWidget] instead.
  final String? value;

  /// Optional widget value, takes precedence over [value] when provided.
  final Widget? valueWidget;

  /// Label column width. Defaults to 140 px to match the portal pattern.
  final double labelWidth;

  const AppInfoRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelWidth = 140,
  }) : assert(
         value != null || valueWidget != null,
         'AppInfoRow requires either value or valueWidget',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
  }
}
