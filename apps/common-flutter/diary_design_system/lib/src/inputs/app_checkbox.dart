import 'package:flutter/material.dart';

import '../tokens/spacing_tokens.dart';

/// The design system checkbox.
///
/// A thin wrapper over Material [Checkbox] that pulls colors from the theme
/// and adds an optional inline label. For checkbox lists (e.g., the Edit User
/// "Assigned Sites" pattern from the Figma), compose this with a `Column` of
/// AppCheckboxes — there isn't a dedicated list widget yet.
class AppCheckbox extends StatelessWidget {
  /// `true`, `false`, or `null` (when [tristate] is enabled).
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final bool enabled;
  final bool tristate;

  /// Test-harness locator. When set, wraps the checkbox in a
  /// `Semantics(identifier: ..., checked: value ?? false, container: true, explicitChildNodes: true)`
  /// node so Playwright can target it and assert its checked state.
  final String? semanticId;

  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.enabled = true,
    this.tristate = false,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final box = Checkbox(
      value: value,
      tristate: tristate,
      onChanged: enabled ? onChanged : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final laidOut = label == null
        ? box
        : InkWell(
            onTap: enabled && onChanged != null
                ? () => onChanged!(
                    tristate ? _nextTristate(value) : !(value ?? false),
                  )
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  box,
                  SizedBox(width: SpacingTokens.sm),
                  // Flexible so long labels (e.g. "002 - Stanford Medical
                  // Center" in a boxed site checklist) wrap instead of
                  // overflowing the row.
                  Flexible(
                    child: Text(
                      label!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (semanticId == null) return laidOut;

    return Semantics(
      identifier: semanticId,
      checked: value ?? false,
      container: true,
      explicitChildNodes: true,
      child: laidOut,
    );
  }

  bool? _nextTristate(bool? current) {
    return switch (current) {
      false => true,
      true => null,
      null => false,
    };
  }
}
