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
import 'participant_actions_dialog.dart';
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

/// How a lifecycle action collects its mandatory reason. The format is
/// Sponsor-configurable (DIARY-PRD-participant-disconnection/C); these are the
/// default presentations the Figma confirm dialogs show — a predefined
/// dropdown for disconnect / mark-not-participating, a free-text field for
/// reconnect / reactivate.
enum _ReasonInput { none, dropdown, freeText }

/// Default predefined disconnection reasons (Sponsor-overridable controlled
/// vocabulary).
const List<String> _kDisconnectReasons = <String>[
  'Device fault',
  'Connectivity issue',
  'Lost or replaced device',
  'Temporary withdrawal',
  'Other',
];

/// Default predefined mark-as-not-participating reasons (Sponsor-overridable).
const List<String> _kNotParticipatingReasons = <String>[
  'Completed trial',
  'Withdrew consent',
  'Lost to follow-up',
  'Screen failure / ineligible',
  'Other',
];

/// Free-text reason cap (DIARY-PRD-reason-field-constraints): 100 characters,
/// whitespace-only submissions rejected.
const int _kReasonMaxLength = 100;

/// Internal joined row: the participant_record fields the view model and
/// the dialogs need.
class ParticipantRecordRow {
  const ParticipantRecordRow({
    required this.id,
    required this.siteId,
    required this.status,
    this.linkingCode,
    this.expiresAtRaw,
    this.usedAtRaw,
  });

  final String id;
  final String siteId;
  final ParticipantStatus status;
  final String? linkingCode;
  final String? expiresAtRaw;

