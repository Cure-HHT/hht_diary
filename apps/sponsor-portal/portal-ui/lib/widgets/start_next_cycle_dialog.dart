// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00080: Questionnaire Study Event Association (Assertion C)
//
// Confirmation dialog shown when starting the next cycle for a questionnaire.
// Displays the auto-incremented cycle number and asks for confirmation.

import 'package:flutter/material.dart';

import 'portal_button.dart';

/// Dialog that confirms sending the next cycle questionnaire.
///
/// Shown when the SC clicks "Start Next Cycle" (auto-increment, no dropdown).
/// Returns true if confirmed, null if cancelled.
class StartNextCycleDialog extends StatelessWidget {
  final String cycleLabel;
  final String patientDisplayId;
  final String questionnaireDisplayName;

  const StartNextCycleDialog({
    super.key,
    required this.cycleLabel,
    required this.patientDisplayId,
    required this.questionnaireDisplayName,
  });

  /// Shows the dialog. Returns true if confirmed, null if cancelled.
  static Future<bool?> show({
    required BuildContext context,
    required String cycleLabel,
    required String patientDisplayId,
    required String questionnaireDisplayName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StartNextCycleDialog(
        cycleLabel: cycleLabel,
        patientDisplayId: patientDisplayId,
        questionnaireDisplayName: questionnaireDisplayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: Color(0xFF6383FD),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Start Next Cycle',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
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
            Text(
              'Confirm sending questionnaire for the next cycle',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD0DBFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2868FC),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'You are sending a questionnaire for ',
                            children: [
                              TextSpan(
                                text: cycleLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2868FC),
                                ),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Participant: $patientDisplayId',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Questionnaire: $questionnaireDisplayName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'The patient will receive this questionnaire on their mobile device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
          onPressed: () => Navigator.of(context).pop(true),
          label: 'Confirm & Send',
        ),
      ],
    );
  }
}
