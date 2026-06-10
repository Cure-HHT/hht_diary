import 'package:flutter/material.dart';

import '../tokens/spacing_tokens.dart';
import 'app_button.dart';

/// A single choice in an [AppSegmentedChoice] group.
@immutable
class AppChoiceOption<T> {
  final T value;
  final String label;
  const AppChoiceOption({required this.value, required this.label});
}

/// A horizontal single-select choice group — the "Yes / No / Don't
/// remember" prompt from the notifications / alerts screens.
///
/// Each option renders via [AppButton] with the [AppButtonVariant.segment]
/// variant so the borderless 34-px pill chrome stays in one place and a
/// sponsor brand override flows through. Selected option uses
/// `selected: true`; unselected uses `selected: false`. Buttons share
/// the row width equally with [SpacingTokens.sm] (8) between them.
class AppSegmentedChoice<T> extends StatelessWidget {
  final List<AppChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  /// Test-harness locator prefix. When set, each option gets the
  /// identifier `<semanticId>-<value>` so harnesses can target each
  /// button individually and assert the selected state.
  final String? semanticId;

  const AppSegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticId,
  }) : assert(options.length > 0, 'AppSegmentedChoice requires ≥ 1 option');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: AppButton(
              variant: AppButtonVariant.segment,
              label: options[i].label,
              selected: options[i].value == value,
              fullWidth: true,
              onPressed: enabled && onChanged != null
                  ? () => onChanged!(options[i].value)
                  : null,
              semanticId: semanticId == null
                  ? null
                  : '$semanticId-${options[i].value}',
            ),
          ),
        ],
      ],
    );
  }
}
