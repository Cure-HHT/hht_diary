// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Vertical radio-style selector for a 5-point response scale.
///
/// Displays each option as a tappable row with a radio indicator.
/// Per REQ-p01070-A / REQ-p01071-A.
class ResponseScaleSelector extends StatelessWidget {
  const ResponseScaleSelector({
    required this.options,
    required this.onSelected,
    this.selectedValue,
    super.key,
  });

  /// The response scale options to display
  final List<ResponseScaleOption> options;

  /// Currently selected value (null if none selected)
  final int? selectedValue;

  /// Called when the patient selects an option
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        final isSelected = selectedValue == option.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(option.value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
