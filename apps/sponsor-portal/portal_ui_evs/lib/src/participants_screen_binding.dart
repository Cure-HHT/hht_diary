import 'dart:async';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart' hide ParticipantsScreen;
import 'package:portal_screens/portal_screens.dart'
    as screens
    show ParticipantsScreen;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'activation_code_display.dart';
import 'manage_questionnaires_dialog.dart';
import 'participant_status.dart';
import 'site_visibility.dart';
import 'start_trial_dialog.dart';

// Reactive wiring for the redesigned Participants screen: joins
// participant_record (status + linking code), sites_index (names + the
// My Sites strip), and questionnaire_instance (ready-to-review bell)
// into ParticipantRowView snapshots, and routes the per-status Action
// button + overflow lifecycle menu to their dialogs/dispatches.
//
// Implements: DIARY-DEV-participant-status-projection/A+B

const String _kLinkAction = 'ACT-PAT-001'; // {siteId, participantId}
const String _kDisconnectAction =
    'ACT-PAT-003'; // {siteId, participantId, reason}
const String _kReconnectAction = 'ACT-PAT-004'; // {siteId, participantId}
const String _kMarkNotParticipatingAction =
    'ACT-PAT-005'; // {siteId, participantId, reason}
const String _kReactivateAction =
    'ACT-PAT-006'; // {siteId, participantId, reason}
const String _kPlaceholderReason = 'portal action';

/// Internal joined row: the participant_record fields the view model and
/// the dialogs need.
class ParticipantRecordRow {
  const ParticipantRecordRow({
    required this.id,
    required this.siteId,
    required this.status,
    this.linkingCode,
    this.expiresAtRaw,
  });

  final String id;
  final String siteId;
  final ParticipantStatus status;
  final String? linkingCode;
  final String? expiresAtRaw;

  static ParticipantRecordRow fromRow(Map<String, Object?> row) =>
      ParticipantRecordRow(
        id:
            (row['aggregateId'] as String?) ??
            (row['participant_id'] as String?) ??
            '?',
        siteId: (row['site_id'] as String?) ?? '?',
        // Trial-start-aware: a reactivated + re-linked participant whose
        // original started_at is preserved reads Trial Active (see
        // effectiveParticipantStatus).
        status: effectiveParticipantStatus(
          row['entryType'] as String?,
          trialStarted: row['started_at'] != null,
        ),
        linkingCode: row['linking_code'] as String?,
        expiresAtRaw: row['expires_at'] as String?,
      );

  /// True when the active code's expiry has passed (Pending only — a used
  /// code has already moved the participant to Connected).
  bool isExpired(DateTime now) {
    if (status != ParticipantStatus.pending) return false;
    final raw = expiresAtRaw;
    if (raw == null) return false;
    final t = DateTime.tryParse(raw);
    return t != null && !now.isBefore(t);
  }
}

/// participant_record lifecycle status -> the display status (with the
/// Code Pending / Expired split).
ParticipantRowStatus displayStatusFor(
  ParticipantRecordRow row, {
  required DateTime now,
}) => switch (row.status) {
  ParticipantStatus.notConnected => ParticipantRowStatus.notConnected,
  ParticipantStatus.pending =>
    row.isExpired(now)
        ? ParticipantRowStatus.expired
        : ParticipantRowStatus.codePending,
  ParticipantStatus.connected => ParticipantRowStatus.linkedAwaitingStart,
  ParticipantStatus.trialActive => ParticipantRowStatus.trialActive,
  ParticipantStatus.disconnected => ParticipantRowStatus.disconnected,
  ParticipantStatus.notParticipating => ParticipantRowStatus.notParticipating,
  ParticipantStatus.unknown => ParticipantRowStatus.unknown,
};

/// The overflow-menu lifecycle actions for a display status: the state
/// machine's legal set minus the row's primary action.
List<ParticipantMenuAction> menuActionsFor(ParticipantRowStatus status) =>
    switch (status) {
      ParticipantRowStatus.notConnected ||
      ParticipantRowStatus.codePending => const [],
      ParticipantRowStatus.expired => const [ParticipantMenuAction.showCode],
      ParticipantRowStatus.linkedAwaitingStart ||
      ParticipantRowStatus.trialActive => const [
        ParticipantMenuAction.disconnect,
        ParticipantMenuAction.showCode,
      ],
      ParticipantRowStatus.disconnected => const [
        ParticipantMenuAction.reconnect,
        ParticipantMenuAction.markNotParticipating,
        ParticipantMenuAction.showCode,
      ],
      ParticipantRowStatus.notParticipating => const [
        ParticipantMenuAction.reactivate,
      ],
      ParticipantRowStatus.unknown => const [],
    };