  /// ISO-8601 timestamp the code was redeemed (folded from
  /// `participant_linking_code_used`). Drives the "Used on …" line in the
  /// reference-only Mobile Linking Code dialog.
  final String? usedAtRaw;

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
        usedAtRaw: row['used_at'] as String?,
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
      // Tapping a row opens the per-status "Participant Actions" sheet
      // (Figma: Participant Management / ParticipantActionsDialog), which
      // surfaces the lifecycle actions that formerly lived in the row's
      // overflow menu.
      onRowTap: (row) => _openActionsDialog(byId[row.id]!, row),
    );
  }

  /// Builds the per-status action list (Figma) — reusing the existing
  /// lifecycle handlers — and shows the "Participant Actions" sheet. A status
  /// with no actions (unknown) opens nothing.
  void _openActionsDialog(
    ParticipantRecordRow record,
    ParticipantRowView row,
  ) {
    final actions = _dialogActionsFor(record, row.status);
    if (actions.isEmpty) return;
    unawaited(
      ParticipantActionsDialog.show(
        context: context,
        participantId: record.id,
        actions: actions,
      ),
    );
  }

  /// The ordered action cards for a row status (Figma:
  /// ParticipantActionsDialog variants). Every linked-or-later state leads
  /// with the code action; lifecycle transitions follow. Each card routes to
  /// the same handler the removed overflow menu used.
  List<ParticipantActionItem> _dialogActionsFor(
    ParticipantRecordRow record,
    ParticipantRowStatus status,
  ) {
    ParticipantActionItem generateCode() => ParticipantActionItem(
      label: 'Generate Linking Code',
      iconAsset: 'assets/icons/participant/link.svg',
      onSelected: () => unawaited(
        LinkParticipantDialog.show(
          context: context,
          participantId: record.id,
          siteId: record.siteId,
        ),
      ),
    );
    ParticipantActionItem regenerateCode() => ParticipantActionItem(
      label: 'Regenerate Code',
      iconAsset: 'assets/icons/participant/refresh.svg',
      onSelected: () => unawaited(
        LinkParticipantDialog.show(
          context: context,
          participantId: record.id,
          siteId: record.siteId,
        ),
      ),
    );
    final showCode = ParticipantActionItem(
      label: 'Show Linking Code',
      iconAsset: 'assets/icons/participant/eye.svg',
      onSelected: () => _showCodeDialog(record),
    );
    final disconnect = ParticipantActionItem(
      label: 'Disconnect Participant',
      iconAsset: 'assets/icons/participant/disconnect.svg',
      destructive: true,
      onSelected: () => _onMenu(record, ParticipantMenuAction.disconnect),
    );
    final reconnect = ParticipantActionItem(
      label: 'Reconnect Participant',
      iconAsset: 'assets/icons/participant/link.svg',
      onSelected: () => _onMenu(record, ParticipantMenuAction.reconnect),
    );
    final markNotParticipating = ParticipantActionItem(
      label: 'Mark as Not Participating',
      iconAsset: 'assets/icons/participant/user_x.svg',
      destructive: true,
      onSelected: () =>
          _onMenu(record, ParticipantMenuAction.markNotParticipating),
    );
    final reactivate = ParticipantActionItem(
      label: 'Reactivate Participant',
      iconAsset: 'assets/icons/participant/reactivate.svg',
      onSelected: () => _onMenu(record, ParticipantMenuAction.reactivate),
    );

    return switch (status) {
      ParticipantRowStatus.notConnected => [generateCode()],
      ParticipantRowStatus.codePending => [showCode],
      ParticipantRowStatus.expired => [regenerateCode(), showCode],
      ParticipantRowStatus.linkedAwaitingStart => [showCode, disconnect],
      ParticipantRowStatus.trialActive => [showCode, disconnect],
      ParticipantRowStatus.disconnected => [
        showCode,
        reconnect,
        markNotParticipating,
      ],
      ParticipantRowStatus.notParticipating => [showCode, reactivate],
      ParticipantRowStatus.unknown => const <ParticipantActionItem>[],
    };
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
          effects: const [
            "Stop data synchronization between the Participant's Mobile "
                'Application and the Sponsor Portal',
            "Continue applying sponsor-specific rules to the Participant's "
                'Mobile Application',
            'Preserve all Participant data and history',
          ],
          reversalNote:
              'This action can be reversed by reconnecting the Participant.',
          confirmLabel: 'Confirm',
          confirmDestructive: true,
          reasonInput: _ReasonInput.dropdown,
          reasonLabel: 'Reason for disconnection',
          reasonOptions: _kDisconnectReasons,
        );
      case ParticipantMenuAction.reconnect:
        _confirmLifecycle(
          record,
          actionName: _kReconnectAction,
          title: 'Reconnect Participant',
          body:
              'Confirming will generate a new Linking Code. The Participant '
              'must enter the new Linking Code to restore the connection. Any '
              'previously issued Linking Code will be invalidated.',
          confirmLabel: 'Confirm',
          reasonInput: _ReasonInput.freeText,
          reasonLabel: 'Reason for reconnection',
          reasonHint: 'Enter reason for reconnecting this Participant...',
          showsCodeOnSuccess: true,
        );
      case ParticipantMenuAction.markNotParticipating:
        _confirmLifecycle(
          record,
          actionName: _kMarkNotParticipatingAction,
          title: 'Mark Participant as Not Participating',
          effects: const [
            'Stop applying sponsor-specific rules to the Mobile Application',
            'Preserve all Participant data and history',
          ],
          reversalNote:
              'This action can be reversed by reactivating the Participant.',
          confirmLabel: 'Confirm',
          confirmDestructive: true,
          reasonInput: _ReasonInput.dropdown,
          reasonLabel: 'Reason for marking as not participating',
          reasonOptions: _kNotParticipatingReasons,
        );
      case ParticipantMenuAction.reactivate:
        _confirmLifecycle(
          record,
          actionName: _kReactivateAction,
          title: 'Reactivate Participant',
          body:
              'Confirming will generate a new Linking Code. The Participant '
              'must enter the new Linking Code to restore the connection. Any '
              'previously issued Linking Code will be invalidated.',
          confirmLabel: 'Confirm',
          reasonInput: _ReasonInput.freeText,
          reasonLabel: 'Reason for reactivation',
          reasonHint: 'Enter reason for reactivating this Participant...',
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
        usedAtRaw: record.usedAtRaw,
        used: used,
        now: _now,
      ),
    );
  }

  void _confirmLifecycle(
    ParticipantRecordRow record, {
    required String actionName,
    required String title,
    String body = '',
    List<String> effects = const <String>[],
    String? reversalNote,
    required String confirmLabel,
    bool confirmDestructive = false,
    _ReasonInput reasonInput = _ReasonInput.none,
    String? reasonLabel,
    String? reasonHint,
    List<String> reasonOptions = const <String>[],
    bool showsCodeOnSuccess = false,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LifecycleActionDialog(
          participantId: record.id,
          actionName: actionName,
          baseInput: <String, Object?>{
            'siteId': record.siteId,
            'participantId': record.id,
          },
          title: title,
          body: body,
          effects: effects,
          reversalNote: reversalNote,
          confirmLabel: confirmLabel,
          confirmDestructive: confirmDestructive,
          reasonInput: reasonInput,
          reasonLabel: reasonLabel,
          reasonHint: reasonHint,
          reasonOptions: reasonOptions,
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
              dismissible: true,
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
      // Figma: the reference-only (used) state shows a single OK; the active
      // code state shows Cancel + Confirm.
      actions: muted
          ? [
              AppButton(
                label: 'OK',
                onPressed: () => Navigator.of(context).pop(),
                semanticId: 'linking-code-confirm-$participantId',
              ),
            ]
          : [
              AppButton(
                variant: AppButtonVariant.secondary,
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
                semanticId: 'linking-code-cancel-$participantId',
              ),
              AppButton(
                label: 'Confirm',
                onPressed: () => Navigator.of(context).pop(),
                semanticId: 'linking-code-confirm-$participantId',
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
  String? usedAtRaw,
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
          ? 'Reference only.${usedOnLabel(usedAtRaw)} This code cannot be '
                'used to establish a new connection.'
          : 'Share this code with the participant to connect their Mobile '
                'Application.',
      footer: used ? '' : expiresInLabel(expiresAtRaw, now),
    ),
  );
}

/// " Used on 20/4/2026 at 12:54." (Figma reference-only Mobile Linking Code
/// dialog) — a leading space so it slots between the "Reference only." and
/// "This code cannot…" sentences. Empty when no redemption timestamp exists.
String usedOnLabel(String? usedAtRaw) {
  final t = usedAtRaw == null ? null : DateTime.tryParse(usedAtRaw);
  if (t == null) return '';
  final local = t.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return ' Used on ${local.day}/${local.month}/${local.year} at $time.';
}

/// Generic lifecycle confirm + dispatch dialog (Disconnect / Reconnect /
/// Mark Not Participating / Reactivate). Captures the mandatory reason — a
/// predefined dropdown or a free-text field per [reasonInput] — and blocks
/// Confirm until it is supplied. The issuing actions surface the regenerated
/// code on success.
///
/// Implements: DIARY-PRD-participant-disconnection/B+C
/// Implements: DIARY-PRD-participant-reconnection/B+C
/// Implements: DIARY-PRD-participant-mark-not-participating/B+C
/// Implements: DIARY-PRD-participant-reactivate/B
class _LifecycleActionDialog extends StatefulWidget {
  const _LifecycleActionDialog({
    required this.participantId,
    required this.actionName,
    required this.baseInput,
    required this.title,
    required this.body,
    required this.effects,
    required this.reversalNote,
    required this.confirmLabel,
    required this.confirmDestructive,
    required this.reasonInput,
    required this.reasonLabel,
    required this.reasonHint,
    required this.reasonOptions,
    required this.showsCodeOnSuccess,
  });

  final String participantId;
  final String actionName;

  /// Identity-only input ({siteId, participantId}); the collected reason is
  /// folded in at submit time.
  final Map<String, Object?> baseInput;

  /// Single-paragraph body (reconnect / reactivate). Ignored when [effects]
  /// is non-empty.
  final String body;

  /// "Effects of this action:" bullet list (disconnect / mark not
  /// participating) — Figma confirm dialogs.
  final List<String> effects;

  /// Trailing reversal note shown under the [effects] list, e.g. "This action
  /// can be reversed by reconnecting the Participant."
  final String? reversalNote;
  final String title;
  final String confirmLabel;

  /// Renders the Confirm button in the Critical palette (disconnect / mark).
  final bool confirmDestructive;
  final _ReasonInput reasonInput;
  final String? reasonLabel;
  final String? reasonHint;
  final List<String> reasonOptions;
  final bool showsCodeOnSuccess;

  @override
  State<_LifecycleActionDialog> createState() => _LifecycleActionDialogState();
}

class _LifecycleActionDialogState extends State<_LifecycleActionDialog> {
  /// Dropdown selection (predefined-list reason).
  String? _selectedReason;

  /// Free-text reason (raw, untrimmed for the live char counter).
  String _typedReason = '';

  /// The reason to dispatch — trimmed; empty when none is required/provided.
  String get _reason => switch (widget.reasonInput) {
    _ReasonInput.dropdown => _selectedReason ?? '',
    _ReasonInput.freeText => _typedReason.trim(),
    _ReasonInput.none => '',
  };

  /// Confirm is enabled only once a non-empty reason is provided (whitespace-
  /// only free text is rejected — DIARY-PRD-reason-field-constraints).
  bool get _reasonSatisfied =>
      widget.reasonInput == _ReasonInput.none || _reason.isNotEmpty;

  Map<String, Object?> _submissionInput() => <String, Object?>{
    ...widget.baseInput,
    if (widget.reasonInput != _ReasonInput.none) 'reason': _reason,
  };

  @override
  Widget build(BuildContext context) {
    return ActionBuilder(
      semanticIdentifier: 'lifecycle-outcome-${widget.participantId}',
      // Read at submit time (ActionBuilder calls this per submit()), so the
      // reason reflects the user's final selection/entry.
      submissionFactory: () => ActionSubmission(
        actionName: widget.actionName,
        rawInput: _submissionInput(),
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
            if (widget.showsCodeOnSuccess && code != null) {
              return _MobileLinkingCodeDialog(
                participantId: widget.participantId,
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
              title: widget.title,
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
              title: widget.title,
              dismissible: false,
              semanticId: 'lifecycle-dialog-${widget.participantId}',
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParticipantIdLine(participantId: widget.participantId),
                  const SizedBox(height: 16),
                  if (widget.effects.isNotEmpty)
                    _EffectsSection(
                      effects: widget.effects,
                      reversalNote: widget.reversalNote,
                    )
                  else if (widget.body.isNotEmpty)
                    Text(widget.body),
                  if (widget.reasonInput != _ReasonInput.none) ...[
                    const SizedBox(height: 16),
                    _reasonField(enabled: !busy),
                  ],
                ],
              ),
              actions: [
                AppButton(
                  variant: AppButtonVariant.secondary,
                  label: 'Cancel',
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                ),
                AppButton(
                  variant: widget.confirmDestructive
                      ? AppButtonVariant.destructive
                      : AppButtonVariant.primary,
                  label: widget.confirmLabel,
                  loading: busy,
                  onPressed: (busy || !_reasonSatisfied) ? null : submit,
                ),
              ],
            );
        }
      },
    );
  }

  /// The reason capture control — a predefined-list dropdown (disconnect /
  /// mark not participating) or a 100-char free-text field (reconnect /
  /// reactivate), matching the Figma confirm dialogs.
  Widget _reasonField({required bool enabled}) => switch (widget.reasonInput) {
    _ReasonInput.dropdown => AppDropdown<String>(
      label: widget.reasonLabel,
      required: true,
      hintText: 'Select a reason',
      enabled: enabled,
      value: _selectedReason,
      semanticId: 'lifecycle-reason-${widget.participantId}',
      items: [
        for (final r in widget.reasonOptions)
          AppDropdownItem<String>(value: r, label: r),
      ],
      onChanged: (v) => setState(() => _selectedReason = v),
    ),
    _ReasonInput.freeText => AppTextField(
      label: widget.reasonLabel,
      hintText: widget.reasonHint,
      required: true,
      enabled: enabled,
      maxLength: _kReasonMaxLength,
      minLines: 2,
      maxLines: 4,
      semanticId: 'lifecycle-reason-${widget.participantId}',
      onChanged: (v) => setState(() => _typedReason = v),
    ),
    _ReasonInput.none => const SizedBox.shrink(),
  };
}

/// "Effects of this action:" heading + disc-bullet list + optional reversal
/// note (Figma: the Disconnect / Mark Not Participating confirm dialogs).
class _EffectsSection extends StatelessWidget {
  const _EffectsSection({required this.effects, required this.reversalNote});

  final List<String> effects;
  final String? reversalNote;

  // Figma confirm-dialog body greys.
  static const Color _heading = Color(0xFF364153);
  static const Color _bodyText = Color(0xFF4A5565);

  @override
  Widget build(BuildContext context) {
    const headingStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: -0.15,
      color: _heading,
    );
    const bulletStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: -0.15,
      color: _bodyText,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Effects of this action:', style: headingStyle),
        const SizedBox(height: 8),
        for (final e in effects)
          Padding(
            padding: EdgeInsets.only(top: e == effects.first ? 0 : 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 5, right: 9, top: 8),
                  child: _Disc(color: _bodyText),
                ),
                Expanded(child: Text(e, style: bulletStyle)),
              ],
            ),
          ),
        if (reversalNote != null) ...[
          const SizedBox(height: 16),
          Text(reversalNote!, style: bulletStyle),
        ],
      ],
    );
  }
}

/// A small list-disc bullet marker.
class _Disc extends StatelessWidget {
  const _Disc({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
