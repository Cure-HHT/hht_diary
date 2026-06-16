// The Manage Questionnaires modal (reactive). For a participant it shows one
// Questionnaire Card per enabled Questionnaire Type, each rendering the Type's
// current Status + paired Cycle info and exactly the action buttons the
// per-status matrix permits. Status is derived live from the reactive
// `questionnaire_instance` view (gated portal.questionnaire.view_status), filtered
// client-side to the selected participant.
//
// The modal OWNS the three action flows (Send Now / Start Next Cycle / Call
// Back): the action buttons open the relevant sub-dialog and drive the
// HTTP/action dispatch internally using the modal's own context, rather than
// invoking injected callbacks. Send Now / Start Next Cycle POST the server's
// `/admin/questionnaire/send` orchestration endpoint with the
// `<identityCredential>|<activeRole>` Bearer (mirrors AuditLogScreen); Call Back
// dispatches the ACT-QST-002 EVS action through the reaction scope (mirrors
// StartTrialDialog).
//
// Implements: DIARY-BASE-questionnaire-manage-modal/A+B+C+D+E
import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
// Explicit for @visibleForTesting (also re-exported transitively by
// material.dart, hence the ignore).
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:http/http.dart' as http;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'questionnaire_card_state.dart';
import 'questionnaire_instance.dart';
import 'questionnaire_types.dart';
import 'send_questionnaire_flow.dart';

const String _viewPerm = 'portal.questionnaire.view_status';
const String _kCallBackAction = 'ACT-QST-002'; // {siteId, instanceId, reason}
const String _kFinalizeAction =
    'ACT-QST-003'; // {siteId, instanceId, cycle?, endEvent?}

/// The two terminal-cycle close markers (assertions B/E). A normal cycle
/// finalize carries a `cycle` study-event string; a terminal close carries one
/// of these `endEvent` sentinels (and no `cycle`).
const String _kEndOfTreatment = 'end_of_treatment';
const String _kEndOfStudy = 'end_of_study';

/// Friendly label for a terminal `endEvent` sentinel, used both in the
/// Finalization dropdown options and the Closed combined badge (assertion E).
String _endEventLabel(String endEvent) => switch (endEvent) {
  _kEndOfTreatment => 'End of Treatment',
  _kEndOfStudy => 'End of Study',
  _ => endEvent,
};

/// The selectable starting-cycle range for the Select Starting Cycle dialog —
/// `Cycle 1`..`Cycle 12` (a const range; assertion I).
const int _kMaxStartingCycle = 12;

/// Reactive Manage Questionnaires modal for a single participant.
///
/// Subscribes to the `questionnaire_instance` view, filters to [participantId],
/// groups by type, and renders one [_QuestionnaireCard] per enabled type with
/// the resolved [QuestionnaireCardState]. The three action flows are owned by
/// the modal (Send / Start Next Cycle POST the server; Call Back dispatches
/// ACT-QST-002); the active role is read from the connected principal.
class ManageQuestionnairesDialog extends StatelessWidget {
  const ManageQuestionnairesDialog({
    super.key,
    required this.participantId,
    required this.siteId,
    required this.serverUrl,
    required this.identityCredential,
    this.httpClient,
  });

  final String participantId;
  final String siteId;

  /// The portal server base URL (same origin as every other screen).
  final String serverUrl;

  /// The bare identity credential — session token in session mode, userId in
  /// dev mode. The active-role claim is appended at send time to form the
  /// `<identityCredential>|<activeRole>` Bearer.
  final String identityCredential;

  /// Injectable HTTP client seam for unit-testing the send flow with a mock;
  /// defaults to a fresh [http.Client] (mirrors login_screen.dart).
  final http.Client? httpClient;

