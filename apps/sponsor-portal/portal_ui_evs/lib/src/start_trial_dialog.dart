// "Send EQ" / Start-Trial confirmation dialog, ported from the legacy portal
// (portal-ui/lib/widgets/start_trial_dialog.dart) onto the reactive stack: the
// confirm button dispatches ACT-PAT-002 through the ReAction scope, and the
// participant row flips to "Trial active" reactively on success. Starting the
// trial is what turns on the participant's Diary Data Synchronization.
//
// Implements: DIARY-PRD-questionnaire-system/C+E  (Trial Start activates Diary
//   Data Synchronization; the activation trigger is the coordinator action)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

const String _kStartTrialAction = 'ACT-PAT-002'; // {siteId, participantId}

/// Confirmation dialog for starting a participant's trial ("Send EQ"). Shows a
/// confirm prompt, dispatches `ACT-PAT-002` on confirm, and renders the
/// loading / success / error result. Driven entirely by the [ActionBuilder]
/// [ActionState] so it needs no local state of its own.
class StartTrialDialog extends StatelessWidget {
  const StartTrialDialog({
    super.key,
    required this.participantId,
    required this.siteId,
  });

  final String participantId;
  final String siteId;

  /// Shows the dialog. Resolves when it is dismissed.
  static Future<void> show({
    required BuildContext context,
    required String participantId,
    required String siteId,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        StartTrialDialog(participantId: participantId, siteId: siteId),
  );

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      // Kit (#28): surfaces the action OUTCOME state (submitting/success/denied)
      // on the semantics tree so a Playwright test can assert the result without
      // scraping localized text. The interactable buttons below are annotated
      // separately (consumer responsibility).
      semanticIdentifier: 'send-eq-outcome-$participantId',
      submissionFactory: () => ActionSubmission(
        actionName: _kStartTrialAction,
        rawInput: <String, Object?>{
          'siteId': siteId,
          'participantId': participantId,
        },
      ),
      builder: (context, state, submit) {
        final theme = Theme.of(context);
        return switch (state) {
          Submitting() => _loading(theme),
          Success() => _success(context, theme),
          Denied() || Failed() => _error(context, theme, submit, state),
          _ => _confirm(context, theme, submit), // Idle
        };
      },
    );
  }

  AlertDialog _confirm(
    BuildContext context,
    ThemeData theme,
    void Function() submit,
  ) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.play_arrow, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Start Trial for Participant $participantId?')),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    participantId,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "This will send the EQ questionnaire to the participant's mobile "
              'app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Enabled',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From now on, the participant’s diary entries '
                          'will be synced to the portal.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // CUR-1307: identified for Playwright web automation.
        Semantics(
          identifier: 'send-eq-confirm-$participantId',
          button: true,
          container: true,
          explicitChildNodes: true,
          child: FilledButton.icon(
            onPressed: submit,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send EQ'),
          ),
        ),
      ],
    );
  }

  AlertDialog _loading(ThemeData theme) {
    return AlertDialog(
      title: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Starting Trial...'),
        ],
      ),
      content: const SizedBox(
        width: 300,
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  AlertDialog _success(BuildContext context, ThemeData theme) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Trial Started'),
        ],
      ),
      content: Semantics(
        identifier: 'send-eq-success-$participantId',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trial has been started for participant $participantId. Status is '
              'now Trial Active.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              "The EQ questionnaire has been sent to the participant's mobile "
              'app. Data sync is now enabled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  AlertDialog _error(
    BuildContext context,
    ThemeData theme,
    void Function() submit,
    ActionState state,
  ) {
    final message = switch (state) {
      Denied(:final result) => 'The action was not permitted ($result).',
      Failed(:final error) => 'Failed to start trial: $error',
      _ => 'An error occurred while starting the trial.',
    };
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('Error'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please try again or contact support if the problem persists.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Try Again')),
      ],
    );
  }
}
