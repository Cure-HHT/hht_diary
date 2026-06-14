import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/rave_sync_view.dart';

/// RAVE Sync status page — read-only health of the EDC synchronization, with
/// a SystemOperator-only manual "Unwedge" recovery.
///
/// **Snapshot in, callbacks out.** The wiring layer (`portal_ui_evs`)
/// subscribes to `rave_sync_status` and maps the row to [status]; the Unwedge
/// affordance renders only when [onUnwedge] is non-null (the viewer holds
/// `portal.rave.unwedge`), and [unwedging] drives its in-flight state.
class RaveSyncScreen extends StatelessWidget {
  const RaveSyncScreen({
    super.key,
    required this.status,
    required this.isLoading,
    this.onUnwedge,
    this.unwedging = false,
  });

  /// Current sync status, or null while the first projection emission is
  /// pending (renders the loading state).
  final RaveSyncView? status;

  /// True until the wiring layer's first emission.
  final bool isLoading;

  /// Fired when the SystemOperator taps Unwedge. Null hides the button
  /// (viewer lacks `portal.rave.unwedge`).
  final VoidCallback? onUnwedge;

  /// True while an Unwedge dispatch is in flight (disables + spins the button).
  final bool unwedging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'rave-sync-screen',
      container: true,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 24),
            if (isLoading && status == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _Body(
                // An empty view (no row yet) reads as a clean healthy status.
                status: status ?? const RaveSyncView(health: RaveSyncHealth.ok),
                onUnwedge: onUnwedge,
                unwedging: unwedging,
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RAVE Sync',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            height: 32 / 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Monitor EDC synchronization status for this study.',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.status,
    required this.onUnwedge,
    required this.unwedging,
    required this.theme,
  });

  final RaveSyncView status;
  final VoidCallback? onUnwedge;
  final bool unwedging;
  final ThemeData theme;

  String _orDash(String? v) => (v == null || v.isEmpty) ? '—' : v;

  @override
  Widget build(BuildContext context) {
    final severity = switch (status.health) {
      RaveSyncHealth.ok => AppBannerSeverity.success,
      RaveSyncHealth.cooldown => AppBannerSeverity.warning,
      RaveSyncHealth.locked => AppBannerSeverity.error,
    };
    final lastSuccess = status.sitesCount != null
        ? '${_orDash(status.lastSuccessAt)}  '
              '(${status.sitesCount ?? 0} sites, '
              '${status.participantsCount ?? 0} participants)'
        : _orDash(status.lastSuccessAt);
    final lastSyncError = status.reasonCode != null
        ? '${_orDash(status.lastSyncErrorAt)}  (${status.reasonCode})'
        : _orDash(status.lastSyncErrorAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          severity: severity,
          message: status.health.label,
          semanticId: 'rave-sync-health',
        ),
        const SizedBox(height: 16),
        AppCard(
          title: 'Sync Status',
          semanticId: 'rave-sync-card',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInfoRow(
                label: 'Last successful sync',
                value: lastSuccess,
                labelWidth: 200,
                semanticId: 'rave-last-success',
              ),
              AppInfoRow(
                label: 'Last failure',
                value: _orDash(status.lastFailureAt),
                labelWidth: 200,
                semanticId: 'rave-last-failure',
              ),
              AppInfoRow(
                label: 'Last sync error',
                value: lastSyncError,
                labelWidth: 200,
                semanticId: 'rave-last-sync-error',
              ),
              AppInfoRow(
                label: 'Consecutive auth failures',
                value: '${status.consecutiveAuthFailures}',
                labelWidth: 200,
                semanticId: 'rave-auth-failures',
              ),
            ],
          ),
        ),
        if (onUnwedge != null) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Unwedge RAVE Sync',
              variant: AppButtonVariant.secondary,
              leadingIcon: Icons.lock_open_outlined,
              loading: unwedging,
              onPressed: unwedging ? null : onUnwedge,
              semanticId: 'rave-unwedge',
            ),
          ),
        ],
      ],
    );
  }
}
