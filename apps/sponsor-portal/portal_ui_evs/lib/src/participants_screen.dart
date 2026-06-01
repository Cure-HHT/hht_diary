import 'dart:math';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'participant_status.dart';

// Reactive Participants list over the participant_record view (gated
// view:participant_record). Each row shows the participant id, site and REAL
// derived status, plus a lifecycle-action row. A button is ENABLED iff the
// pure state machine (enabledActions) permits it for the current status;
// otherwise it renders disabled with a tooltip explaining the diary gate.
// Enabled buttons dispatch the real portal_actions (ACT-PAT-00x).
//
// Implements: DIARY-DEV-participant-status-projection/A+B

const String _viewPerm = 'view:participant_record';

const String _kLinkAction =
    'ACT-PAT-001'; // {siteId, participantId, linkingCode, expiresAt}
const String _kStartTrialAction = 'ACT-PAT-002'; // {siteId, participantId}
const String _kDisconnectAction =
    'ACT-PAT-003'; // {siteId, participantId, reason}
const String _kReconnectAction =
    'ACT-PAT-004'; // {siteId, participantId, linkingCode, expiresAt}
const String _kMarkNotParticipatingAction =
    'ACT-PAT-005'; // {siteId, participantId, reason}
const String _kReactivateAction =
    'ACT-PAT-006'; // {siteId, participantId, reason, linkingCode, expiresAt}

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
        id: (row['aggregateId'] as String?) ??
            (row['participant_id'] as String?) ??
            '?',
        siteId: (row['site_id'] as String?) ?? '?',
        status: statusFromEntryType(row['entryType'] as String?),
        linkingCode: row['linking_code'] as String?,
      );
}

/// Generates a short uppercase alphanumeric client-side linking code.
String _generateLinkingCode() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rng = Random();
  return String.fromCharCodes(
    Iterable<int>.generate(
      8,
      (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
    ),
  );
}

String _expiresAt72h() =>
    DateTime.now().toUtc().add(const Duration(hours: 72)).toIso8601String();

/// Maps an enabled [ParticipantAction] to its (actionName, rawInput). Returns
/// null for [ParticipantAction.showCode], which is a view-only no-op handled
/// separately (a dialog), and for any action not dispatchable for [p].
({String name, Map<String, Object?> input})? _submissionFor(
  ParticipantAction action,
  _P p,
) {
  switch (action) {
    case ParticipantAction.issueLinkingCode:
      return (
        name: _kLinkAction,
        input: <String, Object?>{
          'siteId': p.siteId,
          'participantId': p.id,
          'linkingCode': _generateLinkingCode(),
          'expiresAt': _expiresAt72h(),
        },
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
        input: <String, Object?>{
          'siteId': p.siteId,
          'participantId': p.id,
          'linkingCode': _generateLinkingCode(),
          'expiresAt': _expiresAt72h(),
        },
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
          'linkingCode': _generateLinkingCode(),
          'expiresAt': _expiresAt72h(),
        },
      );
    case ParticipantAction.showCode:
      return null;
  }
}

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
              return const Center(
                child: Text('(no participants synced yet)'),
              );
            }
            return ListView(
              children: <Widget>[
                for (final p in rows)
                  ExpansionTile(
                    title: Text(p.id),
                    subtitle: Text('site ${p.siteId} · ${p.status.label}'),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Wrap(
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
                      ),
                    ],
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
        child: OutlinedButton(
          onPressed: null,
          child: Text(action.label),
        ),
      );
    }

    // showCode is a view-only no-op: it surfaces the current linking code.
    if (action == ParticipantAction.showCode) {
      return OutlinedButton(
        onPressed: () => _showCode(context),
        child: Text(action.label),
      );
    }

    final submission = _submissionFor(action, participant)!;
    return ActionBuilder(
      submissionFactory: () => ActionSubmission(
        actionName: submission.name,
        rawInput: submission.input,
      ),
      builder: (context, state, submit) => FilledButton(
        onPressed: state is Submitting ? null : submit,
        child: Text(switch (state) {
          Submitting() => '...',
          Denied() => 'Denied',
          Failed() => 'Failed',
          _ => action.label,
        }),
      ),
    );
  }

  void _showCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Linking code · ${participant.id}'),
        content: Text(participant.linkingCode ?? '(none)'),
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