class ParticipantsScreenBinding extends StatefulWidget {
  const ParticipantsScreenBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
    this.now,
  });

  /// Threaded to the Manage Questionnaires modal's send POST.
  final String identityCredential;
  final String serverUrl;

  /// Test seam for the expiry split; null = DateTime.now().
  final DateTime Function()? now;

  /// Permission a role must hold to see the Participants tab at all.
  /// (Administrator does not hold it — CUR-1472.)
  static const String viewPermission = 'portal.participant.view';

  @override
  State<ParticipantsScreenBinding> createState() =>
      _ParticipantsScreenBindingState();
}

class _ParticipantsScreenBindingState extends State<ParticipantsScreenBinding> {
  StreamSubscription<EffectiveAuthorization?>? _authSub;
  EffectiveAuthorization? _auth;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authSub != null) return;
    final scope = ReActionScope.of(context);
    _auth = scope.permissionSource.current;
    _authSub = scope.permissionSource.stream.listen((auth) {
      if (!mounted) return;
      setState(() => _auth = auth);
    });
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: ParticipantsScreenBinding.viewPermission,
    fallback: const Center(
      child: Text("You don't have permission to view participants."),
    ),
    child: ViewBuilder<ParticipantRecordRow>(
      viewName: 'participant_record',
      mapper: ParticipantRecordRow.fromRow,
      aggregateIdOf: (p) => p.id,
      builder: (context, recordState) {
        final records = switch (recordState) {
          Loading<ParticipantRecordRow>() => const <ParticipantRecordRow>[],
          Ready<ParticipantRecordRow>(:final rows) => rows,
          Stale<ParticipantRecordRow>(:final lastRows) => lastRows,
        };
        final loading = recordState is Loading<ParticipantRecordRow>;
        // Site names + My Sites strip: separately gated; a viewer without
        // portal.site.view still gets the table (site ids as names).
        return PermissionGate(
          permission: 'portal.site.view',
          fallback: _withQuestionnaires(
            records: records,
            sites: const <SiteRowView>[],
            isLoading: loading,
          ),
          child: ViewBuilder<SiteRowView>(
            viewName: 'sites_index',
            mapper: _siteFromRow,
            aggregateIdOf: (s) => s.id,
            builder: (context, siteState) {
              final sites = switch (siteState) {
                Loading<SiteRowView>() => const <SiteRowView>[],
                Ready<SiteRowView>(:final rows) => rows,
                Stale<SiteRowView>(:final lastRows) => lastRows,
              };
              return _withQuestionnaires(
                records: records,
                sites: sites,
                isLoading: loading,
              );
            },
          ),
        );
      },
    ),
  );

  /// Inner join for the ready-to-review bell, separately gated so a role
  /// without questionnaire visibility still gets the table (no bells).
  Widget _withQuestionnaires({
    required List<ParticipantRecordRow> records,
    required List<SiteRowView> sites,
    required bool isLoading,
  }) => PermissionGate(
    permission: 'portal.questionnaire.view_status',
    fallback: _renderScreen(
      records: records,
      sites: sites,
      readyParticipants: const <String>{},
      isLoading: isLoading,
    ),
    child: ViewBuilder<_QInstance>(
      viewName: 'questionnaire_instance',
      mapper: _QInstance.fromRow,
      aggregateIdOf: (q) => q.instanceId,
      builder: (context, qState) {
        final instances = switch (qState) {
          Loading<_QInstance>() => const <_QInstance>[],
          Ready<_QInstance>(:final rows) => rows,
          Stale<_QInstance>(:final lastRows) => lastRows,
        };
        return _renderScreen(
          records: records,
          sites: sites,
          readyParticipants: {
            for (final q in instances)
              if (q.readyToReview) q.participantId,
          },
          isLoading: isLoading,
        );
      },
    ),
  );

  Widget _renderScreen({
    required List<ParticipantRecordRow> records,
    required List<SiteRowView> sites,
    required Set<String> readyParticipants,
    required bool isLoading,
  }) {
    final now = _now;
    final siteNameById = <String, String>{for (final s in sites) s.id: s.name};
    final byId = <String, ParticipantRecordRow>{
      for (final r in records) r.id: r,
    };
    final views = <ParticipantRowView>[
      for (final r in records)
        () {
          final status = displayStatusFor(r, now: now);
          return ParticipantRowView(
            id: r.id,
            siteName: siteNameById[r.siteId] ?? r.siteId,
            status: status,
            hasReadyToReview: readyParticipants.contains(r.id),
            menuActions: menuActionsFor(status),
          );
        }(),
    ];
    // My Sites strip: the viewer's assigned sites (same narrowing as the
    // Sites page), formatted "001 - Memorial Hospital".
    final mySites = visibleSiteRows(
      sites: sites,
      scopeAssignments: _auth?.scopeAssignments ?? const [],
    );
    final chips = <String>[
      for (final s in mySites..sort((a, b) => a.number.compareTo(b.number)))
        '${s.number} - ${s.name}',
    ];
    return screens.ParticipantsScreen(
      participants: views,
      siteChips: chips,
      isLoading: isLoading,
      onPrimaryAction: (row) => _onPrimary(byId[row.id]!, row),
      onMenuAction: (row, action) => _onMenu(byId[row.id]!, action),
    );
  }

  void _onPrimary(ParticipantRecordRow record, ParticipantRowView row) {
    switch (primaryActionFor(row.status)) {
      case ParticipantPrimaryAction.linkParticipant ||
          ParticipantPrimaryAction.regenerateCode:
        unawaited(
          LinkParticipantDialog.show(
            context: context,
            participantId: record.id,
            siteId: record.siteId,
          ),
        );
      case ParticipantPrimaryAction.showLinkingCode:
        _showCodeDialog(record);
      case ParticipantPrimaryAction.startTrial:
        unawaited(
          StartTrialDialog.show(
            context: context,
            participantId: record.id,
            siteId: record.siteId,
          ),
        );
      case ParticipantPrimaryAction.manageQuestionnaires:
        unawaited(
          ManageQuestionnairesDialog.show(
            context: context,
            participantId: record.id,
            siteId: record.siteId,
            serverUrl: widget.serverUrl,
            identityCredential: widget.identityCredential,
          ),
        );
      case ParticipantPrimaryAction.none:
        break;
    }
  }

  void _onMenu(ParticipantRecordRow record, ParticipantMenuAction action) {
    switch (action) {
      case ParticipantMenuAction.showCode:
        _showCodeDialog(record);
      case ParticipantMenuAction.disconnect:
        _confirmLifecycle(
          record,
          actionName: _kDisconnectAction,
          title: 'Disconnect Participant',
          body:
              'The participant\'s device will stop syncing diary entries '
              'until they are reconnected with a new linking code.',
          confirmLabel: 'Disconnect',
          withReason: true,
        );
      case ParticipantMenuAction.reconnect:
        _confirmLifecycle(
          record,
          actionName: _kReconnectAction,
          title: 'Reconnect Participant',
          body:
              'A new linking code will be generated for the participant to '
              're-connect their Mobile Application. The code will expire '
              'after 72 hours.',
          confirmLabel: 'Reconnect',
          showsCodeOnSuccess: true,
        );
      case ParticipantMenuAction.markNotParticipating:
        _confirmLifecycle(
          record,
          actionName: _kMarkNotParticipatingAction,
          title: 'Mark Not Participating',
          body:
              'The participant will be marked as not participating and their '
              'device link released. They can be reactivated later.',
          confirmLabel: 'Mark Not Participating',
          withReason: true,
        );
      case ParticipantMenuAction.reactivate:
        _confirmLifecycle(
          record,
          actionName: _kReactivateAction,
          title: 'Reactivate Participant',
          body:
              'A new linking code will be generated for the participant to '
              're-connect their Mobile Application. The code will expire '
              'after 72 hours.',
          confirmLabel: 'Reactivate',
          withReason: true,
          showsCodeOnSuccess: true,
        );
    }
  }

  void _showCodeDialog(ParticipantRecordRow record) {
    final used =
        record.status == ParticipantStatus.connected ||
        record.status == ParticipantStatus.trialActive;
    unawaited(
      showLinkingCodeDialog(
        context: context,
        participantId: record.id,
        code: record.linkingCode,
        expiresAtRaw: record.expiresAtRaw,
        used: used,
        now: _now,
      ),
    );
  }

  void _confirmLifecycle(
    ParticipantRecordRow record, {
    required String actionName,
    required String title,
    required String body,
    required String confirmLabel,
    bool withReason = false,
    bool showsCodeOnSuccess = false,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LifecycleActionDialog(
          participantId: record.id,
          actionName: actionName,
          rawInput: <String, Object?>{
            'siteId': record.siteId,
            'participantId': record.id,
            if (withReason) 'reason': _kPlaceholderReason,
          },
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          showsCodeOnSuccess: showsCodeOnSuccess,
        ),
      ),
    );
  }
}