  /// Shows the dialog. Resolves when it is dismissed.
  static Future<void> show({
    required BuildContext context,
    required String participantId,
    required String siteId,
    required String serverUrl,
    required String identityCredential,
    http.Client? httpClient,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ManageQuestionnairesDialog(
      participantId: participantId,
      siteId: siteId,
      serverUrl: serverUrl,
      identityCredential: identityCredential,
      httpClient: httpClient,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Assertion A: the modal header shows the participant identifier.
    // Assertion C: the kit dialog's close (X) dismisses with no change.
    return AppDialog(
      size: AppDialogSize.medium,
      title: 'Manage Questionnaires',
      subtitle: 'Participant ID: $participantId',
      semanticId: 'qst-modal-$participantId',
      body: SizedBox(
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
                      siteId: siteId,
                      type: type,
                      rowsForType:
                          byType[type.id] ?? const <QuestionnaireInstance>[],
                      onSendNow: (typeId) => _runSend(
                        context,
                        questionnaireType: typeId,
                        startNextCycle: false,
                      ),
                      onStartNextCycle: (typeId) => _runSend(
                        context,
                        questionnaireType: typeId,
                        startNextCycle: true,
                      ),
                      onCallBack: (current) =>
                          _runCallBack(context, current: current),
                      onFinalize: (current) =>
                          _runFinalize(context, current: current),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The active role from the connected principal (mirrors AuditLogScreen).
  String _activeRole(BuildContext context) {
    final status = ReActionScope.of(context).authSession.current;
    if (status is Authenticated && status.principal is UserPrincipal) {
      return (status.principal as UserPrincipal).activeRole;
    }
    return '';
  }

  /// The `<identityCredential>|<activeRole>` Bearer for the send POST.
  String _bearer(BuildContext context) =>
      '$identityCredential|${_activeRole(context)}';

  /// Send Now / Start Next Cycle flow. Both POST `/admin/questionnaire/send`
  /// with `{siteId, participantId, questionnaireType}` and NO studyEvent;
  /// [startNextCycle] only changes the confirm copy (the server auto-increments
  /// the cycle). Send Now additionally handles the 422 first-send case by
  /// opening the Select Starting Cycle dialog (assertion M: Start Next Cycle has
  /// NO cycle picker — its cycle is auto).
  ///
  /// Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
  /// Implements: DIARY-BASE-questionnaire-manage-modal/I+J+K+L+M
  Future<void> _runSend(
    BuildContext context, {
    required String questionnaireType,
    required bool startNextCycle,
  }) async {
    // A client minted here (no injection) is ours to close when the send
    // flow ends — early returns included — or its sockets linger.
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final bearer = _bearer(context);

      // Start Next Cycle shows a brief confirm first (no cycle picker,
      // assertion M); Send Now goes straight to the POST.
      if (startNextCycle) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              _ConfirmNextCycleDialog(participantId: participantId),
        );
        if (ok != true) return; // cancelled — no change
        if (!context.mounted) return;
      }

      final outcome =
          await postSend(client, serverUrl, bearer, <String, Object?>{
            'siteId': siteId,
            'participantId': participantId,
            'questionnaireType': questionnaireType,
          });
      if (!context.mounted) return;

      switch (outcome) {
        case SendSent():
          // The card flips to Sent reactively via the view; a brief
          // confirmation.
          _snack(context, 'Questionnaire sent.');
        case SendNeedsCycleSelection():
          // First send of this type: pick the starting cycle, then re-POST
          // with an explicit `studyEvent: 'Cycle <N> Day 1'` (assertions
          // I/J/K/L).
          await _selectStartingCycleAndSend(
            context,
            client: client,
            bearer: bearer,
            questionnaireType: questionnaireType,
          );
        case SendBlocked(:final reason):
          _showError(context, reason);
        case SendError(:final message):
          _showError(context, message);
      }
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Opens the Select Starting Cycle dialog and, on Confirm, re-POSTs with the
  /// chosen `studyEvent`. Cancel => no change (assertion L).
  ///
  /// Implements: DIARY-BASE-questionnaire-manage-modal/I+J+K+L
  Future<void> _selectStartingCycleAndSend(
    BuildContext context, {
    required http.Client client,
    required String bearer,
    required String questionnaireType,
  }) async {
    final cycle = await showDialog<int>(
      context: context,
      builder: (ctx) =>
          _SelectStartingCycleDialog(participantId: participantId),
    );
    if (cycle == null) return; // Cancel — no change (assertion L)
    if (!context.mounted) return;

    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': siteId,
      'participantId': participantId,
      'questionnaireType': questionnaireType,
      'studyEvent': 'Cycle $cycle Day 1',
    });
    if (!context.mounted) return;
    switch (outcome) {
      case SendSent():
        _snack(context, 'Questionnaire sent.');
      case SendNeedsCycleSelection():
        // Should not recur once a studyEvent is supplied; surface defensively.
        _showError(context, 'A starting cycle is required.');
      case SendBlocked(:final reason):
        _showError(context, reason);
      case SendError(:final message):
        _showError(context, message);
    }
  }

  /// Call Back flow: open the reason dialog; on Confirm with a non-empty reason
  /// dispatch ACT-QST-002 for the open [current] instance. On success the row
  /// tombstones and the card returns to Not Sent reactively (assertion G).
  ///
  /// Implements: DIARY-BASE-questionnaire-coordinator-workflow/D+E
  /// Implements: DIARY-BASE-questionnaire-manage-modal/F+G+H
  Future<void> _runCallBack(
    BuildContext context, {
    required QuestionnaireInstance current,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CallBackDialog(
      participantId: participantId,
      siteId: siteId,
      instanceId: current.instanceId,
    ),
  );

  /// Finalize flow: open the Finalization Dialog for the open [current]
  /// instance. The dialog owns the Cycle dropdown, the nested Terminal Cycle
  /// Warning, and the ACT-QST-003 dispatch; on success the card flips reactively
  /// (Closed for a terminal close, Not-Sent/Start-Next for a cycle finalize).
  ///
  /// Implements: DIARY-BASE-questionnaire-finalization/A+B+C+D+E+F+G
  Future<void> _runFinalize(
    BuildContext context, {
    required QuestionnaireInstance current,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FinalizationDialog(
      participantId: participantId,
      siteId: siteId,
      instanceId: current.instanceId,
      currentStudyEvent: current.studyEvent,
    ),
  );

  void _snack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not send'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
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
    required this.siteId,
    required this.type,
    required this.rowsForType,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
    required this.onFinalize,
  });

  final String participantId;
  final String siteId;
  final QuestionnaireType type;
  final List<QuestionnaireInstance> rowsForType;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;
  final void Function(QuestionnaireInstance current) onFinalize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = resolveCardState(rowsForType);
    // The ready-to-review card carries the Figma's soft warm tint so the
    // reviewable questionnaire reads at a glance.
    final ready = state.status == QuestionnaireInstanceStatus.readyToReview;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFFFFBEB) : theme.colorScheme.surface,
        border: Border.all(
          color: ready
              ? const Color(0xFFFDE68A)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Leading questionnaire icon chip (Figma).
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 22,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  type.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Cycle info paired inline with the status chip it
                // describes (assertion D).
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _CycleInfo(state: state),
                    _StatusBadge(state: state),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action cluster, top-right (Figma): the per-status buttons,
          // with Call Back as the trash affordance.
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final action in state.actions)
                _ActionButton(
                  participantId: participantId,
                  siteId: siteId,
                  typeId: type.id,
                  action: action,
                  state: state,
                  onSendNow: onSendNow,
                  onStartNextCycle: onStartNextCycle,
                  onCallBack: onCallBack,
                  onFinalize: onFinalize,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The status chip for a card. For a genuine terminal Closed the matrix calls
/// for a combined "Closed · End of Treatment/Study" badge: when the resolved
/// state is Closed and carries a terminal `endEvent`, the badge text becomes
/// "Closed · [friendly endEvent]" (assertion E); otherwise it shows the plain
/// status label.
///
/// Implements: DIARY-BASE-questionnaire-finalization/E
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final QuestionnaireCardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endEvent = state.endEvent;
    final label =
        state.status == QuestionnaireInstanceStatus.closed && endEvent != null
        ? 'Closed · ${_endEventLabel(endEvent)}'
        : state.status.label;
    // Per-status pill tints (Figma): Sent soft blue, Ready to Review warm
    // outline, Not Sent / Closed neutral.
    final (Color bg, Color fg, Color border) = switch (state.status) {
      QuestionnaireInstanceStatus.sent => (
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
        const Color(0xFFBFDBFE),
      ),
      QuestionnaireInstanceStatus.readyToReview => (
        const Color(0xFFFFFBEB),
        const Color(0xFFD97706),
        const Color(0xFFFBBF24),
      ),
      QuestionnaireInstanceStatus.closed => (
        const Color(0xFF0E7490),
        Colors.white,
        const Color(0xFF0E7490),
      ),
      _ => (
        theme.colorScheme.surface,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: fg,
        ),
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

    // Current cycle (Sent / Ready to Review) — Figma: "Current: Cycle N Day 1".
    if (state.currentStudyEvent != null) {
      return Text.rich(
        TextSpan(
          text: 'Current: ',
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

/// One action button. Send Now / Start Next Cycle / Call Back / Finalize invoke
/// the modal's flow handlers. Each interactive button carries a stable Semantics
/// identifier for Playwright.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.participantId,
    required this.siteId,
    required this.typeId,
    required this.action,
    required this.state,
    required this.onSendNow,
    required this.onStartNextCycle,
    required this.onCallBack,
    required this.onFinalize,
  });

  final String participantId;
  final String siteId;
  final String typeId;
  final QuestionnaireCardAction action;
  final QuestionnaireCardState state;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;
  final void Function(QuestionnaireInstance current) onFinalize;

  @override
  Widget build(BuildContext context) {
    // The Delivery-Failed troubleshooting popover (assertions N/O) is deferred.
    // TODO(later): wire the Delivery-Failed troubleshooting popover (info icon).
    final VoidCallback? onPressed;
    switch (action) {
      case QuestionnaireCardAction.sendNow:
        onPressed = () => onSendNow(typeId);
      case QuestionnaireCardAction.startNextCycle:
        onPressed = () => onStartNextCycle(typeId);
      case QuestionnaireCardAction.callBack:
        // Call Back targets the current open instance. resolveCardState only
        // offers callBack when an open instance exists, but if the open
        // instance can't be resolved the button renders DISABLED (null) rather
        // than as an enabled no-op.
        final current = _currentInstance();
        onPressed = current == null ? null : () => onCallBack(current);
      case QuestionnaireCardAction.finalize:
        // Finalize targets the current open instance (Ready to Review / Delivery
        // Failed). Disabled if the open instance can't be resolved.
        // Implements: DIARY-BASE-questionnaire-finalization/A
        final current = _currentInstance();
        onPressed = current == null ? null : () => onFinalize(current);
    }

    // Stable identifier for Playwright e2e (mirrors the send-eq-confirm-...
    // pattern); container + explicitChildNodes keep it from being merged away
    // by the button's own button semantics.
    //
    // Call Back renders as the Figma's trash affordance (tooltip carries the
    // action name); Finalize as the green check button; Send Now / Start Next
    // Cycle as kit primary buttons.
    final Widget button = switch (action) {
      QuestionnaireCardAction.callBack => IconButton(
        onPressed: onPressed,
        tooltip: action.label,
        icon: const Icon(
          Icons.delete_outline,
          size: 20,
          color: Color(0xFFDC2626),
        ),
        visualDensity: VisualDensity.compact,
      ),
      QuestionnaireCardAction.finalize => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: Text(action.label),
      ),
      _ => AppButton(
        label: action.label,
        leadingIcon: Icons.send_outlined,
        onPressed: onPressed,
      ),
    };
    return Semantics(
      identifier: 'qst-${action.name}-$typeId-$participantId',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: button,
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

/// The Select Starting Cycle dialog (assertions I/J/K/L). A `Cycle 1`..`Cycle
/// 12` dropdown (assertion I) plus "Confirm and Send" (pops the chosen cycle —
/// assertions J/K) and "Cancel" (pops null — assertion L).
///
/// Implements: DIARY-BASE-questionnaire-manage-modal/I+J+K+L
class _SelectStartingCycleDialog extends StatefulWidget {
  const _SelectStartingCycleDialog({required this.participantId});

  final String participantId;

  @override
  State<_SelectStartingCycleDialog> createState() =>
      _SelectStartingCycleDialogState();
}

class _SelectStartingCycleDialogState
    extends State<_SelectStartingCycleDialog> {
  int _cycle = 1;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Select Starting Cycle',
      subtitle:
          'Choose which cycle this questionnaire belongs to for participant '
          '${widget.participantId}.',
      dismissible: false,
      semanticId: 'qst-cycle-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppBanner(
            severity: AppBannerSeverity.info,
            message:
                "Select Cycle 1 Day 1 if this is the participant's first "
                'cycle, or a later cycle if the participant started on '
                'paper diaries.',
          ),
          const SizedBox(height: 16),
          // Assertion I: a cycle dropdown over the const Cycle 1..12 range.
          DropdownButtonFormField<int>(
            initialValue: _cycle,
            decoration: const InputDecoration(labelText: 'Starting Cycle'),
            items: <DropdownMenuItem<int>>[
              for (var n = 1; n <= _kMaxStartingCycle; n++)
                DropdownMenuItem<int>(value: n, child: Text('Cycle $n Day 1')),
            ],
            onChanged: (v) => setState(() => _cycle = v ?? _cycle),
          ),
        ],
      ),
      actions: <Widget>[
        // Assertion L: Cancel pops null -> no change.
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Assertions J/K: Confirm pops the chosen cycle -> re-POST with
        // studyEvent.
        AppButton(
          label: 'Confirm and Send',
          onPressed: () => Navigator.of(context).pop(_cycle),
          semanticId: 'qst-cycle-confirm-${widget.participantId}',
        ),
      ],
    );
  }
}

/// The Start-Next-Cycle confirm dialog (assertion M): a brief confirm with NO
/// cycle picker — the cycle is auto-incremented server-side. Pops `true` on
/// Start, `false`/null on Cancel.
///
/// Implements: DIARY-BASE-questionnaire-manage-modal/M
class _ConfirmNextCycleDialog extends StatelessWidget {
  const _ConfirmNextCycleDialog({required this.participantId});

