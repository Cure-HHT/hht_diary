import 'package:event_sourcing/event_sourcing.dart';
// Explicit for @visibleForTesting (also re-exported transitively by
// material.dart, hence the ignore).
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'activation_code_display.dart';
import 'participant_status.dart';
import 'start_trial_dialog.dart';

// Reactive Participants list over the participant_record view (gated
// view:participant_record). Each row shows the participant id, site and REAL
// derived status, plus a lifecycle-action row. A button is ENABLED iff the
// pure state machine (enabledActions) permits it for the current status;
// otherwise it renders disabled with a tooltip explaining the diary gate.
// Enabled buttons dispatch the real portal_actions (ACT-PAT-00x).
//
// Implements: DIARY-DEV-participant-status-projection/A+B

const String _viewPerm = 'view:participant_record';

const String _kLinkAction = 'ACT-PAT-001'; // {siteId, participantId}
const String _kStartTrialAction = 'ACT-PAT-002'; // {siteId, participantId}
const String _kDisconnectAction =
    'ACT-PAT-003'; // {siteId, participantId, reason}
const String _kReconnectAction = 'ACT-PAT-004'; // {siteId, participantId}
const String _kMarkNotParticipatingAction =
    'ACT-PAT-005'; // {siteId, participantId, reason}
const String _kReactivateAction =
    'ACT-PAT-006'; // {siteId, participantId, reason}

const String _kDisabledTooltip = 'Available once a connected diary is running';
const String _kPlaceholderReason = 'portal action';

/// One participant_record row: aggregateId == participant_id (row key), plus
/// the EDC-synced site_id, the stamped latest entryType (-> status), and the
/// last-issued linking_code (for showCode).
class _P {
  const _P({
    required this.id,
    required this.siteId,
    required this.status,
    this.linkingCode,
  });

  final String id;
  final String siteId;
  final ParticipantStatus status;
  final String? linkingCode;

  static _P fromRow(Map<String, Object?> row) => _P(
    id:
        (row['aggregateId'] as String?) ??
        (row['participant_id'] as String?) ??
        '?',
    siteId: (row['site_id'] as String?) ?? '?',
    // Use the trial-start-aware status so a reactivated + re-linked participant
    // (whose original started_at is preserved) reads as Trial Active and is not
    // re-offered Start Trial. See effectiveParticipantStatus.
    status: effectiveParticipantStatus(
      row['entryType'] as String?,
      trialStarted: row['started_at'] != null,
    ),
    linkingCode: row['linking_code'] as String?,
  );
}

/// Maps an enabled [ParticipantAction] to its (actionName, rawInput). Returns
/// null for [ParticipantAction.showCode], which is a view-only no-op handled
/// separately (a dialog), and for any action not dispatchable for [p].
///
/// The issuing actions (ACT-PAT-001/004/006) submit ONLY identity
/// ({siteId, participantId}, plus `reason` for reactivate). The linking code
/// and 72h expiry are generated SERVER-SIDE by the action and returned in its
/// result — the client never supplies them.
({String name, Map<String, Object?> input})? _submissionFor(
  ParticipantAction action,
  _P p,
) {
  switch (action) {
    case ParticipantAction.issueLinkingCode:
      return (
        name: _kLinkAction,
        input: <String, Object?>{'siteId': p.siteId, 'participantId': p.id},
      );
    case ParticipantAction.startTrial:
      return (
        name: _kStartTrialAction,
        input: <String, Object?>{'siteId': p.siteId, 'participantId': p.id},
      );
    case ParticipantAction.disconnect:
      return (
        name: _kDisconnectAction,
        input: <String, Object?>{
          'siteId': p.siteId,
          'participantId': p.id,
          'reason': _kPlaceholderReason,
        },
      );
    case ParticipantAction.reconnect:
      return (
        name: _kReconnectAction,
        input: <String, Object?>{'siteId': p.siteId, 'participantId': p.id},
      );
    case ParticipantAction.markNotParticipating:
      return (
        name: _kMarkNotParticipatingAction,
        input: <String, Object?>{
          'siteId': p.siteId,
          'participantId': p.id,
          'reason': _kPlaceholderReason,
        },
      );
    case ParticipantAction.reactivate:
      return (
        name: _kReactivateAction,
        input: <String, Object?>{
          'siteId': p.siteId,
          'participantId': p.id,
          'reason': _kPlaceholderReason,
        },
      );
    case ParticipantAction.showCode:
      return null;
  }
}