SiteRowView _siteFromRow(Map<String, Object?> r) => SiteRowView(
  id: (r['site_id'] as String?) ?? '?',
  name: (r['site_name'] as String?) ?? '?',
  number: (r['site_number'] as String?) ?? '?',
  active: (r['is_active'] as bool?) ?? true,
);

class _QInstance {
  const _QInstance({
    required this.instanceId,
    required this.participantId,
    required this.readyToReview,
  });

  final String instanceId;
  final String participantId;
  final bool readyToReview;

  static _QInstance fromRow(Map<String, Object?> row) => _QInstance(
    instanceId: (row['aggregateId'] as String?) ?? '?',
    participantId: (row['participant_id'] as String?) ?? '?',
    readyToReview: row['entryType'] == 'questionnaire_submission_received',
  );
}

/// "Expires in 3 days, 0 hours" (Figma) — floor-of-hours remaining.
String expiresInLabel(String? expiresAtRaw, DateTime now) {
  final t = expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw);
  if (t == null) return '';
  final left = t.difference(now);
  if (left.isNegative) return 'Expired';
  final days = left.inDays;
  final hours = left.inHours - days * 24;
  return 'Expires in $days days, $hours hours';
}

/// Link Participant / Regenerate Code: confirm (Figma "Link Participant"),
/// dispatch ACT-PAT-001, then show the server-generated code (Figma
/// "Mobile Linking Code").
class LinkParticipantDialog extends StatelessWidget {
  const LinkParticipantDialog({
    super.key,
    required this.participantId,
    required this.siteId,
  });

