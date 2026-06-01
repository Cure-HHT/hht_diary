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