  final String participantId;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Start Next Cycle',
      dismissible: false,
      body: Text(
        'Send the next cycle of this questionnaire to participant '
        '$participantId? The cycle is determined automatically.',
      ),
      actions: <Widget>[
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Start Next Cycle',
          onPressed: () => Navigator.of(context).pop(true),
          semanticId: 'qst-nextcycle-confirm-$participantId',
        ),
      ],
    );
  }
}

/// The Call Back reason dialog. A required free-text reason (assertion F);
/// Cancel => no change (assertion H); Confirm with a non-empty reason dispatches
/// ACT-QST-002 through the reaction scope, which tombstones the instance row so
/// the card returns to Not Sent reactively (assertion G). The dispatch is driven
/// by an [ActionBuilder] whose `submissionFactory` closes over the entered
/// reason (collect-then-dispatch, since the reason is dynamic).
///
/// Implements: DIARY-BASE-questionnaire-coordinator-workflow/D+E
/// Implements: DIARY-BASE-questionnaire-manage-modal/F+G+H
class _CallBackDialog extends StatefulWidget {
  const _CallBackDialog({
    required this.participantId,
    required this.siteId,
    required this.instanceId,
  });

  final String participantId;
  final String siteId;
  final String instanceId;

  @override
  State<_CallBackDialog> createState() => _CallBackDialogState();
}

