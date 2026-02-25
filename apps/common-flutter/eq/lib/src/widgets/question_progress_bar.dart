// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI

import 'package:flutter/material.dart';

/// Linear progress indicator showing "Question X of Y".
///
/// Displays a progress bar and text label.
class QuestionProgressBar extends StatelessWidget {
  const QuestionProgressBar({
    required this.current,
    required this.total,
    super.key,
  });

  /// Current question number (1-based)
  final int current;

  /// Total number of questions
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total > 0 ? current / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Question $current of $total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
