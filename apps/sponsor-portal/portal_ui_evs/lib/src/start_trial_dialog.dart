// "Send EQ" / Start-Trial confirmation dialog (Figma: Start Trial): the
// confirm button dispatches ACT-PAT-002 through the ReAction scope, and the
// participant row flips to "Trial Active" reactively on success. Starting the
// trial is what turns on the participant's Diary Data Synchronization —
// "Send EQ" is the sponsor-requested label for that signal.
//
// Implements: DIARY-PRD-questionnaire-system/C+E  (Trial Start activates Diary
//   Data Synchronization; the activation trigger is the coordinator action)
import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

const String _kStartTrialAction = 'ACT-PAT-002'; // {siteId, participantId}

/// Confirmation dialog for starting a participant's trial ("Send EQ"). Shows
/// the Figma confirm prompt, dispatches `ACT-PAT-002` on confirm, and renders
/// the loading / success / error result. Driven entirely by the
/// [ActionBuilder] [ActionState] so it needs no local state of its own.
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
        switch (state) {
          case Success():
            return AppDialog(
              size: AppDialogSize.small,
              title: 'Trial Started',
              dismissible: false,
              body: Semantics(
                identifier: 'send-eq-success-$participantId',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trial has been started for participant $participantId. '
                      'Status is now Trial Active.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Diary Data Synchronization is now enabled.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          case Denied() || Failed():
            return AppDialog(
              size: AppDialogSize.small,
              title: 'Error',
              dismissible: false,
              body: AppBanner(
                severity: AppBannerSeverity.error,
                message: switch (state) {
                  Denied(:final result) =>
                    'The action was not permitted ($result).',
                  Failed(:final error) => 'Failed to start trial: $error',
                  _ => 'An error occurred while starting the trial.',
                },
              ),
              actions: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                AppButton(label: 'Try Again', onPressed: submit),
              ],
            );
          default:
            final busy = state is Submitting;
            return AppDialog(
              size: AppDialogSize.small,
              title: 'Start Trial',
              dismissible: true,
              semanticId: 'start-trial-dialog-$participantId',
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Participant ID: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: participantId,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Confirming will activate Diary Data Synchronization '
                    "between the Participant's Mobile Application and the "
                    'Sponsor Portal. Diary entries will begin transmitting '
                    'to the Sponsor Portal and Rave EDC.',
                  ),
                ],
              ),
              actions: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  label: 'Cancel',
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
                AppButton(
                  label: 'Send EQ',
                  loading: busy,
                  onPressed: busy ? null : submit,
                  semanticId: 'send-eq-confirm-$participantId',
                ),
              ],
            );
        }
      },
    );
  }
}
