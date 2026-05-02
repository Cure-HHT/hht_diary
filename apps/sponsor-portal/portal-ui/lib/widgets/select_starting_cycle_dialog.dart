// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion H)
//
// Dialog for selecting the starting cycle number when sending the first
// questionnaire of a type to a patient. Supports patients transitioning
// from paper records who may need to start at a cycle > 1.

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'portal_button.dart';
import 'portal_dropdown.dart';

/// Dialog that prompts the Study Coordinator to select a starting cycle.
///
/// Shown on the first send of each questionnaire type per patient (or after
/// all previous sends were deleted). Returns the selected cycle number or
/// null if cancelled.
class SelectStartingCycleDialog extends StatefulWidget {
  final String questionnaireDisplayName;
  final String patientDisplayId;
  final int? suggestedCycle;

  const SelectStartingCycleDialog({
    super.key,
    required this.questionnaireDisplayName,
    required this.patientDisplayId,
    this.suggestedCycle,
  });

  /// Shows the dialog and returns the selected cycle number, or null if
  /// cancelled.
  static Future<int?> show({
    required BuildContext context,
    required String questionnaireDisplayName,
    required String patientDisplayId,
    int? suggestedCycle,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SelectStartingCycleDialog(
        questionnaireDisplayName: questionnaireDisplayName,
        patientDisplayId: patientDisplayId,
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
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Start Questionnaire?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cycle dropdown
            PortalDropdown<int>(
              label: 'Cycle',
              value: _selectedCycle,
              items: List.generate(100, (i) {
                final cycle = i + 1;
                return DropdownMenuItem<int>(
                  value: cycle,
                  child: Text(StudyEvent.format(cycle)),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCycle = value);
                }
              },
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF2E7D32),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "The questionnaire will be sent to the participant's "
                      'Daily Diary app. They will receive a notification to '
                      'complete it.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        PortalButton.outlined(
          onPressed: () => Navigator.of(context).pop(null),
          label: 'Cancel',
        ),
        PortalButton(
          onPressed: () => Navigator.of(context).pop(_selectedCycle),
          icon: Icons.check_circle_outline,
          label: 'Confirm and Send',
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
