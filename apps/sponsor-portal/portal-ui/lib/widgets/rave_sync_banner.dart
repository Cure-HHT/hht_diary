// Implements: DIARY-GUI-rave-sync-paused-banner/A+B+C

import 'package:flutter/material.dart';

/// Non-dismissible banner shown above Sites and Participants tables when
/// the backend `rave_sync` block reports a paused state.
///
/// Renders nothing when [state] is `'ok'`.
///
/// Copy intentionally stays at the "actionable summary" level — no counters,
/// reason codes, or unwedge identities. Diagnostic detail is Dev-Admin-only
/// on the Dev Admin dashboard's Rave Sync card.
class RaveSyncBanner extends StatelessWidget {
  const RaveSyncBanner({
    super.key,
    required this.state,
    this.pausedUntil,
    this.since,
  });

  /// One of `'ok'`, `'cooldown'`, `'locked'` — matches the backend
  /// `rave_sync.state` field.
  final String state;

  /// For `'cooldown'`: when the soft pause auto-resumes.
  final DateTime? pausedUntil;

  /// For `'locked'`: when the hard lockout started (i.e. how stale the
  /// cached data is).
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    if (state == 'ok') return const SizedBox.shrink();
    final text = state == 'cooldown'
        ? 'Rave sync paused due to a recent auth failure. Showing last-known '
              'data. Sync resumes automatically at '
              '${pausedUntil?.toIso8601String() ?? '?'}.'
        : 'Rave sync paused - contact a Developer Admin to resume. Showing '
              'last-known data from ${since?.toIso8601String() ?? '?'}.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
