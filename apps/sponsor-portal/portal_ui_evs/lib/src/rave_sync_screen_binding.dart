import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

// Reactive wiring for the redesigned RAVE Sync page: subscribes to the
// single-row rave_sync_status view (AggregateProjectionSpec on aggregateId
// 'rave_sync'), maps it to a RaveSyncView, and routes the SystemOperator-only
// Unwedge (ACT-OPS-001, portal.rave.unwedge) through an ActionBuilder.
//
// Implements: DIARY-DEV-rave-edc-ingest/C+D

const String _viewPerm = 'portal.rave.view_sync';
const String _unwedgePerm = 'portal.rave.unwedge';
const String _kUnwedgeAction = 'ACT-OPS-001'; // {reason}

/// Maps a rave_sync_status row to the presentation [RaveSyncView]. A hard
/// lockout (locked_at set) wins; otherwise any consecutive auth failures read
/// as cooldown; otherwise healthy.
RaveSyncView raveSyncFromRow(Map<String, Object?> r) {
  final failures = (r['consecutive_auth_failures'] as int?) ?? 0;
  final lockedAt = r['locked_at'] as String?;
  final health = lockedAt != null
      ? RaveSyncHealth.locked
      : failures > 0
      ? RaveSyncHealth.cooldown
      : RaveSyncHealth.ok;
  return RaveSyncView(
    health: health,
    consecutiveAuthFailures: failures,
    lastSuccessAt: r['last_success_at'] as String?,
    lastFailureAt: r['last_failure_at'] as String?,
    lastSyncErrorAt: r['last_sync_error_at'] as String?,
    reasonCode: r['reason_code'] as String?,
    sitesCount: r['sites_count'] as int?,
    participantsCount: r['participants_count'] as int?,
  );
}

class RaveSyncScreenBinding extends StatelessWidget {
  const RaveSyncScreenBinding({super.key});

  /// Permission a role must hold to see the RAVE Sync tab + status.
  static const String viewPermission = _viewPerm;

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: _viewPerm,
    fallback: const Center(
      child: Text("You don't have permission to view RAVE sync status."),
    ),
    child: ViewBuilder<RaveSyncView>(
      viewName: 'rave_sync_status',
      mapper: raveSyncFromRow,
      aggregateIdOf: (_) => 'rave_sync',
      builder: (context, state) {
        final rows = switch (state) {
          Loading<RaveSyncView>() => const <RaveSyncView>[],
          Ready<RaveSyncView>(:final rows) => rows,
          Stale<RaveSyncView>(:final lastRows) => lastRows,
        };
        // Empty view (no row yet) → the screen treats null as healthy.
        final status = rows.isEmpty ? null : rows.first;
        final isLoading = state is Loading<RaveSyncView>;
        // Unwedge is SystemOperator-only: without the permission the screen
        // renders read-only (no button); with it, an ActionBuilder drives the
        // dispatch + in-flight state.
        return PermissionGate(
          permission: _unwedgePerm,
          fallback: RaveSyncScreen(status: status, isLoading: isLoading),
          child: ActionBuilder(
            semanticIdentifier: 'rave-unwedge-outcome',
            submissionFactory: () => ActionSubmission(
              actionName: _kUnwedgeAction,
              rawInput: const <String, Object?>{
                'reason': 'manual recovery from portal',
              },
            ),
            builder: (context, actionState, submit) {
              final busy = actionState is Submitting;
              return RaveSyncScreen(
                status: status,
                isLoading: isLoading,
                onUnwedge: busy ? null : submit,
                unwedging: busy,
              );
            },
          ),
        );
      },
    ),
  );
}
