// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion H)
//
// Dialog for selecting the starting cycle number when sending the first
// questionnaire of a type to a patient. Supports patients transitioning
// from paper records who may need to start at a cycle > 1.

import 'package:flutter/material.dart';

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
              'Select Starting Cycle',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
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
            // Subtitle with bold patient ID
            Text.rich(
              TextSpan(
                text:
                    'Choose which cycle this ${widget.questionnaireDisplayName} '
                    'questionnaire belongs to for patient ',
                children: [
                  TextSpan(
                    text: widget.patientDisplayId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Info card with calendar icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFeff6ff),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD0DBFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF2868fc),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      const TextSpan(
                        text: 'Select ',
                        children: [
                          TextSpan(
                            text: 'Cycle 1 Day 1',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                ' if this is the patient\'s first cycle, or a '
                                'later cycle if the patient started on paper diaries.',
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF334e99),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dropdown
            PortalDropdown<int>(
              label: 'Starting Cycle',
              value: _selectedCycle,
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
      ),
      actions: [
        PortalButton.outlined(
          onPressed: () => Navigator.of(context).pop(null),
          label: 'Cancel',
        ),
        PortalButton(
          onPressed: () => Navigator.of(context).pop(_selectedCycle),
          label: 'Confirm and Send',
        ),
      ],
    );
  }
}
