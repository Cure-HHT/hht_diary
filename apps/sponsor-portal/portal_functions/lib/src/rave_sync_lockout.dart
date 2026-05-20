// Implements: CAL-OPS-rave-sync-cooldown, CAL-OPS-rave-sync-hard-lockout,
//   CAL-DEV-rave-auth-failure-classification, CAL-OPS-rave-alert-notification
//
// Live decision state for Rave sync lockout. See
// docs/superpowers/specs/2026-05-19-rave-lockout-design.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:otel_common/otel_common.dart';

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

/// Slack alert origin. Probe-path failures suppress the per-failure alert in
/// favor of the Unwedge confirmation alert.
enum AuthFailureSource { normalSync, unwedgeProbe }

/// Increments the consecutive-failure counter and may transition into
/// hard lockout. Always sets last_failure_at (drives cooldown).
/// On lockout-trip, fires both the per-failure Slack alert and the
/// distinct lockout-trip alert. When [source] == unwedgeProbe, the
/// per-failure alert is suppressed.
// Implements: CAL-DEV-rave-auth-failure-classification/A+B+C
// Implements: CAL-OPS-rave-sync-hard-lockout/A
// Implements: CAL-OPS-rave-alert-notification/A+B
Future<void> recordAuthFailure({
  String? reasonCode,
  AuthFailureSource source = AuthFailureSource.normalSync,
}) async {
  final db = Database.instance;
  final threshold = raveAuthFailureThresholdFromEnv(Platform.environment);
  final cooldownHours = raveAuthCooldownHoursFromEnv(Platform.environment);

  final result = await db.executeWithContext(
    '''
    WITH prev AS (
      SELECT locked_at AS prev_locked_at FROM rave_sync_lockout WHERE id = 1
    )
    UPDATE rave_sync_lockout
    SET consecutive_auth_failures = consecutive_auth_failures + 1,
        last_failure_at = now(),
        last_failure_reason_code = @reasonCode,
        locked_at = CASE
          WHEN consecutive_auth_failures + 1 >= @threshold AND locked_at IS NULL THEN now()
          ELSE locked_at
        END,
        updated_at = now()
    FROM prev
    WHERE id = 1
    RETURNING consecutive_auth_failures, locked_at, last_failure_at,
              prev.prev_locked_at
    ''',
    parameters: {'reasonCode': reasonCode, 'threshold': threshold},
    context: UserContext.service,
  );

  if (result.isEmpty) return;
  final counter = result.first[0] as int;
  final lockedAt = result.first[1] as DateTime?;
  final lastFailureAt = result.first[2] as DateTime;
  final prevLockedAt = result.first[3] as DateTime?;
  final justLocked = lockedAt != null && prevLockedAt == null;

  logWithTrace(
    'ERROR',
    'Rave auth failure',
    labels: {
      'rave_auth_failed': 'true',
      'rave_reason_code': reasonCode ?? 'unknown',
      'rave_counter': '$counter',
      'rave_threshold': '$threshold',
      if (justLocked) 'rave_lockout_event': 'locked',
    },
  );

  if (source == AuthFailureSource.normalSync) {
    final cooldownEnd = lastFailureAt.add(Duration(hours: cooldownHours));
    await notifySlack(
      ':rotating_light: [${_envTag()}] Rave auth failed — counter '
      '$counter/$threshold, paused until ${cooldownEnd.toIso8601String()}',
    );
  }
  if (justLocked) {
    await notifySlack(
      ':no_entry: [${_envTag()}] Rave HARD LOCKOUT — manual Unwedge required '
      'from Dev Admin dashboard',
    );
  }
}

/// Resets the counter, sets last_success_at. Does NOT clear locked_at —
/// hard lockout is hard and only cleared by Unwedge.
// Implements: CAL-OPS-rave-sync-cooldown/C
Future<void> recordSyncSuccess() async {
  final db = Database.instance;
  await db.executeWithContext('''
    UPDATE rave_sync_lockout
    SET consecutive_auth_failures = 0,
        last_success_at = now(),
        updated_at = now()
    WHERE id = 1
    ''', context: UserContext.service);
}

/// Fire-and-forget Slack notifier. Reads RAVE_ALERT_SLACK_WEBHOOK per call.
/// When unset, no-op (logs once). Slack failure never throws.
// Implements: CAL-OPS-rave-alert-notification/A+E
Future<void> notifySlack(String text) async {
  final webhook = Platform.environment['RAVE_ALERT_SLACK_WEBHOOK'];
  if (webhook == null || webhook.isEmpty) {
    // ignore: avoid_print
    print(
      '[INFO] RAVE_ALERT_SLACK_WEBHOOK unset — skipping Slack alert: $text',
    );
    return;
  }
  try {
    await http
        .post(
          Uri.parse(webhook),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // ignore: avoid_print
    print('[WARN] Slack notify failed (non-fatal): $e');
  }
}

String _envTag() =>
    Platform.environment['ENVIRONMENT'] ??
    Platform.environment['DEPLOY_ENV'] ??
    'unknown-env';
