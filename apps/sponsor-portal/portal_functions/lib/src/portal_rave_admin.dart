// Developer Admin endpoints for the Rave sync lockout feature. Per-handler
// `// Implements:` annotations cite specific assertions; no file-header
// IMPLEMENTS block per CLAUDE.md §1.

import 'dart:async';
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

/// Builds the Slack confirmation alert text fired by unwedgeRaveHandler.
/// Pure — extracted so unit tests can assert on env tag, operator email,
/// and probe outcome formatting without a webhook stub.
// Implements: DIARY-OPS-rave-alert-notification/C+D
String buildUnwedgeConfirmationSlackMessage({
  required String env,
  required String userEmail,
  required bool probeOk,
  String? probeError,
}) {
  // Use distinct leading emoji so an operator scanning the channel can tell
  // success vs failure at a glance, without parsing the full message body.
  final emoji = probeOk ? ':white_check_mark:' : ':x:';
  final probeText = probeOk ? 'OK' : 'FAIL: ${probeError ?? "unknown"}';
  return '$emoji [$env] Rave unwedged by $userEmail — probe $probeText';
}

/// Renders the `rave_sync` block embedded in /sites and /participants
/// responses. Reads current lockout state.
// Implements: DIARY-GUI-rave-sync-paused-banner/A
Future<Map<String, dynamic>> buildRaveSyncBlock() async {
  final state = await checkLockout();
  return {
    'state': switch (state.result) {
      LockoutCheckResult.proceed => 'ok',
      LockoutCheckResult.pausedCooldown => 'cooldown',
      LockoutCheckResult.pausedLocked => 'locked',
    },
    if (state.row.lockedAt != null)
      'since': state.row.lockedAt!.toIso8601String(),
    if (state.pausedUntil != null)
      'paused_until': state.pausedUntil!.toIso8601String(),
  };
}

/// GET /api/v1/portal/dev-admin/rave/lockout
// Implements: DIARY-GUI-dev-admin-rave-sync-card/A
Future<Response> getRaveLockoutStateHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) return _json({'error': 'Unauthorized'}, 401);
  if (!user.isDeveloperAdmin) return _json({'error': 'Forbidden'}, 403);

  final state = await checkLockout();
  return _json({
    'threshold': raveAuthFailureThresholdFromEnv(Platform.environment),
    // Wire as seconds (integer) — the UI formats smartly. Allows
    // sub-hour cooldowns (RAVE_AUTH_COOLDOWN_MINUTES) without losing
    // precision in the JSON transit.
    'cooldown_seconds': raveAuthCooldownFromEnv(Platform.environment).inSeconds,
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
// Implements: DIARY-OPS-rave-unwedge-authz/A+B, DIARY-OPS-rave-alert-notification/C
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
        'unwedge', 0, @success, @errorMessage, @metadata::jsonb
      )
      ''',
      parameters: {
        'success': probeOk,
        'errorMessage': probeOk ? null : probeError,
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
  // Fire-and-forget (DIARY-OPS-rave-alert-notification/E): notifySlackWith
  // swallows its own failures internally, but the 5s timeout MUST NOT add
  // tail latency to the HTTP response. On Cloud Run the isolate stays
  // alive after the response so the background send completes.
  unawaited(
    notifySlack(
      buildUnwedgeConfirmationSlackMessage(
        env: raveEnvTag(),
        userEmail: user.email,
        probeOk: probeOk,
        probeError: probeError,
      ),
    ),
  );

  // Best-effort state fetch. If this throws we still return a useful
  // response: the clear committed, the timestamp is DB-authoritative,
  // and probe outcome is known.
  LockoutState? stateAfter;
  try {
    stateAfter = await checkLockout();
  } catch (e) {
    // ignore: avoid_print
    print('[WARN] Failed to fetch state_after for unwedge response: $e');
  }
  final rowAfter = stateAfter?.row;
  final stateAfterName = switch (stateAfter?.result) {
    LockoutCheckResult.proceed => 'ok',
    LockoutCheckResult.pausedCooldown => 'cooldown',
    LockoutCheckResult.pausedLocked => 'locked',
    null => 'unknown',
  };

  return _json({
    'unwedged_at': (dbUnwedgedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'probe': {'ok': probeOk, if (!probeOk) 'error': probeError},
    'state_after': {
      'state': stateAfterName,
      'consecutive_auth_failures': rowAfter?.consecutiveAuthFailures ?? 0,
      'locked': rowAfter?.lockedAt != null,
      if (stateAfter?.pausedUntil != null)
        'paused_until': stateAfter!.pausedUntil!.toIso8601String(),
      'last_success_at': rowAfter?.lastSuccessAt?.toIso8601String(),
    },
  });
}
