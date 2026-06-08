// The Manage Questionnaires modal (reactive). For a participant it shows one
// Questionnaire Card per enabled Questionnaire Type, each rendering the Type's
// current Status + paired Cycle info and exactly the action buttons the
// per-status matrix permits. Status is derived live from the reactive
// `questionnaire_instance` view (gated view:questionnaire_instance), filtered
// client-side to the selected participant.
//
// This task (Task 7) builds presentation + pure card-state wiring only: the
// action buttons invoke INJECTED callbacks. The dialogs they launch and the
// HTTP/action dispatch are Task 8 — it supplies real handlers; here the modal
// just invokes them.
//
// Implements: DIARY-BASE-questionnaire-manage-modal/A+B+C+D+E
// Explicit for @visibleForTesting (also re-exported transitively by
// material.dart, hence the ignore).
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction_widgets/reaction_widgets.dart';

import 'questionnaire_card_state.dart';
import 'questionnaire_instance.dart';
import 'questionnaire_types.dart';

const String _viewPerm = 'view:questionnaire_instance';

/// Reactive Manage Questionnaires modal for a single participant.
///
/// Subscribes to the `questionnaire_instance` view, filters to [participantId],
/// groups by type, and renders one [_QuestionnaireCard] per enabled type with
/// the resolved [QuestionnaireCardState]. The three action callbacks are
/// injected; Task 8 supplies the real send / call-back handlers.
class ManageQuestionnairesDialog extends StatelessWidget {
  const ManageQuestionnairesDialog({
    super.key,
    required this.participantId,
    required this.siteId,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
  });

  final String participantId;
  final String siteId;

  /// Invoked with the questionnaire type id when Send Now is tapped.
  final void Function(String questionnaireType) onSendNow;

  /// Invoked with the questionnaire type id when Start Next Cycle is tapped.
  final void Function(String questionnaireType) onStartNextCycle;

  /// Invoked with the current (open) instance when Call Back is tapped.
  final void Function(QuestionnaireInstance current) onCallBack;

