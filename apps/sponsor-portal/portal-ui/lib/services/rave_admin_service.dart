// Service for the Dev Admin Rave Sync card: fetch lockout state and trigger
// an unwedge (test-probe + counter reset) via the portal server.
//
// Wraps the authenticated [ApiClient] singleton used elsewhere in portal-ui
// so callers don't need to know endpoint paths or JSON shapes.

import 'api_client.dart';

/// Snapshot of Rave outbound-sync lockout state, returned by
/// `GET /api/v1/portal/dev-admin/rave/lockout`.
class RaveLockoutState {
  /// One of `ok`, `cooldown`, `locked`.
  final String state;
  final int consecutiveAuthFailures;
  final int threshold;
  final int cooldownHours;
  final DateTime? lockedAt;
  final DateTime? pausedUntil;
  final DateTime? lastFailureAt;
  final String? lastFailureReasonCode;
  final DateTime? lastSuccessAt;
  final String? lastUnwedgedByUserId;
  final DateTime? lastUnwedgedAt;

  RaveLockoutState({
    required this.state,
    required this.consecutiveAuthFailures,
    required this.threshold,
    required this.cooldownHours,
    this.lockedAt,
    this.pausedUntil,
    this.lastFailureAt,
    this.lastFailureReasonCode,
    this.lastSuccessAt,
    this.lastUnwedgedByUserId,
    this.lastUnwedgedAt,
  });

  factory RaveLockoutState.fromJson(Map<String, dynamic> j) {
    return RaveLockoutState(
      state: j['state'] as String,
      consecutiveAuthFailures: (j['consecutive_auth_failures'] as int?) ?? 0,
      threshold: (j['threshold'] as int?) ?? 3,
      cooldownHours: (j['cooldown_hours'] as int?) ?? 24,
      lockedAt: _parseDt(j['locked_at']),
      pausedUntil: _parseDt(j['paused_until']),
      lastFailureAt: _parseDt(j['last_failure_at']),
      lastFailureReasonCode: j['last_failure_reason_code'] as String?,
      lastSuccessAt: _parseDt(j['last_success_at']),
      lastUnwedgedByUserId: j['last_unwedged_by_user_id'] as String?,
      lastUnwedgedAt: _parseDt(j['last_unwedged_at']),
    );
  }

  static DateTime? _parseDt(dynamic v) =>
      v is String ? DateTime.parse(v) : null;
}

/// Result of a Dev-Admin-initiated unwedge attempt, returned by
/// `POST /api/v1/portal/dev-admin/rave/unwedge`.
class UnwedgeResult {
  /// Whether the live test probe against Rave succeeded.
  final bool probeOk;

  /// Error description when [probeOk] is false; null on success.
  final String? probeError;

  /// Counter value after the unwedge attempt resolved.
  final int consecutiveAuthFailures;

  /// True if the lockout was retriggered by the probe failure.
  final bool lockedAfter;

  /// Post-unwedge state: `ok`, `cooldown`, `locked`, or `unknown` if the
  /// state read failed after the clear committed.
  final String stateAfter;

  /// Populated when [stateAfter] is `cooldown`.
  final DateTime? pausedUntil;

  UnwedgeResult({
    required this.probeOk,
    required this.consecutiveAuthFailures,
    required this.lockedAfter,
    required this.stateAfter,
    this.probeError,
    this.pausedUntil,
  });

  factory UnwedgeResult.fromJson(Map<String, dynamic> j) {
    final probe = (j['probe'] as Map).cast<String, dynamic>();
    final stateAfter = (j['state_after'] as Map).cast<String, dynamic>();
    final pausedUntilRaw = stateAfter['paused_until'];
    return UnwedgeResult(
      probeOk: probe['ok'] as bool,
      probeError: probe['error'] as String?,
      consecutiveAuthFailures: stateAfter['consecutive_auth_failures'] as int,
      lockedAfter: stateAfter['locked'] as bool,
      stateAfter: (stateAfter['state'] as String?) ?? 'unknown',
      pausedUntil: pausedUntilRaw is String
          ? DateTime.tryParse(pausedUntilRaw)
          : null,
    );
  }
}

/// Thin wrapper around [ApiClient] that exposes the Dev Admin Rave Sync
/// endpoints as typed methods.
// Implements: DIARY-GUI-dev-admin-rave-sync-card/A+B
class RaveAdminService {
  final ApiClient _api;

  RaveAdminService(this._api);

  /// Fetch the current Rave sync lockout state.
  /// Throws [RaveAdminException] on non-2xx or transport errors.
  Future<RaveLockoutState> getState() async {
    final response = await _api.get('/api/v1/portal/dev-admin/rave/lockout');
    if (!response.isSuccess) {
      throw RaveAdminException(
        response.error ?? 'Failed to load Rave sync state',
        statusCode: response.statusCode,
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw RaveAdminException(
        'Unexpected response shape from lockout endpoint',
        statusCode: response.statusCode,
      );
    }
    return RaveLockoutState.fromJson(data.cast<String, dynamic>());
  }

  /// Attempt a Dev-Admin-initiated unwedge: posts to the unwedge endpoint,
  /// which runs a live probe and (if successful) resets the failure counter.
  /// Throws [RaveAdminException] on non-2xx or transport errors.
  Future<UnwedgeResult> unwedge() async {
    final response = await _api.post(
      '/api/v1/portal/dev-admin/rave/unwedge',
      const {},
    );
    if (!response.isSuccess) {
      throw RaveAdminException(
        response.error ?? 'Unwedge request failed',
        statusCode: response.statusCode,
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw RaveAdminException(
        'Unexpected response shape from unwedge endpoint',
        statusCode: response.statusCode,
      );
    }
    return UnwedgeResult.fromJson(data.cast<String, dynamic>());
  }
}

/// Exception type for [RaveAdminService] failures, carrying the HTTP status
/// when one is available (transport errors will surface as 500).
class RaveAdminException implements Exception {
  final String message;
  final int statusCode;

  RaveAdminException(this.message, {required this.statusCode});

  @override
  String toString() => 'RaveAdminException($statusCode): $message';
}
