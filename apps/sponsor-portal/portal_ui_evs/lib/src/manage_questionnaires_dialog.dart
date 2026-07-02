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
import 'package:flutter_svg/flutter_svg.dart';
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

/// Friendly label for a terminal `endEvent` sentinel, used in the Finalization
/// dropdown options and the Terminal Cycle Warning title (Figma: title-case
/// "End of Treatment" / "End of Study").
String _endEventLabel(String endEvent) => switch (endEvent) {
  _kEndOfTreatment => 'End of Treatment',
  _kEndOfStudy => 'End of Study',
  _ => endEvent,
};

/// Sentence-case variant of [_endEventLabel] for the Closed combined badge
/// (Figma: "Closed · End of treatment" — note the lower-case noun, assertion E).
String _endEventLabelSentence(String endEvent) => switch (endEvent) {
  _kEndOfTreatment => 'End of treatment',
  _kEndOfStudy => 'End of study',
  _ => endEvent,
};

/// The short verb-phrase for the Terminal Cycle Warning's confirm button
/// (Figma: "End treatment" / "End study").
String _endEventVerb(String endEvent) => switch (endEvent) {
  _kEndOfTreatment => 'End treatment',
  _kEndOfStudy => 'End study',
  _ => endEvent,
};

/// Formats a finalization timestamp for the "Last:" line as e.g.
/// `'Oct 13, 2024, 5:00 PM'` (Figma "Last Completed" stamp). Rendered in local
/// time on a 12-hour clock — no `intl` dependency in this package, so the
/// format is hand-rolled (mirrors `usedOnLabel` in participants_screen_binding).
///
/// Implements: DIARY-BASE-questionnaire-finalization/D
String _formatFinalizedAt(DateTime t) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = t.toLocal();
  final period = local.hour < 12 ? 'AM' : 'PM';
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${months[local.month - 1]} ${local.day}, ${local.year}, '
      '$hour12:$minute $period';
}

/// Resolves a questionnaire type id (e.g. `'nose_hht'`) to its display name
/// (e.g. `'NOSE HHT'`) for the sub-dialog copy. Falls back to the id if the
/// type is not in the enabled list.
String _typeDisplayName(String typeId) {
  for (final t in kEnabledQuestionnaireTypes) {
    if (t.id == typeId) return t.displayName;
  }
  return typeId;
}

/// The selectable starting-cycle range for the Select Starting Cycle dialog —
/// `Cycle 1`..`Cycle 12` (a const range; assertion I).
const int _kMaxStartingCycle = 12;