/// The lifecycle actions that cause the SERVER to generate (or re-generate) a
/// linking code: issue (001), reconnect (004), and reactivate (006). On
/// success the action result carries `{linkingCode, expiresAt}`, which the UI
/// surfaces inline.
const Set<ParticipantAction> _kIssuingActions = <ParticipantAction>{
  ParticipantAction.issueLinkingCode,
  ParticipantAction.reconnect,
  ParticipantAction.reactivate,
};

/// Test-only accessor for [_submissionFor]: lets tests assert that an issuing
/// submission carries ONLY identity keys (no client-generated linkingCode /
/// expiresAt). Returns the (actionName, rawInput) record, or null for the
/// view-only showCode pseudo-action.
@visibleForTesting
({String name, Map<String, Object?> input})? submissionForTest(
  ParticipantAction action, {
  required String siteId,
  required String participantId,
}) => _submissionFor(
  action,
  _P(id: participantId, siteId: siteId, status: ParticipantStatus.unknown),
);

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: _viewPerm,
    fallback: const Center(
      child: Text("You don't have permission to view participants."),
    ),
    child: ViewBuilder<_P>(
      viewName: 'participant_record',
      mapper: _P.fromRow,
      aggregateIdOf: (p) => p.id,
      builder: (context, state) {
        final rows = switch (state) {
          Loading<_P>() => const <_P>[],
          Ready<_P>(:final rows) => rows,
          Stale<_P>(:final lastRows) => lastRows,
        };
        if (state is Loading<_P>) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rows.isEmpty) {
          return const Center(child: Text('(no participants synced yet)'));
        }
        // One card per participant with the lifecycle-action buttons rendered
        // inline (always visible). A button is enabled iff the pure state
        // machine permits it for the current status; otherwise it renders
        // disabled with a tooltip.
        //
        // WHY inline rather than an ExpansionTile (which would be the natural,
        // more compact UX): the actions live in a reactive list that re-renders
        // on every participant_record change, and a CanvasKit ExpansionTile's
        // expand toggle is non-deterministic to drive through the Flutter-web
        // semantics tree (its header semantics node churns on rebuild, so the
        // expand click is flaky under Playwright). Rendering the actions inline
        // removes the expand step so the row is deterministic for CUR-1307
        // browser e2e. If/when the e2e moves off the live UI, an ExpansionTile
        // would be the preferred presentation.
        return ListView(
          children: <Widget>[
            for (final p in rows)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // CUR-1307: identified for Playwright web automation.
                      Semantics(
                        identifier: 'participant-${p.id}',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.id),
                          subtitle: Text(
                            'site ${p.siteId} · ${p.status.label}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final action in ParticipantAction.values)
                            _ParticipantActionButton(
                              participant: p,
                              action: action,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// One lifecycle-action button. Enabled iff enabledActions(status) permits the
/// action: showCode pops a dialog with the current linking code; the other
/// enabled actions dispatch their portal_action. When not permitted, renders a
/// disabled button wrapped in a tooltip explaining the diary gate.
///
/// Implements: DIARY-DEV-participant-status-projection/A+B
class _ParticipantActionButton extends StatelessWidget {
  const _ParticipantActionButton({
    required this.participant,
    required this.action,
  });

  final _P participant;
  final ParticipantAction action;

  @override
  Widget build(BuildContext context) {
    final permitted = enabledActions(participant.status).contains(action);
    if (!permitted) {
      return Tooltip(
        message: _kDisabledTooltip,
        child: OutlinedButton(onPressed: null, child: Text(action.label)),
      );
    }

    // startTrial ("Send EQ") opens a confirmation dialog that owns the
    // ACT-PAT-002 dispatch + result (port of the legacy StartTrialDialog),
    // rather than dispatching inline. Starting the trial turns on the
    // participant's Diary Data Synchronization; the row flips to "Trial active"
    // reactively on success.
    if (action == ParticipantAction.startTrial) {
      return Semantics(
        identifier: 'send-eq-${participant.id}',
        button: true,
        container: true,
        explicitChildNodes: true,
        child: FilledButton.icon(
          onPressed: () => StartTrialDialog.show(
            context: context,
            participantId: participant.id,
            siteId: participant.siteId,
          ),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send EQ'),
        ),
      );
    }

    // showCode is a view-only no-op: it surfaces the current linking code.
    if (action == ParticipantAction.showCode) {
      // CUR-1307: identified for Playwright (container+explicitChildNodes so the
      // identifier survives the OutlinedButton's own button semantics).
      return Semantics(
        identifier: 'showcode-${participant.id}',
        button: true,
        container: true,
        explicitChildNodes: true,
        child: OutlinedButton(
          onPressed: () => _showCode(context),
          child: Text(action.label),
        ),
      );
    }

    final submission = _submissionFor(action, participant)!;
    final isIssuing = _kIssuingActions.contains(action);
    return ActionBuilder(
      submissionFactory: () => ActionSubmission(
        actionName: submission.name,
        rawInput: submission.input,
      ),
      builder: (context, state, submit) {
        // On a successful issuing action, surface the SERVER-generated code
        // inline (instead of the bare button), with copy + expiry. The code
        // comes from the action result, NOT a client-side guess. The issuing
        // actions are Idempotency.required, so a double-tap / retry / same-key
        // resubmit returns a DispatchIdempotencyHit (carrying the cached
        // result) rather than a fresh DispatchSuccess — ActionBuilder maps
        // BOTH to Success, so we read the result map from either variant.
        //
        // NOTE: this inline display is TRANSIENT — it lives only in this
        // ActionBuilder's state and is lost if the row's ExpansionTile
        // collapses (the subtree is rebuilt). The PERSISTENT source of the
        // code is the showCode dialog, backed by the reactive
        // participant_record.linking_code projection. This is intentional; do
        // NOT make the widget stateful to retain it.
        if (isIssuing && state is Success) {
          final dr = state.result;
          final Object? data = switch (dr) {
            DispatchSuccess<Object?>(:final result) => result,
            DispatchIdempotencyHit<Object?>(:final cachedResult) =>
              cachedResult,
            _ => null,
          };
          if (data is Map) {
            final code = data['linkingCode'] as String?;
            if (code != null) {
              // CUR-1307: expose the server code on the semantics tree (value ->
              // aria-label on web) so Playwright can read the issued code.
              // container+explicitChildNodes keep this identifier from being
              // merged away by the copy IconButton's own button semantics.
              return Semantics(
                identifier: 'linking-code-${participant.id}',
                value: code,
                container: true,
                explicitChildNodes: true,
                child: ActivationCodeDisplay(
                  code: code,
                  label: 'Linking code',
                  expiresAt: data['expiresAt'] as String?,
                ),
              );
            }
          }
        }
        final button = FilledButton(
          onPressed: state is Submitting ? null : submit,
          child: Text(switch (state) {
            Submitting() => '...',
            Denied() => 'Denied',
            Failed() => 'Failed',
            _ => action.label,
          }),
        );
        // CUR-1307: a stable identifier for the issue button so Playwright can
        // tap it. container+explicitChildNodes keep the identifier from being
        // merged away by the FilledButton's own button semantics (PR#28 gotcha).
        if (!isIssuing) return button;
        return Semantics(
          identifier: 'issue-${participant.id}',
          container: true,
          explicitChildNodes: true,
          child: button,
        );
      },
    );
  }

  void _showCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Linking code · ${participant.id}'),
        content: participant.linkingCode == null
            ? const Text('(none)')
            // CUR-1307: expose the persistent (reactive participant_record)
            // code on the semantics tree for Playwright. This is the stable
            // read path — unlike the transient inline ActionBuilder success
            // display, which the reactive list rebuild clears once issuance
            // flips the participant to "pending".
            : Semantics(
                identifier: 'linking-code-${participant.id}',
                value: participant.linkingCode!,
                container: true,
                explicitChildNodes: true,
                child: ActivationCodeDisplay(
                  code: participant.linkingCode!,
                  fontSize: 20,
                ),
              ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Test-only harness that renders the issuing-action button for a
/// fresh (notConnected) participant — i.e. the Issue Linking Code button,
/// whose ActionBuilder surfaces the SERVER-returned code on success.
@visibleForTesting
class ActionBuilderHarness extends StatelessWidget {
  const ActionBuilderHarness({
    super.key,
    required this.siteId,
    required this.participantId,
  });

  final String siteId;
  final String participantId;

  @override
  Widget build(BuildContext context) => _ParticipantActionButton(
    participant: _P(
      id: participantId,
      siteId: siteId,
      status: ParticipantStatus.notConnected,
    ),
    action: ParticipantAction.issueLinkingCode,
  );
}
