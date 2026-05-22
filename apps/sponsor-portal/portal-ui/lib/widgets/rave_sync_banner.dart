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
    final text = switch (state) {
      'ok' => null, // No banner.
      'cooldown' => _cooldownText(pausedUntil),
      'locked' => _lockedText(since),
      _ => null, // Unknown state: render nothing rather than misleading copy.
    };
    if (text == null) return const SizedBox.shrink();
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

  static String _cooldownText(DateTime? pausedUntil) {
    const base =
        'Rave sync paused due to a recent auth failure. Showing '
        'last-known data.';
    if (pausedUntil == null) {
      return '$base Sync will resume automatically.';
    }
    return '$base Sync resumes automatically at '
        '${pausedUntil.toIso8601String()}.';
  }

  static String _lockedText(DateTime? since) {
    const base =
        'Rave sync paused - contact a Developer Admin to resume. '
        'Showing last-known data';
    if (since == null) {
      return '$base.';
    }
    return '$base from ${since.toIso8601String()}.';
  }
}