/// A questionnaire-flow glyph exported from the Figma UI pack
/// (`assets/icons/questionnaire/<name>.svg`), tinted to [color]. The SVGs paint
/// with `currentColor`, so a `srcIn` colour filter recolours the stroke.
Widget _qGlyph(String name, Color color, {double? size}) => SvgPicture.asset(
  'assets/icons/questionnaire/$name.svg',
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

/// The info callout used in the Select Starting Cycle and Finalize dialogs
/// (Figma): a Primary-Light-Soft (#E8F3F7) panel, 6px radius, with the calendar
/// glyph and Primary (#165C7D) copy. [spans] carry the rich text (emphasise the
/// cycle with a `w600` span).
class _QInfoBanner extends StatelessWidget {
  const _QInfoBanner({required this.spans});

  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF165C7D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: <Widget>[
          _qGlyph('calendar', primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w400,
                  color: primary,
                ),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      // Figma: the whole modal is a soft grey panel (Primary Bg #F7FAFB) so
      // the white question cards read as distinct boxes.
      backgroundColor: const Color(0xFFF7FAFB),
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
                  const SizedBox(height: 8),
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
      builder: (ctx) => _SelectStartingCycleDialog(
        participantId: participantId,
        typeDisplayName: _typeDisplayName(questionnaireType),
      ),
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
      typeDisplayName: _typeDisplayName(current.type),
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
      typeDisplayName: _typeDisplayName(current.type),
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
    // Figma: every card is a white bordered panel with the same 12px radius
    // sitting on the dialog's soft grey body; status tint lives only in the
    // pill, not the card background. The card colour is an explicit white (not
    // colorScheme.surface) so it stays distinct from the grey panel.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        // Figma: a hairline Light-Gray (#ECEEF0) stroke, not a heavy border.
        border: Border.all(color: const Color(0xFFECEEF0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: _content(context, theme, state),
    );
  }

  /// Never-sent cards are a single row (title + "Not Sent" pill + Send);
  /// every other status is a header row over a hairline divider over a body
  /// row carrying the cycle line and its status pill (Figma).
  Widget _content(
    BuildContext context,
    ThemeData theme,
    QuestionnaireCardState state,
  ) {
    // Figma: Inter Semi Bold 18 / line-height 28, Black (#04161E).
    final title = Text(
      type.displayName,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF04161E),
      ),
    );

    // Never sent: one row — title, inline "Not Sent" pill, Send button.
    final neverSent =
        state.status == QuestionnaireInstanceStatus.notSent &&
        state.finalizedStudyEvent == null;
    if (neverSent) {
      return Row(
        children: <Widget>[
          title,
          const SizedBox(width: 12),
          _StatusBadge(state: state),
          const Spacer(),
          for (final action in state.actions) _actionButton(action, state),
        ],
      );
    }

    // Closed terminal carries the combined "Closed · …" pill inline in the
    // header (Figma); the other states keep their pill in the body row.
    final isClosed = state.status == QuestionnaireInstanceStatus.closed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            title,
            if (isClosed) ...<Widget>[
              const SizedBox(width: 12),
              _StatusBadge(state: state),
            ],
            const Spacer(),
            for (final action in state.actions) ...<Widget>[
              _actionButton(action, state),
              const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        _body(theme, state, isClosed),
      ],
    );
  }

  /// The body under the divider: the cycle line (and its status pill for
  /// non-terminal states; a no-further-sends note for a terminal Closed).
  Widget _body(ThemeData theme, QuestionnaireCardState state, bool isClosed) {
    // Figma: label Inter Regular 14 / cycle Inter Semi Bold 14, both Dark Grey
    // (#54636A) — the cycle is weighted, not recoloured.
    final muted = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: const Color(0xFF54636A),
    );
    final emph = muted?.copyWith(fontWeight: FontWeight.w600);

    // The formatted finalization stamp for the "Last:" line, when the row
    // carries one (after-finalize / Closed only).
    // Implements: DIARY-BASE-questionnaire-finalization/D
    final finalizedLabel = state.finalizedAt == null
        ? null
        : _formatFinalizedAt(state.finalizedAt!);

    if (isClosed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (state.finalizedStudyEvent != null)
            Text.rich(
              TextSpan(
                text: 'Last: ',
                style: muted,
                children: <InlineSpan>[
                  TextSpan(text: state.finalizedStudyEvent, style: emph),
                  // Implements: DIARY-BASE-questionnaire-finalization/D — the finalization date/time.
                  if (finalizedLabel != null)
                    TextSpan(text: '  •  $finalizedLabel', style: muted),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'No further questionnaires of this type can be sent.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Sent / Ready to Review -> a single "Current: <cycle>" row with the pill.
    final isCurrent = state.currentStudyEvent != null;
    if (isCurrent) {
      return Row(
        children: <Widget>[
          Flexible(
            child: Text.rich(
              TextSpan(
                text: 'Current: ',
                style: muted,
                children: <InlineSpan>[
                  TextSpan(text: state.currentStudyEvent, style: emph),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(state: state),
        ],
      );
    }

    // After-finalize: "Last: <cycle> • <finalized date>" over a
    // "Next: Cycle N+1 Day 1" line carrying the Not-Sent pill (Figma). The
    // pill renders exactly once — on the Next line when a next cycle is known,
    // else inline with Last.
    // Implements: DIARY-BASE-questionnaire-finalization/D
    final cycle = state.finalizedStudyEvent;
    final next = state.nextStudyEvent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (cycle != null)
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Last: ',
                    style: muted,
                    children: <InlineSpan>[
                      TextSpan(text: cycle, style: emph),
                      if (finalizedLabel != null)
                        TextSpan(text: '  •  $finalizedLabel', style: muted),
                    ],
                  ),
                ),
              ),
            if (next == null) ...<Widget>[
              const SizedBox(width: 8),
              _StatusBadge(state: state),
            ],
          ],
        ),
        if (next != null) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Next: ',
                    style: muted,
                    children: <InlineSpan>[TextSpan(text: next, style: emph)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(state: state),
            ],
          ),
        ],
      ],
    );
  }

  Widget _actionButton(
    QuestionnaireCardAction action,
    QuestionnaireCardState state,
  ) => _ActionButton(
    participantId: participantId,
    siteId: siteId,
    typeId: type.id,
    action: action,
    state: state,
    onSendNow: onSendNow,
    onStartNextCycle: onStartNextCycle,
    onCallBack: onCallBack,
    onFinalize: onFinalize,
  );
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
    final endEvent = state.endEvent;
    final label =
        state.status == QuestionnaireInstanceStatus.closed && endEvent != null
        ? 'Closed · ${_endEventLabelSentence(endEvent)}'
        : state.status.label;
    // Per-status pill colours, lifted exactly from the Figma badges:
    //  Sent           bg Primary Light Soft #E8F3F7 / fg Primary    #165C7D
    //  Ready to Review bg Pending Bg        #FFF5DE / fg Pending Dk  #B9790A
    //  Not Sent        bg Light Gray        #ECEEF0 / fg Dark Grey   #54636A
    //  Closed          bg Light Gray        #ECEEF0 / fg Grey        #A4B9C2
    final (Color bg, Color fg) = switch (state.status) {
      QuestionnaireInstanceStatus.sent => (
        const Color(0xFFE8F3F7),
        const Color(0xFF165C7D),
      ),
      QuestionnaireInstanceStatus.readyToReview => (
        const Color(0xFFFFF5DE),
        const Color(0xFFB9790A),
      ),
      QuestionnaireInstanceStatus.closed => (
        const Color(0xFFECEEF0),
        const Color(0xFFA4B9C2),
      ),
      _ => (const Color(0xFFECEEF0), const Color(0xFF54636A)),
    };
    return Container(
      // Figma: 8.5 / 2.5 px insets, 6px radius, no visible stroke.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      // Figma: Inter Medium 12 / line-height 16.
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 16 / 12,
        ).copyWith(color: fg),
      ),
    );
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
    final theme = Theme.of(context);
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
    // Call Back renders as the Figma's red trash affordance (tooltip carries
    // the action name); Send / Finalize / Start Next Cycle are kit primary
    // buttons with their Figma leading glyph.
    final Widget button = switch (action) {
      QuestionnaireCardAction.callBack => IconButton(
        onPressed: onPressed,
        tooltip: action.label,
        // Figma trash glyph, Critical red (#CB333B = colorScheme.error).
        icon: _qGlyph('call_back', theme.colorScheme.error, size: 16),
        visualDensity: VisualDensity.compact,
      ),
      QuestionnaireCardAction.finalize => AppButton(
        size: AppButtonSize.medium,
        label: 'Finalize',
        leadingWidget: _qGlyph('finalize', Colors.white),
        onPressed: onPressed,
      ),
      QuestionnaireCardAction.sendNow => AppButton(
        size: AppButtonSize.medium,
        label: 'Send',
        leadingWidget: _qGlyph('send', Colors.white),
        onPressed: onPressed,
      ),
      QuestionnaireCardAction.startNextCycle => AppButton(
        size: AppButtonSize.medium,
        label: 'Start Next Cycle',
        leadingWidget: _qGlyph('start_next_cycle', Colors.white),
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
  const _SelectStartingCycleDialog({
    required this.participantId,
    required this.typeDisplayName,
  });

  final String participantId;

  /// The questionnaire type's display name (e.g. `'NOSE HHT'`), woven into the
  /// dialog copy (Figma).
  final String typeDisplayName;

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
          'Choose which cycle this ${widget.typeDisplayName} questionnaire '
          'belongs to for participant ${widget.participantId}.',
      dismissible: false,
      semanticId: 'qst-cycle-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _QInfoBanner(
            spans: <InlineSpan>[
              TextSpan(text: 'Select '),
              TextSpan(
                text: 'Cycle 1 Day 1',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text:
                    " if this is the participant's first cycle, or a later "
                    'cycle if the participant started on paper diaries.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Assertion I: a cycle dropdown over the const Cycle 1..12 range.
          AppDropdown<int>(
            label: 'Starting Cycle',
            value: _cycle,
            items: <AppDropdownItem<int>>[
              for (var n = 1; n <= _kMaxStartingCycle; n++)
                AppDropdownItem<int>(value: n, label: 'Cycle $n Day 1'),
            ],
            onChanged: (v) => setState(() => _cycle = v ?? _cycle),
            semanticId: 'qst-cycle-select-${widget.participantId}',
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
          label: 'Confirm',
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
    required this.typeDisplayName,
  });

  final String participantId;
  final String siteId;
  final String instanceId;

  /// The questionnaire type's display name, woven into the dialog copy (Figma).
  final String typeDisplayName;

  @override
  State<_CallBackDialog> createState() => _CallBackDialogState();
}

/// The "← Manage Questionnaires" back-link rendered above a sub-dialog title
/// (Figma). Tapping it pops the sub-dialog, returning to the modal with no
/// change — the same no-op outcome as Cancel.
class _ManageQuestionnairesBreadcrumb extends StatelessWidget {
  const _ManageQuestionnairesBreadcrumb();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.arrow_back, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Manage Questionnaires',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
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
      breadcrumb: const _ManageQuestionnairesBreadcrumb(),
      title: 'Call Back Questionnaire',
      subtitle: 'Participant ID: ${widget.participantId}',
      dismissible: false,
      semanticId: 'qst-callback-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Calling back the ${widget.typeDisplayName} Questionnaire will set '
            'its status to Not Sent.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // Assertion F: a required free-text reason, capped at 100 chars with
          // the Figma "0/100" counter.
          AppTextField(
            controller: _reason,
            label: 'Reason for call back',
            required: true,
            hintText: 'Enter reason for calling back this Questionnaire...',
            autofocus: true,
            minLines: 3,
            maxLines: 4,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
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
    required this.typeDisplayName,
  });

  final String participantId;
  final String siteId;
  final String instanceId;

  /// The open instance's study event (Current Cycle), used as the first
  /// dropdown option's label/value. Null when cycle tracking is off / no cycle
  /// is recorded — the dropdown then offers only the two terminal options.
  final String? currentStudyEvent;

  /// The questionnaire type's display name, woven into the dialog copy (Figma).
  final String typeDisplayName;

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
  List<AppDropdownItem<String>> _items() => <AppDropdownItem<String>>[
    if (widget.currentStudyEvent != null)
      AppDropdownItem<String>(
        value: widget.currentStudyEvent!,
        label: widget.currentStudyEvent!,
      ),
    const AppDropdownItem<String>(
      value: _kEndOfTreatment,
      label: 'End of Treatment',
    ),
    const AppDropdownItem<String>(value: _kEndOfStudy, label: 'End of Study'),
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
          typeDisplayName: widget.typeDisplayName,
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AppDialog(
      size: AppDialogSize.small,
      breadcrumb: const _ManageQuestionnairesBreadcrumb(),
      title: 'Finalize Questionnaire',
      subtitle: 'Participant ID: ${widget.participantId}',
      dismissible: false,
      semanticId: 'qst-finalize-dialog-${widget.participantId}',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Are you sure you want to finalize the ${widget.typeDisplayName} '
            'Questionnaire?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // Assertions A/B: a Cycle dropdown over the current cycle + the two
          // terminal options.
          AppDropdown<String>(
            label: 'Starting Cycle',
            value: _selectedKey,
            items: _items(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _choice = _choiceFor(v));
            },
            semanticId: 'qst-finalize-cycle-${widget.participantId}',
          ),
          const SizedBox(height: 16),
          _QInfoBanner(
            spans: <InlineSpan>[
              const TextSpan(text: 'This questionnaire will be finalized as: '),
              TextSpan(
                text: selectionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Effects of this action:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _bullet(theme, muted, 'Finalize this Questionnaire'),
          _bullet(theme, muted, 'Calculate the score and send it to EDC'),
          _bullet(theme, muted, 'Lock all Participant responses permanently'),
          const SizedBox(height: 8),
          Text(
            'After finalization, the Participant cannot edit or update '
            'their answers in the Daily Diary app.',
            style: muted,
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
        // Assertion C: the Finalize confirm button (Figma: primary).
        AppButton(
          label: 'Confirm',
          onPressed: () => _onFinalize(submit),
          semanticId: 'qst-finalize-confirm-${widget.participantId}',
        ),
      ],
    );
  }

  /// One bulleted effect line in the Finalize dialog (Figma: "Effects of this
  /// action" list).
  Widget _bullet(ThemeData theme, TextStyle? style, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('•', style: style),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    ),
  );

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
    required this.typeDisplayName,
  });

  final String participantId;
  final String endEvent;

  /// The questionnaire type's display name, woven into the warning copy (Figma).
  final String typeDisplayName;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB9790A); // Pending Dark
    final regular = const TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: amber,
    );
    final bold = regular.copyWith(fontWeight: FontWeight.w600);
    return AppDialog(
      size: AppDialogSize.small,
      // Figma: the dialog is titled by the chosen terminal event itself.
      title: _endEventLabel(endEvent),
      dismissible: false,
      semanticId: 'qst-terminal-warning-$participantId',
      // Figma: a Pending-Bg (#FFF5DE) panel, 10px radius, carrying the
      // triangle-alert glyph and the warning copy in Pending Dark (#B9790A),
      // with the questionnaire type + patient id emphasised.
      body: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _qGlyph('triangle_alert', amber, size: 36),
            const SizedBox(width: 17),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: regular,
                  children: <InlineSpan>[
                    TextSpan(
                      text:
                          'This action will permanently close this '
                          'questionnaire type for this patient. ',
                      style: bold,
                    ),
                    const TextSpan(text: "You won't be able to send"),
                    TextSpan(text: ' $typeDisplayName', style: bold),
                    const TextSpan(text: ' questionnaires to patient '),
                    TextSpan(text: participantId, style: bold),
                    const TextSpan(text: '. Are you sure?'),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          label: _endEventVerb(endEvent),
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
    this.typeDisplayName = 'NOSE HHT',
  });

  final String participantId;
  final String siteId;
  final String instanceId;
  final String? currentStudyEvent;
  final String typeDisplayName;

  @override
  Widget build(BuildContext context) => _FinalizationDialog(
    participantId: participantId,
    siteId: siteId,
    instanceId: instanceId,
    currentStudyEvent: currentStudyEvent,
    typeDisplayName: typeDisplayName,
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
    this.typeDisplayName = 'NOSE HHT',
  });

  final String participantId;
  final String siteId;
  final String instanceId;
  final String typeDisplayName;

  @override
  Widget build(BuildContext context) => _CallBackDialog(
    participantId: participantId,
    siteId: siteId,
    instanceId: instanceId,
    typeDisplayName: typeDisplayName,
  );
}