  /// Shows the dialog. Resolves when it is dismissed.
  static Future<void> show({
    required BuildContext context,
    required String participantId,
    required String siteId,
    required void Function(String questionnaireType) onSendNow,
    required void Function(String questionnaireType) onStartNextCycle,
    required void Function(QuestionnaireInstance current) onCallBack,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ManageQuestionnairesDialog(
      participantId: participantId,
      siteId: siteId,
      onSendNow: onSendNow,
      onStartNextCycle: onStartNextCycle,
      onCallBack: onCallBack,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Manage Questionnaires',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Assertion A: the modal header shows the participant identifier.
                Text.rich(
                  TextSpan(
                    text: 'Participant ',
                    children: <InlineSpan>[
                      TextSpan(
                        text: participantId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Assertion C: a close action dismisses with no change.
          Semantics(
            identifier: 'qst-close-$participantId',
            button: true,
            container: true,
            explicitChildNodes: true,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: PermissionGate(
          permission: _viewPerm,
          fallback: const Padding(
            padding: EdgeInsets.all(16),
            child: Text("You don't have permission to view questionnaires."),
          ),
          child: ViewBuilder<QuestionnaireInstance>(
            viewName: 'questionnaire_instance',
            mapper: QuestionnaireInstance.fromRow,
            aggregateIdOf: (q) => q.instanceId,
            builder: (context, state) {
              if (state is Loading<QuestionnaireInstance>) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final rows = switch (state) {
                Loading<QuestionnaireInstance>() =>
                  const <QuestionnaireInstance>[],
                Ready<QuestionnaireInstance>(:final rows) => rows,
                Stale<QuestionnaireInstance>(:final lastRows) => lastRows,
              };
              // Filter to this participant; tombstoned (called-back) rows are
              // simply not delivered by the view.
              final mine = <QuestionnaireInstance>[
                for (final r in rows)
                  if (r.participantId == participantId) r,
              ];
              // Group by type.
              final byType = <String, List<QuestionnaireInstance>>{};
              for (final r in mine) {
                (byType[r.type] ??= <QuestionnaireInstance>[]).add(r);
              }
              // One card per ENABLED type (assertion B); a type with no rows
              // resolves to never-sent.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final type in kEnabledQuestionnaireTypes)
                    _QuestionnaireCard(
                      participantId: participantId,
                      type: type,
                      rowsForType:
                          byType[type.id] ?? const <QuestionnaireInstance>[],
                      onSendNow: onSendNow,
                      onStartNextCycle: onStartNextCycle,
                      onCallBack: onCallBack,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One Questionnaire Card: the Type display name + a Status badge with the
/// Cycle info paired inline (assertion D), and exactly the action buttons the
/// resolved [QuestionnaireCardState] permits for the Type (assertion E).
///
/// Implements: DIARY-BASE-questionnaire-manage-modal/D+E
class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({
    required this.participantId,
    required this.type,
    required this.rowsForType,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
  });

  final String participantId;
  final QuestionnaireType type;
  final List<QuestionnaireInstance> rowsForType;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = resolveCardState(rowsForType);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Type name + status badge.
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    type.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(state: state),
              ],
            ),
            const SizedBox(height: 8),
            // Cycle info paired inline with the status it describes
            // (assertion D).
            _CycleInfo(state: state),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final action in state.actions)
                  _ActionButton(
                    participantId: participantId,
                    typeId: type.id,
                    action: action,
                    state: state,
                    onSendNow: onSendNow,
                    onStartNextCycle: onStartNextCycle,
                    onCallBack: onCallBack,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The status chip for a card. For a genuine terminal Closed (Phase 4) the
/// matrix calls for a combined "Closed · End of Treatment/Study" badge; that
/// terminal state is not produced by the view yet, so the badge shows the
/// plain status label.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final QuestionnaireCardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.status.label,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Renders the Cycle field(s) appropriate to the card's status, paired inline
/// with the cycle they describe (assertion D):
///  * Sent / Ready to Review -> `Current Cycle: <studyEvent>`.
///  * Not Sent after-finalize -> `Finalized Cycle: <studyEvent>` + `Next Cycle`.
///  * Not Sent (never sent) -> nothing.
class _CycleInfo extends StatelessWidget {
  const _CycleInfo({required this.state});

  final QuestionnaireCardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final emph = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.bold,
    );

    // Current Cycle (Sent / Ready to Review).
    if (state.currentStudyEvent != null) {
      return Text.rich(
        TextSpan(
          text: 'Current Cycle: ',
          style: muted,
          children: <InlineSpan>[
            TextSpan(text: state.currentStudyEvent, style: emph),
          ],
        ),
      );
    }

    // Finalized Cycle + Next Cycle (Not Sent after-finalize).
    if (state.finalizedStudyEvent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              text: 'Finalized Cycle: ',
              style: muted,
              children: <InlineSpan>[
                TextSpan(text: state.finalizedStudyEvent, style: emph),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('Next Cycle', style: muted),
        ],
      );
    }

    // Never sent -> no cycle fields.
    return const SizedBox.shrink();
  }
}

/// One action button. Send Now / Start Next Cycle / Call Back invoke the
/// injected callbacks; Finalize renders DISABLED with a Phase-4 tooltip (the
/// finalize flow + the `<id>_survey` Ready-to-Review join arrive in Phase 4).
/// Each interactive button carries a stable Semantics identifier for Playwright.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.participantId,
    required this.typeId,
    required this.action,
    required this.state,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
  });

  final String participantId;
  final String typeId;
  final QuestionnaireCardAction action;
  final QuestionnaireCardState state;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;

  @override
  Widget build(BuildContext context) {
    // Finalize is rendered but DISABLED until Phase 4 (no finalize behavior is
    // wired here). The Delivery-Failed troubleshooting popover (assertions N/O)
    // is likewise deferred.
    // TODO(Phase 4/later): wire Finalize + the Delivery-Failed troubleshooting
    //   popover (info icon).
    if (action == QuestionnaireCardAction.finalize) {
      return Tooltip(
        message: 'Finalize arrives in Phase 4',
        child: FilledButton(onPressed: null, child: Text(action.label)),
      );
    }

    final VoidCallback onPressed;
    switch (action) {
      case QuestionnaireCardAction.sendNow:
        onPressed = () => onSendNow(typeId);
      case QuestionnaireCardAction.startNextCycle:
        onPressed = () => onStartNextCycle(typeId);
      case QuestionnaireCardAction.callBack:
        // Call Back targets the current open instance. resolveCardState only
        // offers callBack when an open instance exists, so the lookup is safe.
        final current = _currentInstance();
        onPressed = current == null ? () {} : () => onCallBack(current);
      case QuestionnaireCardAction.finalize:
        onPressed = () {}; // Unreachable — handled above.
    }

    // Stable identifier for Playwright e2e (mirrors the send-eq-confirm-...
    // pattern); container + explicitChildNodes keep it from being merged away
    // by the button's own button semantics.
    return Semantics(
      identifier: 'qst-${action.name}-$typeId-$participantId',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: FilledButton(onPressed: onPressed, child: Text(action.label)),
    );
  }

  /// The open instance backing a Call Back, looked up from the rows the state
  /// was resolved from (carried via [QuestionnaireCardState.currentInstanceId]).
  QuestionnaireInstance? _currentInstance() {
    final id = state.currentInstanceId;
    if (id == null) return null;
    return QuestionnaireInstance(
      instanceId: id,
      participantId: participantId,
      type: typeId,
      studyEvent: state.currentStudyEvent,
      status: state.status,
    );
  }
}

/// Test-only harness: renders a single [_QuestionnaireCard] over an injected
/// row set so the card's status/cycle/action rendering can be verified without
/// standing up a live ViewBuilder. Recording callback invocations is the
/// caller's responsibility (pass closures).
@visibleForTesting
class ManageQuestionnairesCardHarness extends StatelessWidget {
  const ManageQuestionnairesCardHarness({
    super.key,
    required this.participantId,
    required this.type,
    required this.rowsForType,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
  });

  final String participantId;
  final QuestionnaireType type;
  final List<QuestionnaireInstance> rowsForType;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;

  @override
  Widget build(BuildContext context) => _QuestionnaireCard(
    participantId: participantId,
    type: type,
    rowsForType: rowsForType,
    onSendNow: onSendNow,
    onStartNextCycle: onStartNextCycle,
    onCallBack: onCallBack,
  );
}
