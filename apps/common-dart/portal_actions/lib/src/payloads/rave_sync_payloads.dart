// Implements: DIARY-DEV-rave-edc-ingest/C — data builders for the rave_sync lockout
//   events. Every counter-affecting event carries the authoritative
//   consecutive_auth_failures value so the AggregateProjectionSpec key-wise merge
//   yields a correct running counter (0 on success).
Map<String, Object?> edcSyncSucceededData({
  required int sitesCount,
  required int participantsCount,
  required String lastSuccessAt,
}) => <String, Object?>{
  'consecutive_auth_failures': 0,
  'sites_count': sitesCount,
  'participants_count': participantsCount,
  'last_success_at': lastSuccessAt,
  // Clear any hard lockout on a successful sync (null-as-clear merge).
  'locked_at': null,
};

Map<String, Object?> raveAuthFailedData({
  required int consecutiveAuthFailures,
  required String reasonCode,
  required String failedAt,
}) => <String, Object?>{
  'consecutive_auth_failures': consecutiveAuthFailures,
  'reason_code': reasonCode,
  'last_failure_at': failedAt,
};

Map<String, Object?> raveHardLockoutData({required String lockedAt}) =>
    <String, Object?>{'locked_at': lockedAt};

/// Records a non-auth EDC sync failure (network blip or other RAVE-library
/// error) for audit + display. Deliberately does NOT carry
/// consecutive_auth_failures or last_failure_at: those belong only to
/// rave_auth_failed, which drives the lockout gate. An edc_sync_failed
/// therefore leaves classifyLockout's cooldown/lock decision untouched.
// Implements: DIARY-DEV-rave-edc-ingest/C — records sync failures for audit.
Map<String, Object?> edcSyncFailedData({
  required String reasonCode,
  required String failedAt,
  String? message,
}) => <String, Object?>{
  'reason_code': reasonCode,
  'last_sync_error_at': failedAt,
  if (message != null) 'message': message,
};