  final String participantId;
  final String siteId;

  static Future<void> show({
    required BuildContext context,
    required String participantId,
    required String siteId,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        LinkParticipantDialog(participantId: participantId, siteId: siteId),
  );

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      semanticIdentifier: 'link-participant-outcome-$participantId',
      submissionFactory: () => ActionSubmission(
        actionName: _kLinkAction,
        rawInput: <String, Object?>{
          'siteId': siteId,
          'participantId': participantId,
        },
      ),
      builder: (context, state, submit) {
        switch (state) {
          case Success():
            final data = switch (state.result) {
              DispatchSuccess<Object?>(:final result) => result,
              DispatchIdempotencyHit<Object?>(:final cachedResult) =>
                cachedResult,
              _ => null,
            };
            final code = data is Map ? data['linkingCode'] as String? : null;
            final expiresAt = data is Map ? data['expiresAt'] as String? : null;
            return _MobileLinkingCodeDialog(
              participantId: participantId,
              code: code ?? '?',
              subtitle:
                  'The linking code has been generated successfully. Share '
                  'it with participant to connect their Mobile Application.',
              footer: expiresInLabel(expiresAt, DateTime.now()),
            );
          case Denied() || Failed():
            return _ErrorDialog(state: state, onRetry: submit);
          default:
            // Idle + Submitting share the confirm shape; the Confirm
            // button carries the in-flight spinner (kit pattern).
            final busy = state is Submitting;
            return AppDialog(
              size: AppDialogSize.small,
              title: 'Link Participant',
              dismissible: false,
              semanticId: 'link-participant-dialog-$participantId',
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParticipantIdLine(participantId: participantId),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you sure you want to generate a Linking Code? The '
                    'Participant will use this code to connect their Mobile '
                    'Application. The code will expire after 72 hours.',
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
                  label: 'Confirm',
                  loading: busy,
                  onPressed: busy ? null : submit,
                  semanticId: 'link-participant-confirm-$participantId',
                ),
              ],
            );
        }
      },
    );
  }
}

/// "Participant ID: [participantId]" header line shared by the dialogs.
class _ParticipantIdLine extends StatelessWidget {
  const _ParticipantIdLine({required this.participantId});

  final String participantId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
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
    );
  }
}

