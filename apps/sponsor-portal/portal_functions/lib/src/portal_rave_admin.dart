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
  if (user == null) return _json({'error': 'Unauthorized'}, 403);
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
  if (user == null) return _json({'error': 'Unauthorized'}, 403);
  if (!user.isDeveloperAdmin) return _json({'error': 'Forbidden'}, 403);

  final db = Database.instance;
  // Step 1: atomic clear.
  await db.executeWithContext(
    '''
    UPDATE rave_sync_lockout
    SET consecutive_auth_failures = 0,
        locked_at = NULL,
        last_unwedged_by_user_id = @userId::uuid,
        last_unwedged_at = now(),
        updated_at = now()
    WHERE id = 1
    ''',
    parameters: {'userId': user.id},
    context: UserContext.service,
  );

  // Step 2: probe with one sync. Bypasses checkLockout (calls FromEdc
  // directly). recordAuthFailure inside FromEdc is invoked via the
  // unwedge-probe path, suppressing the per-failure Slack alert.
  final probeResult = await syncSitesFromEdc(
    authFailureSource: AuthFailureSource.unwedgeProbe,
  );

  // Step 3: write a dedicated UNWEDGE row to edc_sync_log for history.
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
        'probe_ok': !probeResult.hasError,
        if (probeResult.hasError) 'probe_error': probeResult.error,
      }),
    },
    context: UserContext.service,
  );

  logWithTrace(
    'INFO',
    'Rave unwedged',
    labels: {
      'rave_lockout_event': 'unwedged',
      'user_id': user.id,
      'probe_ok': '${!probeResult.hasError}',
    },
  );

  // Slack confirmation. Probe-fail case: the per-failure Slack alert was
  // suppressed by syncSitesFromEdc using AuthFailureSource.unwedgeProbe.
  final probeText = probeResult.hasError ? 'FAIL: ${probeResult.error}' : 'OK';
  await notifySlack(
    ':white_check_mark: [${Platform.environment['ENVIRONMENT'] ?? 'unknown-env'}] '
    'Rave unwedged by ${user.email} — probe $probeText',
  );

  final stateAfter = await checkLockout();
  return _json({
    'unwedged_at': DateTime.now().toUtc().toIso8601String(),
    'probe': {
      'ok': !probeResult.hasError,
      if (probeResult.hasError) 'error': probeResult.error,
    },
    'state_after': {
      'consecutive_auth_failures': stateAfter.row.consecutiveAuthFailures,
      'locked': stateAfter.row.lockedAt != null,
      'last_success_at': stateAfter.row.lastSuccessAt?.toIso8601String(),
    },
  });
}
