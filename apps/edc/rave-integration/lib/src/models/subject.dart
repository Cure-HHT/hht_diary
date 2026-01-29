/// Represents a clinical trial subject (patient) from the RAVE EDC system.
///
/// Subjects are extracted from ODM ClinicalData/SubjectData elements returned by
/// the `/RaveWebServices/studies/{studyOid}/subjects` endpoint.
class RaveSubject {
  /// The SubjectKey (e.g., "840-001-001").
  final String subjectKey;

  /// The LocationOID from SiteRef (maps to sites.site_id).
  final String siteOid;

  /// The study-environment site number from SiteRef
  /// (mdsol:StudyEnvSiteNumber attribute).
  final String? siteNumber;

  const RaveSubject({
    required this.subjectKey,
    required this.siteOid,
    this.siteNumber,
  });

  @override
  String toString() =>
      'RaveSubject(subjectKey: $subjectKey, siteOid: $siteOid, siteNumber: $siteNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaveSubject &&
          runtimeType == other.runtimeType &&
          subjectKey == other.subjectKey &&
          siteOid == other.siteOid &&
          siteNumber == other.siteNumber;

  @override
  int get hashCode =>
      subjectKey.hashCode ^ siteOid.hashCode ^ siteNumber.hashCode;
}
