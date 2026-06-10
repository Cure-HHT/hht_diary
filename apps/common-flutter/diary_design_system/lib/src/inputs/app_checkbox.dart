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

  /// When true, the box border and label are rendered in
  /// `colorScheme.error`. Used by [AppConsentRow] and by form fields that
  /// surface a validation error without an inline error label.
  final bool hasError;

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
    this.hasError = false,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    final box = Checkbox(
      value: value,
      tristate: tristate,
      onChanged: enabled ? onChanged : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: hasError ? BorderSide(color: errorColor, width: 1.5) : null,
      fillColor: hasError && (value ?? false)
          ? WidgetStatePropertyAll(errorColor)
          : null,
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
                  Text(
                    label!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasError
                          ? errorColor
                          : enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
