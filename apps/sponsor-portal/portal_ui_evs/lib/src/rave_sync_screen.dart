import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

// Read-only status panel over the reactive rave_sync_status view (single row,
// AggregateProjectionSpec on aggregateId 'rave_sync'), gated portal.rave.view_sync.
// The Unwedge button dispatches UnwedgeRaveSyncAction (ACT-OPS-001), gated to the
// SystemOperator-only portal.rave.unwedge permission.
// Implements: DIARY-DEV-rave-edc-ingest/C+D

/// The single rave_sync_status row.
class _RaveStatus {
  const _RaveStatus({
    required this.failures,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastSyncErrorAt,
    this.reasonCode,
    this.lockedAt,
    this.sitesCount,
    this.participantsCount,
  });
  final int failures;
  final String? lastSuccessAt;
  final String? lastFailureAt;
  final String? lastSyncErrorAt;
  final String? reasonCode;
  final String? lockedAt;
  final int? sitesCount;
  final int? participantsCount;

  bool get isLocked => lockedAt != null;

  static _RaveStatus fromRow(Map<String, Object?> r) => _RaveStatus(
    failures: (r['consecutive_auth_failures'] as int?) ?? 0,
    lastSuccessAt: r['last_success_at'] as String?,
    lastFailureAt: r['last_failure_at'] as String?,
    lastSyncErrorAt: r['last_sync_error_at'] as String?,
    reasonCode: r['reason_code'] as String?,
    lockedAt: r['locked_at'] as String?,
    sitesCount: r['sites_count'] as int?,
    participantsCount: r['participants_count'] as int?,
  );
}

class RaveSyncScreen extends StatelessWidget {
  const RaveSyncScreen({super.key});

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: 'portal.rave.view_sync',
    fallback: const Center(
      child: Text("You don't have permission to view RAVE sync status."),
    ),
    child: ViewBuilder<_RaveStatus>(
      viewName: 'rave_sync_status',
      mapper: _RaveStatus.fromRow,
      aggregateIdOf: (_) => 'rave_sync',
      builder: (context, state) {
        final rows = switch (state) {
          Loading<_RaveStatus>() => const <_RaveStatus>[],
          Ready<_RaveStatus>(:final rows) => rows,
          Stale<_RaveStatus>(:final lastRows) => lastRows,
        };
        if (state is Loading<_RaveStatus>) {
          return const Center(child: CircularProgressIndicator());
        }
        // Empty view (no rows yet) reads as a clean OK/empty status.
        final status = rows.isEmpty
            ? const _RaveStatus(failures: 0)
            : rows.first;
        return _StatusPanel(status: status);
      },
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});
  final _RaveStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String banner, Color color) = status.isLocked
        ? ('LOCKED', theme.colorScheme.error)
        : status.failures > 0
        ? ('Cooldown / failures: ${status.failures}', Colors.orange)
        : ('OK', Colors.green);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            banner,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 16),
          Text(
            'Last success: ${status.lastSuccessAt ?? "—"} '
            '(${status.sitesCount ?? 0} sites, '
            '${status.participantsCount ?? 0} participants)',
          ),
          const SizedBox(height: 8),
          Text('Last failure: ${status.lastFailureAt ?? "—"}'),
          const SizedBox(height: 8),
          // Transient (non-lockout) sync errors: network blips / other EDC
          // failures recorded via edc_sync_failed. Separate from the lockout
          // banner, which is driven only by auth failures.
          Text(
            'Last sync error: ${status.lastSyncErrorAt ?? "—"} '
            '(${status.reasonCode ?? ""})',
          ),
          const SizedBox(height: 24),
          // SystemOperator-only manual recovery.
          PermissionGate(
            permission: 'portal.rave.unwedge',
            child: ActionBuilder(
              submissionFactory: () => ActionSubmission(
                actionName: 'ACT-OPS-001',
                rawInput: const <String, Object?>{
                  'reason': 'manual recovery from portal',
                },
              ),
              builder: (context, st, submit) => FilledButton(
                onPressed: st is Submitting ? null : submit,
                child: Text(switch (st) {
                  Submitting() => '...',
                  Denied() => 'Denied',
                  Failed() => 'Failed',
                  _ => 'Unwedge RAVE Sync',
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
