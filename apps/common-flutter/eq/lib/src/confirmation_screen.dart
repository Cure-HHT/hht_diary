// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI

import 'package:flutter/material.dart';

/// Success confirmation screen shown after questionnaire submission.
///
/// Shows a checkmark, success message, and "Done" button
/// per REQ-p01070-F / REQ-p01071-F.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    required this.questionnaireName,
    required this.onDone,
    super.key,
  });

  /// Name of the submitted questionnaire
  final String questionnaireName;

  /// Called when patient taps "Done"
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade50,
            ),
            child: Icon(
              Icons.check_circle,
              size: 56,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Submitted for Review',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your $questionnaireName responses have been submitted. '
            'Your investigator will review them.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onDone, child: const Text('Done')),
          ),
        ],
      ),
    );
  }
}
