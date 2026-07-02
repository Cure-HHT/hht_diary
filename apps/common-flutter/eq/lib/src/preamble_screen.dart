import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Preamble pages shown one at a time before the questions.
///
/// Participant must acknowledge each page by tapping "Continue".
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/A
class PreambleScreen extends StatelessWidget {
  const PreambleScreen({
    required this.preamble,
    required this.currentIndex,
    required this.totalCount,
    required this.onContinue,
    super.key,
  });

  /// The current preamble item to display
  final PreambleItem preamble;

  /// Index of current preamble (0-based)
  final int currentIndex;

  /// Total number of preamble items
  final int totalCount;

  /// Called when participant taps "Continue"
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  preamble.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (totalCount > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${currentIndex + 1} of $totalCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