class _CallBackDialogState extends State<_CallBackDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      semanticIdentifier: 'qst-callback-outcome-${widget.participantId}',
      // The reason is captured at submit time: the factory reads the live
      // controller text, so the latest reason rides the dispatch.
      submissionFactory: () => ActionSubmission(
        actionName: _kCallBackAction,
        rawInput: <String, Object?>{
          'siteId': widget.siteId,
          'instanceId': widget.instanceId,
          'reason': _reason.text.trim(),
        },
      ),
      builder: (context, state, submit) {
        final theme = Theme.of(context);
        return switch (state) {
          Submitting() => _busy(theme),
          // On success the row tombstones -> the card returns to Not Sent
          // reactively (assertion G). Close the dialog.
          Success() => _AutoCloseOnSuccess(participantId: widget.participantId),
          Denied() || Failed() => _form(context, theme, submit, state),
          _ => _form(context, theme, submit, null), // Idle
        };
      },
    );
  }

  Widget _form(
    BuildContext context,
    ThemeData theme,
    void Function() submit,
    ActionState? errorState,
  ) {
    final reasonEmpty = _reason.text.trim().isEmpty;
    final message = switch (errorState) {
      Denied(:final result) => 'The call back was not permitted ($result).',
      Failed(:final error) => 'Call back failed: $error',
      _ => null,
    };
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Call Back Questionnaire',
      dismissible: false,
      semanticId: 'qst-callback-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Retract this questionnaire from participant '
            '${widget.participantId}. A reason is required.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Assertion F: a required free-text reason.
          TextField(
            controller: _reason,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 12),
            AppBanner(severity: AppBannerSeverity.error, message: message),
          ],
        ],
      ),
      actions: <Widget>[
        // Assertion H: Cancel dismisses with no change.
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          variant: AppButtonVariant.destructive,
          label: 'Confirm',
          // Disabled until a non-empty reason is entered (assertion F).
          onPressed: reasonEmpty ? null : submit,
          semanticId: 'qst-callback-confirm-${widget.participantId}',
        ),
      ],
    );
  }

  Widget _busy(ThemeData theme) => const AppDialog(
    size: AppDialogSize.small,
    title: 'Calling back…',
    dismissible: false,
    body: SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

/// Pops a dispatch dialog once the action succeeds. Rendered transiently in the
/// [ActionBuilder] Success branch so the modal returns to the card list (which
/// has already flipped reactively). Shared by Call Back and Finalize; the
/// [semanticSuffix] and [message] distinguish the two surfaces.
class _AutoCloseOnSuccess extends StatefulWidget {
  const _AutoCloseOnSuccess({
    required this.participantId,
    this.semanticSuffix = 'callback',
    this.message = 'Questionnaire called back.',
  });

  final String participantId;
  final String semanticSuffix;
  final String message;

  @override
  State<_AutoCloseOnSuccess> createState() => _AutoCloseOnSuccessState();
}

class _AutoCloseOnSuccessState extends State<_AutoCloseOnSuccess> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'qst-${widget.semanticSuffix}-success-${widget.participantId}',
    child: AlertDialog(
      content: SizedBox(
        width: 280,
        height: 60,
        child: Center(child: Text(widget.message)),
      ),
    ),
  );
}

