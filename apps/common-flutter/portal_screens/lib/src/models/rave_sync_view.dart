import 'package:flutter/foundation.dart';

/// Overall health of the RAVE/EDC sync, derived from the rave_sync_status row.
enum RaveSyncHealth {
  /// No failures — syncing normally.
  ok('Sync healthy'),

  /// Consecutive auth failures below the lockout threshold (cooldown window).
  cooldown('Cooldown — recent auth failures'),

  /// Hard lockout — sync is wedged and needs a manual Unwedge.
  locked('Locked — sync is wedged');

  const RaveSyncHealth(this.label);
  final String label;
}

/// Snapshot of the single rave_sync_status row for the RAVE Sync page. The
/// wiring layer maps the reactive view row into this; timestamps are passed
/// through as the row's strings (null → rendered as an em-dash).
@immutable
class RaveSyncView {
  const RaveSyncView({
    required this.health,
    this.consecutiveAuthFailures = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastSyncErrorAt,
    this.reasonCode,
    this.sitesCount,
    this.participantsCount,
  });

  final RaveSyncHealth health;
  final int consecutiveAuthFailures;
  final String? lastSuccessAt;
  final String? lastFailureAt;
  final String? lastSyncErrorAt;
  final String? reasonCode;
  final int? sitesCount;
  final int? participantsCount;
}
