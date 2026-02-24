// IMPLEMENTS REQUIREMENTS:
//   REQ-p01073: Session Management

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Readiness gate screen shown before starting a questionnaire.
///
/// Shows estimated completion time and "I'm ready" / "Not now" buttons
/// per REQ-p01073-A,B.
class ReadinessScreen extends StatelessWidget {
  const ReadinessScreen({
    required this.definition,
    required this.onReady,
    required this.onDefer,
    super.key,
  });

  /// The questionnaire definition (for session config)
  final QuestionnaireDefinition definition;

  /// Called when patient taps "I'm ready"
  final VoidCallback onReady;

  /// Called when patient taps "Not now"
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = definition.sessionConfig;
    final message =
        config?.readinessMessage ??
        'Please ensure you have enough time to complete this questionnaire.';
    final estimated = config?.estimatedMinutes ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          Text(
            definition.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (estimated.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Estimated time: $estimated minutes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReady,
              icon: const Icon(Icons.check),
              label: const Text("I'm ready"),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDefer,
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}
