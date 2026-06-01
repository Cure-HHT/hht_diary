// Implements: DIARY-DEV-rave-edc-ingest/A — typed payload for the site_synced_from_edc
//   edge event; field names match the RAVE Sites.odm record (RaveSite).
class SiteSyncedFromEdcPayload {
  const SiteSyncedFromEdcPayload({
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
    required this.isActive,
    required this.studyOid,
    required this.edcSyncedAt,
  });
  final String siteId; // RaveSite.oid
  final String siteName; // RaveSite.name
  final String siteNumber; // RaveSite.studySiteNumber (fallback oid)
  final bool isActive; // RaveSite.isActive
  final String studyOid; // RaveSite.studyOid
  final String edcSyncedAt; // ISO-8601 UTC of this sync

  Map<String, Object?> toJson() => <String, Object?>{
    'site_id': siteId,
    'site_name': siteName,
    'site_number': siteNumber,
    'is_active': isActive,
    'study_oid': studyOid,
    'edc_synced_at': edcSyncedAt,
  };
}