/// The selected option in the Finalization Dialog's Cycle dropdown: either the
/// current cycle's study-event string, or a terminal close marker.
sealed class _FinalizeChoice {
  const _FinalizeChoice();
}

/// A normal cycle finalize — carries the chosen study-event string (e.g.
/// `'Cycle 2 Day 1'`).
class _CycleChoice extends _FinalizeChoice {
  const _CycleChoice(this.studyEvent);
  final String studyEvent;
}

/// A terminal close — carries an `endEvent` sentinel (`end_of_treatment` /
/// `end_of_study`).
class _TerminalChoice extends _FinalizeChoice {
  const _TerminalChoice(this.endEvent);
  final String endEvent;
}

/// The Finalization Dialog (assertions A/B/C/F). A Cycle dropdown over the
/// current cycle + the two terminal options, a Finalize Questionnaire button,
/// and a Cancel.
///
///  * Cycle option + Finalize -> dispatch ACT-QST-003 `{cycle}` directly (D).
///  * Terminal option + Finalize -> open the nested Terminal Cycle Warning; on
///    its confirm -> dispatch ACT-QST-003 `{endEvent}` (E); on its cancel ->
///    return to this dialog unchanged (G).
///  * Cancel -> pop with no dispatch (F).
///
/// The dispatch is driven by an [ActionBuilder] whose `submissionFactory` closes
/// over the chosen cycle/endEvent (resolved when Finalize is pressed); on
/// Success the dialog auto-closes and the card flips reactively.
///
/// Implements: DIARY-BASE-questionnaire-finalization/A+B+C+D+E+F+G
class _FinalizationDialog extends StatefulWidget {
  const _FinalizationDialog({
    required this.participantId,
    required this.siteId,
    required this.instanceId,
    required this.currentStudyEvent,
  });

