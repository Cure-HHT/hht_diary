// Implements: DIARY-DEV-rave-edc-ingest/C+D — pure lockout decision over the
//   rave_sync_status projection row, ported from the legacy classifyLockout. Threshold
//   + cooldown are env-configurable (per-env counters per the shared-cred model).

enum LockoutKind { proceed, cooldown, locked }

class LockoutConfig {
  const LockoutConfig({required this.threshold, required this.cooldown});
  final int threshold;
  final Duration cooldown;

  factory LockoutConfig.fromEnv(Map<String, String> env) {
    final threshold =
        int.tryParse(env['RAVE_AUTH_FAILURE_THRESHOLD'] ?? '') ?? 3;
    final mins = double.tryParse(env['RAVE_AUTH_COOLDOWN_MINUTES'] ?? '');
    final hours = double.tryParse(env['RAVE_AUTH_COOLDOWN_HOURS'] ?? '');
    final cooldown = mins != null
        ? Duration(milliseconds: (mins * 60000).round())
        : hours != null
        ? Duration(milliseconds: (hours * 3600000).round())
        : const Duration(hours: 24);
    return LockoutConfig(threshold: threshold, cooldown: cooldown);
  }
}

class LockoutDecision {
  const LockoutDecision(this.kind, {this.cooldownUntil});
  final LockoutKind kind;
  final DateTime? cooldownUntil;
}

DateTime? _ts(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;

LockoutDecision classifyLockout(
  Map<String, Object?> row, {
  required DateTime now,
  required LockoutConfig config,
}) {
  final failures = (row['consecutive_auth_failures'] as int?) ?? 0;
  final lastFailure = _ts(row['last_failure_at']);
  final lastSuccess = _ts(row['last_success_at']);

  // Legacy semantics: any success at-or-after the last failure supersedes it
  // (the Unwedge probe records a success that clears the pause).
  final supersededBySuccess =
      lastSuccess != null &&
      (lastFailure == null || !lastSuccess.isBefore(lastFailure));

  if (failures >= config.threshold && !supersededBySuccess) {
    return const LockoutDecision(LockoutKind.locked);
  }
  if (!supersededBySuccess && lastFailure != null) {
    final until = lastFailure.add(config.cooldown);
    if (until.isAfter(now)) {
      return LockoutDecision(LockoutKind.cooldown, cooldownUntil: until);
    }
  }
  return const LockoutDecision(LockoutKind.proceed);
}
