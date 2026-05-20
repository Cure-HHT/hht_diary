// Implements: CAL-OPS-rave-sync-cooldown, CAL-OPS-rave-sync-hard-lockout,
//   CAL-DEV-rave-auth-failure-classification, CAL-OPS-rave-alert-notification
//
// Live decision state for Rave sync lockout. See
// docs/superpowers/specs/2026-05-19-rave-lockout-design.md.

import 'dart:async';
import 'dart:io';

import 'database.dart';

const int _defaultThreshold = 3;
const int _defaultCooldownHours = 24;

/// Reads RAVE_AUTH_FAILURE_THRESHOLD with a default of 3.
/// Non-numeric values fall back to the default with a warning log.
// Implements: CAL-OPS-rave-sync-hard-lockout/A
int raveAuthFailureThresholdFromEnv(Map<String, String> env) {
  final raw = env['RAVE_AUTH_FAILURE_THRESHOLD'];
  if (raw == null || raw.isEmpty) return _defaultThreshold;
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1) {
    // ignore: avoid_print
    print(
      '[WARN] RAVE_AUTH_FAILURE_THRESHOLD=$raw is not a positive integer; '
      'falling back to $_defaultThreshold',
    );
    return _defaultThreshold;
  }
  return parsed;
}

/// Reads RAVE_AUTH_COOLDOWN_HOURS with a default of 24.
// Implements: CAL-OPS-rave-sync-cooldown/B
int raveAuthCooldownHoursFromEnv(Map<String, String> env) {
  final raw = env['RAVE_AUTH_COOLDOWN_HOURS'];
  if (raw == null || raw.isEmpty) return _defaultCooldownHours;
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 1) {
    // ignore: avoid_print
    print(
      '[WARN] RAVE_AUTH_COOLDOWN_HOURS=$raw is not a positive integer; '
      'falling back to $_defaultCooldownHours',
    );
    return _defaultCooldownHours;
  }
  return parsed;
}

enum LockoutCheckResult { proceed, pausedCooldown, pausedLocked }

/// Snapshot of the single rave_sync_lockout row.
class RaveLockoutRow {
  final int consecutiveAuthFailures;
  final DateTime? lockedAt;
  final DateTime? lastFailureAt;
  final String? lastFailureReasonCode;
  final DateTime? lastSuccessAt;
  final String? lastUnwedgedByUserId;
  final DateTime? lastUnwedgedAt;

  const RaveLockoutRow({
    this.consecutiveAuthFailures = 0,
    this.lockedAt,
    this.lastFailureAt,
    this.lastFailureReasonCode,
    this.lastSuccessAt,
    this.lastUnwedgedByUserId,
    this.lastUnwedgedAt,
  });
}

class LockoutState {
  final LockoutCheckResult result;
  final DateTime? pausedUntil;
  final DateTime? lockedAt;
  final int consecutiveAuthFailures;
  final RaveLockoutRow row;

  const LockoutState({
    required this.result,
    required this.row,
    this.pausedUntil,
    this.lockedAt,
    this.consecutiveAuthFailures = 0,
  });

  bool get isPaused => result != LockoutCheckResult.proceed;
}

/// Pure classifier: given a row snapshot, decide if sync is allowed.
/// Tested directly; the live `checkLockout` is a thin DB wrapper around this.
// Implements: CAL-OPS-rave-sync-cooldown/D, CAL-OPS-rave-sync-hard-lockout/B
LockoutState classifyLockout({
  required RaveLockoutRow row,
  required int cooldownHours,
  required DateTime now,
}) {
  if (row.lockedAt != null) {
    return LockoutState(
      result: LockoutCheckResult.pausedLocked,
      lockedAt: row.lockedAt,
      consecutiveAuthFailures: row.consecutiveAuthFailures,
      row: row,
    );
  }
  final lastFail = row.lastFailureAt;
  if (lastFail != null) {
    final cooldownEnd = lastFail.add(Duration(hours: cooldownHours));
    if (cooldownEnd.isAfter(now)) {
      return LockoutState(
        result: LockoutCheckResult.pausedCooldown,
        pausedUntil: cooldownEnd,
        consecutiveAuthFailures: row.consecutiveAuthFailures,
        row: row,
      );
    }
  }
  return LockoutState(
    result: LockoutCheckResult.proceed,
    consecutiveAuthFailures: row.consecutiveAuthFailures,
    row: row,
  );
}

/// Reads the singleton row from rave_sync_lockout and classifies it.
Future<LockoutState> checkLockout() async {
  final db = Database.instance;
  final result = await db.executeWithContext('''
    SELECT consecutive_auth_failures, locked_at, last_failure_at,
           last_failure_reason_code, last_success_at,
           last_unwedged_by_user_id::text, last_unwedged_at
    FROM rave_sync_lockout WHERE id = 1
    ''', context: UserContext.service);
  if (result.isEmpty) {
    // Should not happen — migration seeds the row. Defensive: treat as clean.
    return const LockoutState(
      result: LockoutCheckResult.proceed,
      row: RaveLockoutRow(),
    );
  }
  final r = result.first;
  final row = RaveLockoutRow(
    consecutiveAuthFailures: r[0] as int,
    lockedAt: r[1] as DateTime?,
    lastFailureAt: r[2] as DateTime?,
    lastFailureReasonCode: r[3] as String?,
    lastSuccessAt: r[4] as DateTime?,
    lastUnwedgedByUserId: r[5] as String?,
    lastUnwedgedAt: r[6] as DateTime?,
  );
  return classifyLockout(
    row: row,
    cooldownHours: raveAuthCooldownHoursFromEnv(Platform.environment),
    now: DateTime.now().toUtc(),
  );
}
