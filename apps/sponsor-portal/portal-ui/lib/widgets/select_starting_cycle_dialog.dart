// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion H)
//
// Dialog for selecting the starting cycle number when sending the first
// questionnaire of a type to a patient. Supports patients transitioning
// from paper records who may need to start at a cycle > 1.

import 'package:flutter/material.dart';

/// Dialog that prompts the Study Coordinator to select a starting cycle.
///
/// Shown on the first send of each questionnaire type per patient (or after
/// all previous sends were deleted). Returns the selected cycle number or
/// null if cancelled.
class SelectStartingCycleDialog extends StatefulWidget {
  final String questionnaireDisplayName;
  final int? suggestedCycle;

  const SelectStartingCycleDialog({
    super.key,
    required this.questionnaireDisplayName,
    this.suggestedCycle,
  });

  /// Shows the dialog and returns the selected cycle number, or null if
  /// cancelled.
  static Future<int?> show({
    required BuildContext context,
    required String questionnaireDisplayName,
    int? suggestedCycle,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SelectStartingCycleDialog(
        questionnaireDisplayName: questionnaireDisplayName,
        suggestedCycle: suggestedCycle,
      ),
    );
  }

  @override
  State<SelectStartingCycleDialog> createState() =>
      _SelectStartingCycleDialogState();
}

class _SelectStartingCycleDialogState extends State<SelectStartingCycleDialog> {
  late int _selectedCycle;

  @override
  void initState() {
    super.initState();
    _selectedCycle = widget.suggestedCycle ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Starting Cycle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select the starting cycle for this patient\'s '
            '${widget.questionnaireDisplayName} questionnaire.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedCycle,
            decoration: const InputDecoration(
              labelText: 'Starting Cycle',
              border: OutlineInputBorder(),
            ),
            items: List.generate(20, (i) {
              final cycle = i + 1;
              return DropdownMenuItem<int>(
                value: cycle,
                child: Text('Cycle $cycle Day 1'),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCycle = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedCycle),
          child: const Text('Confirm and Send'),
        ),
      ],
    );
  }
}