/// Shared kit error dialog for a Denied/Failed dispatch.
class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.state, required this.onRetry});

  final ActionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Error',
      dismissible: false,
      body: AppBanner(
        severity: AppBannerSeverity.error,
        message: switch (state) {
          Denied(:final result) => 'The action was not permitted ($result).',
          Failed(:final error) => 'Failed: $error',
          _ => 'An error occurred.',
        },
      ),
      actions: [
        AppButton(
          variant: AppButtonVariant.secondary,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Try Again', onPressed: onRetry),
      ],
    );
  }
}

/// Figma "Mobile Linking Code": code box with copy + expiry footer.
class _MobileLinkingCodeDialog extends StatelessWidget {
  const _MobileLinkingCodeDialog({
    required this.participantId,
    required this.code,
    required this.subtitle,
    required this.footer,
    this.muted = false,
  });

  final String participantId;
  final String code;
  final String subtitle;
  final String footer;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog(
      size: AppDialogSize.small,
      title: 'Mobile Linking Code',
      semanticId: 'linking-code-dialog-$participantId',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParticipantIdLine(participantId: participantId),
          const SizedBox(height: 12),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Opacity(
            opacity: muted ? 0.55 : 1,
            child: Semantics(
              identifier: 'linking-code-$participantId',
              value: code,
              container: true,
              explicitChildNodes: true,
              child: ActivationCodeDisplay(code: code, fontSize: 20),
            ),
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: 'OK',
          onPressed: () => Navigator.of(context).pop(),
          semanticId: 'linking-code-ok-$participantId',
        ),
      ],
    );
  }
}

/// Show Linking Code (row data): active code with expiry, or the
/// reference-only used state (Figma image 7).
Future<void> showLinkingCodeDialog({
  required BuildContext context,
  required String participantId,
  required String? code,
  required String? expiresAtRaw,
  required bool used,
  required DateTime now,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MobileLinkingCodeDialog(
      participantId: participantId,
      code: code ?? '(none)',
      muted: used,
      subtitle: used
          ? 'Reference only. This code was already used and cannot be used '
                'to establish a new connection.'
          : 'Share this code with the participant to connect their Mobile '
                'Application.',
      footer: used ? '' : expiresInLabel(expiresAtRaw, now),
    ),
  );
}

/// Generic lifecycle confirm + dispatch dialog (Disconnect / Reconnect /
/// Mark Not Participating / Reactivate). The issuing actions surface the
/// regenerated code on success.
class _LifecycleActionDialog extends StatelessWidget {
  const _LifecycleActionDialog({
    required this.participantId,
    required this.actionName,
    required this.rawInput,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.showsCodeOnSuccess,
  });

  final String participantId;
  final String actionName;
  final Map<String, Object?> rawInput;
  final String title;
  final String body;
  final String confirmLabel;
  final bool showsCodeOnSuccess;

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      semanticIdentifier: 'lifecycle-outcome-$participantId',
      submissionFactory: () =>
          ActionSubmission(actionName: actionName, rawInput: rawInput),
      builder: (context, state, submit) {
        switch (state) {
          case Success():
            final data = switch (state.result) {
              DispatchSuccess<Object?>(:final result) => result,
              DispatchIdempotencyHit<Object?>(:final cachedResult) =>
                cachedResult,
              _ => null,
            };
            final code = data is Map ? data['linkingCode'] as String? : null;
            if (showsCodeOnSuccess && code != null) {
              return _MobileLinkingCodeDialog(
                participantId: participantId,
                code: code,
                subtitle:
                    'The linking code has been generated successfully. Share '
                    'it with participant to connect their Mobile Application.',
                footer: expiresInLabel(
                  data is Map ? data['expiresAt'] as String? : null,
                  DateTime.now(),
                ),
              );
            }
            return AppDialog(
              size: AppDialogSize.small,
              title: title,
              dismissible: false,
              body: const Text("Done. The participant's status has updated."),
              actions: [
                AppButton(
                  label: 'OK',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          case Denied() || Failed():
            return _ErrorDialog(state: state, onRetry: submit);
          default:
            final busy = state is Submitting;
            return AppDialog(
              size: AppDialogSize.small,
              title: title,
              dismissible: false,
              semanticId: 'lifecycle-dialog-$participantId',
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParticipantIdLine(participantId: participantId),
                  const SizedBox(height: 16),
                  Text(body),
                ],
              ),
              actions: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  label: 'Cancel',
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
                AppButton(
                  label: confirmLabel,
                  loading: busy,
                  onPressed: busy ? null : submit,
                ),
              ],
            );
        }
      },
    );
  }
}