  final String participantId;
  final String siteId;
  final String instanceId;

  /// The open instance's study event (Current Cycle), used as the first
  /// dropdown option's label/value. Null when cycle tracking is off / no cycle
  /// is recorded — the dropdown then offers only the two terminal options.
  final String? currentStudyEvent;

  @override
  State<_FinalizationDialog> createState() => _FinalizationDialogState();
}

class _FinalizationDialogState extends State<_FinalizationDialog> {
  /// The chosen dropdown option, resolved once Finalize is pressed (Idle path)
  /// or carried into the dispatch (Submitting/Success). Initialised in
  /// [initState] to the current cycle when present, else End of Treatment.
  late _FinalizeChoice _choice;

  @override
  void initState() {
    super.initState();
    final cycle = widget.currentStudyEvent;
    _choice = cycle != null
        ? _CycleChoice(cycle)
        : const _TerminalChoice(_kEndOfTreatment);
  }

  /// The dropdown value key for the current selection (the study-event string
  /// for a cycle choice, or the endEvent sentinel for a terminal choice).
  String get _selectedKey => switch (_choice) {
    _CycleChoice(:final studyEvent) => studyEvent,
    _TerminalChoice(:final endEvent) => endEvent,
  };

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      // Surfaces the action outcome state on the semantics tree for Playwright.
      semanticIdentifier: 'qst-finalize-outcome-${widget.participantId}',
      // The chosen cycle/endEvent rides the dispatch: the factory reads the
      // resolved [_choice] at submit time.
      submissionFactory: () => ActionSubmission(
        actionName: _kFinalizeAction,
        rawInput: switch (_choice) {
          _CycleChoice(:final studyEvent) => <String, Object?>{
            'siteId': widget.siteId,
            'instanceId': widget.instanceId,
            'cycle': studyEvent,
          },
          _TerminalChoice(:final endEvent) => <String, Object?>{
            'siteId': widget.siteId,
            'instanceId': widget.instanceId,
            'endEvent': endEvent,
          },
        },
      ),
      builder: (context, state, submit) {
        final theme = Theme.of(context);
        return switch (state) {
          Submitting() => _busy(theme),
          // On success the row folds to finalized -> the card flips reactively
          // (Closed for terminal, Not-Sent/Start-Next for a cycle). Close.
          Success() => _AutoCloseOnSuccess(
            participantId: widget.participantId,
            semanticSuffix: 'finalize',
            message: 'Questionnaire finalized.',
          ),
          Denied() || Failed() => _form(context, theme, submit, state),
          _ => _form(context, theme, submit, null), // Idle
        };
      },
    );
  }

  /// Builds the dropdown items: the current cycle (when present) plus the two
  /// terminal options (assertion B).
  List<DropdownMenuItem<String>> _items() => <DropdownMenuItem<String>>[
    if (widget.currentStudyEvent != null)
      DropdownMenuItem<String>(
        value: widget.currentStudyEvent,
        child: Text(widget.currentStudyEvent!),
      ),
    const DropdownMenuItem<String>(
      value: _kEndOfTreatment,
      child: Text('End of Treatment'),
    ),
    const DropdownMenuItem<String>(
      value: _kEndOfStudy,
      child: Text('End of Study'),
    ),
  ];

  /// Maps a dropdown value key back to a [_FinalizeChoice].
  _FinalizeChoice _choiceFor(String key) =>
      (key == _kEndOfTreatment || key == _kEndOfStudy)
      ? _TerminalChoice(key)
      : _CycleChoice(key);

  /// Finalize pressed. A cycle choice dispatches directly; a terminal choice
  /// opens the nested Terminal Cycle Warning first (assertion E/G).
  Future<void> _onFinalize(void Function() submit) async {
    final choice = _choice;
    if (choice is _TerminalChoice) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TerminalCycleWarningDialog(
          participantId: widget.participantId,
          endEvent: choice.endEvent,
        ),
      );
      // Cancel -> return to this dialog unchanged, no dispatch (assertion G).
      if (confirmed != true) return;
      if (!mounted) return;
    }
    submit();
  }

  Widget _form(
    BuildContext context,
    ThemeData theme,
    void Function() submit,
    ActionState? errorState,
  ) {
    final message = switch (errorState) {
      Denied(:final result) => 'The finalization was not permitted ($result).',
      Failed(:final error) => 'Finalize failed: $error',
      _ => null,
    };
    final selectionLabel = switch (_choice) {
      _CycleChoice(:final studyEvent) => studyEvent,
      _TerminalChoice(:final endEvent) => _endEventLabel(endEvent),
    };
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Finalize Questionnaire?',
      subtitle: 'Participant ID: ${widget.participantId}',
      dismissible: false,
      semanticId: 'qst-finalize-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Are you sure you want to finalize this Questionnaire?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // Assertions A/B: a Cycle dropdown over the current cycle + the two
          // terminal options.
          DropdownButtonFormField<String>(
            initialValue: _selectedKey,
            decoration: const InputDecoration(labelText: 'Cycle'),
            items: _items(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _choice = _choiceFor(v));
            },
          ),
          const SizedBox(height: 12),
          AppBanner(
            severity: AppBannerSeverity.info,
            message:
                'This questionnaire will be finalized as: '
                '$selectionLabel',
          ),
          const SizedBox(height: 16),
          Text(
            'Effects of this action:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Finalize this Questionnaire\n'
            'Calculate the score and send it to EDC\n'
            'Lock all Participant responses permanently',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After finalization, the Participant cannot edit or update '
            'their answers in the Daily Diary app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 12),
            AppBanner(severity: AppBannerSeverity.error, message: message),
          ],
        ],
      ),
      actions: <Widget>[
        // Assertion F: Cancel dismisses with no change.
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Assertion C: the Finalize Questionnaire button (Figma: green).
        Semantics(
          identifier: 'qst-finalize-confirm-${widget.participantId}',
          button: true,
          container: true,
          explicitChildNodes: true,
          child: FilledButton(
            onPressed: () => _onFinalize(submit),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }

  Widget _busy(ThemeData theme) => const AppDialog(
    size: AppDialogSize.small,
    title: 'Finalizing…',
    dismissible: false,
    body: SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

/// The Terminal Cycle Warning Dialog (assertions E/G). Warns that the
/// questionnaire type will be PERMANENTLY closed for the participant. Pops
/// `true` on confirm (proceed to dispatch), `false`/null on Cancel (return to
/// the Finalization Dialog unchanged).
///
/// Implements: DIARY-BASE-questionnaire-finalization/E+G
class _TerminalCycleWarningDialog extends StatelessWidget {
  const _TerminalCycleWarningDialog({
    required this.participantId,
    required this.endEvent,
  });

  final String participantId;
  final String endEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _endEventLabel(endEvent);
    return AppDialog(
      size: AppDialogSize.medium,
      icon: Icon(Icons.warning_amber, color: theme.colorScheme.error),
      title: 'Permanently Close Questionnaire?',
      dismissible: false,
      body: Text(
        'Finalizing as "$label" will permanently close this questionnaire for '
        'participant $participantId. No further cycles of this questionnaire '
        'can be sent. This cannot be undone.',
      ),
      actions: <Widget>[
        // Assertion G: Cancel pops false -> return to the Finalization Dialog
        // unchanged.
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          variant: AppButtonVariant.destructive,
          label: 'Close as $label',
          onPressed: () => Navigator.of(context).pop(true),
          semanticId: 'qst-terminal-warning-confirm-$participantId',
        ),
      ],
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
    required this.onFinalize,
    this.siteId = 'S-1',
  });

  final String participantId;
  final String siteId;
  final QuestionnaireType type;
  final List<QuestionnaireInstance> rowsForType;
  final void Function(String questionnaireType) onSendNow;
  final void Function(String questionnaireType) onStartNextCycle;
  final void Function(QuestionnaireInstance current) onCallBack;
  final void Function(QuestionnaireInstance current) onFinalize;

  @override
  Widget build(BuildContext context) => _QuestionnaireCard(
    participantId: participantId,
    siteId: siteId,
    type: type,
    rowsForType: rowsForType,
    onSendNow: onSendNow,
    onStartNextCycle: onStartNextCycle,
    onCallBack: onCallBack,
    onFinalize: onFinalize,
  );
}

/// Test-only harness: the Finalization Dialog, mountable directly over a
/// FakeReaction scope so the dropdown + terminal-warning + ACT-QST-003 dispatch
/// behavior can be verified without the live ViewBuilder.
@visibleForTesting
class FinalizationDialogHarness extends StatelessWidget {
  const FinalizationDialogHarness({
    super.key,
    required this.participantId,
    required this.siteId,
    required this.instanceId,
    this.currentStudyEvent,
  });

  final String participantId;
  final String siteId;
  final String instanceId;
  final String? currentStudyEvent;

  @override
  Widget build(BuildContext context) => _FinalizationDialog(
    participantId: participantId,
    siteId: siteId,
    instanceId: instanceId,
    currentStudyEvent: currentStudyEvent,
  );
}

/// Test-only harness: the Call Back reason dialog, mountable directly over a
/// FakeReaction scope so the reason-required + dispatch behavior can be verified
/// without the live ViewBuilder.
@visibleForTesting
class CallBackDialogHarness extends StatelessWidget {
  const CallBackDialogHarness({
    super.key,
    required this.participantId,
    required this.siteId,
    required this.instanceId,
  });

  final String participantId;
  final String siteId;
  final String instanceId;

  @override
  Widget build(BuildContext context) => _CallBackDialog(
    participantId: participantId,
    siteId: siteId,
    instanceId: instanceId,
  );
}
