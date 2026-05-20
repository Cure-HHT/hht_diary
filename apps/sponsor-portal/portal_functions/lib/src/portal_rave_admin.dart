// Implements: CAL-OPS-rave-unwedge-authz, CAL-OPS-rave-alert-notification/C
//
// Developer Admin endpoints for the Rave sync lockout feature.

import 'dart:convert';
import 'dart:io';

import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'portal_auth.dart';
import 'rave_sync_lockout.dart';
import 'sites_sync.dart';

Response _json(Map<String, dynamic> body, [int status = 200]) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

/// GET /api/v1/portal/dev-admin/rave/lockout
// Implements: CAL-GUI-dev-admin-rave-sync-card/A
Future<Response> getRaveLockoutStateHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) return _json({'error': 'Unauthorized'}, 401);
  if (!user.isDeveloperAdmin) return _json({'error': 'Forbidden'}, 403);

  final state = await checkLockout();
  return _json({
    'threshold': raveAuthFailureThresholdFromEnv(Platform.environment),
    'cooldown_hours': raveAuthCooldownHoursFromEnv(Platform.environment),
    'state': switch (state.result) {
      LockoutCheckResult.proceed => 'ok',
      LockoutCheckResult.pausedCooldown => 'cooldown',
      LockoutCheckResult.pausedLocked => 'locked',
    },
    'consecutive_auth_failures': state.row.consecutiveAuthFailures,
    'locked_at': state.row.lockedAt?.toIso8601String(),
    'paused_until': state.pausedUntil?.toIso8601String(),
    'last_failure_at': state.row.lastFailureAt?.toIso8601String(),
    'last_failure_reason_code': state.row.lastFailureReasonCode,
    'last_success_at': state.row.lastSuccessAt?.toIso8601String(),
    'last_unwedged_by_user_id': state.row.lastUnwedgedByUserId,
    'last_unwedged_at': state.row.lastUnwedgedAt?.toIso8601String(),
  });
}

/// POST /api/v1/portal/dev-admin/rave/unwedge
// Implements: CAL-OPS-rave-unwedge-authz/A+B, CAL-OPS-rave-alert-notification/C
Future<Response> unwedgeRaveHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) return _json({'error': 'Unauthorized'}, 401);
  if (!user.isDeveloperAdmin) return _json({'error': 'Forbidden'}, 403);

  final db = Database.instance;

  // Step 1: atomic clear. RETURNING last_unwedged_at so the response uses
  // the DB-authoritative timestamp (matches what GET /lockout will read on
  // subsequent calls).
  DateTime? dbUnwedgedAt;
  final clearResult = await db.executeWithContext(
    '''
    UPDATE rave_sync_lockout
    SET consecutive_auth_failures = 0,
        locked_at = NULL,
        last_unwedged_by_user_id = @userId::uuid,
        last_unwedged_at = now(),
        updated_at = now()
    WHERE id = 1
    RETURNING last_unwedged_at
    ''',
    parameters: {'userId': user.id},
    context: UserContext.service,
  );
  if (clearResult.isNotEmpty) {
    dbUnwedgedAt = clearResult.first[0] as DateTime?;
  }

  // Step 2: probe with one sync. Bypasses checkLockout (calls FromEdc
  // directly). recordAuthFailure inside FromEdc is invoked via the
  // unwedge-probe path, suppressing the per-failure Slack alert.
  //
  // The probe call already returns SitesSyncResult with hasError for
  // expected Rave failures, but defensively wrap for non-Rave throws
  // (DNS, DB write failing inside _logSyncResult, etc.) so the clear
  // we just committed cannot be left without an audit row / Slack alert /
  // HTTP response.
  SitesSyncResult? probeResult;
  String? probeException;
  try {
    probeResult = await syncSitesFromEdc(
      authFailureSource: AuthFailureSource.unwedgeProbe,
    );
  } catch (e) {
    probeException = e.toString();
    // ignore: avoid_print
    print('[WARN] Unwedge probe threw: $e');
  }
  final probeOk = probeResult != null && !probeResult.hasError;
  final probeError = probeException ?? probeResult?.error;

  // Step 3: always write a dedicated UNWEDGE row to edc_sync_log for
  // history — even on probe exception. Wrapped so a transient DB error
  // here doesn't drop the response (clear already committed).
  try {
    await db.executeWithContext(
      '''
      INSERT INTO edc_sync_log (
        sync_timestamp, source_system, operation,
        sites_created, sites_updated, sites_deactivated,
        content_hash, duration_ms, success, error_message, metadata
      ) VALUES (
        now(), 'RAVE', 'UNWEDGE',
        0, 0, 0,
        'unwedge', 0, true, NULL, @metadata::jsonb
      )
      ''',
      parameters: {
        'metadata': jsonEncode({
          'triggered_by': 'unwedge',
          'unwedged_by_user_id': user.id,
          'probe_ok': probeOk,
          if (!probeOk) 'probe_error': probeError,
        }),
      },
      context: UserContext.service,
    );
  } catch (e) {
    // ignore: avoid_print
    print('[WARN] Failed to write UNWEDGE audit row: $e');
  }

  logWithTrace(
    'INFO',
    'Rave unwedged',
    labels: {
      'rave_lockout_event': 'unwedged',
      'user_id': user.id,
      'probe_ok': '$probeOk',
    },
  );

  // Slack confirmation. Probe-fail case: the per-failure Slack alert was
  // suppressed by syncSitesFromEdc using AuthFailureSource.unwedgeProbe.
  // notifySlack swallows its own failures internally — safe to await
  // without an outer try.
  final probeText = probeOk ? 'OK' : 'FAIL: ${probeError ?? "unknown"}';
  await notifySlack(
    ':white_check_mark: [${raveEnvTag()}] '
    'Rave unwedged by ${user.email} — probe $probeText',
  );

  // Best-effort state fetch. If this throws we still return a useful
  // response: the clear committed, the timestamp is DB-authoritative,
  // and probe outcome is known.
  RaveLockoutRow? rowAfter;
  try {
    final stateAfter = await checkLockout();
    rowAfter = stateAfter.row;
  } catch (e) {
    // ignore: avoid_print
    print('[WARN] Failed to fetch state_after for unwedge response: $e');
  }

  return _json({
    'unwedged_at': (dbUnwedgedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'probe': {'ok': probeOk, if (!probeOk) 'error': probeError},
    'state_after': {
      'consecutive_auth_failures': rowAfter?.consecutiveAuthFailures ?? 0,
      'locked': rowAfter?.lockedAt != null,
      'last_success_at': rowAfter?.lastSuccessAt?.toIso8601String(),
    },
  });
}
