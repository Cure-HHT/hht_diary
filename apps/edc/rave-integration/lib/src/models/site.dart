/// Represents a clinical trial site from the RAVE EDC system.
///
/// Sites are extracted from ODM AdminData/Location elements returned by
/// the `/RaveWebServices/datasets/Sites.odm` endpoint.
class RaveSite {
  /// The Location OID (e.g., "DEV_999-001" or "12345").
  final String oid;

  /// The site name (e.g., "Site 001").
  final String name;

  /// Whether the site is active in RAVE (mdsol:Active="Yes").
  final bool isActive;

  /// The study-specific site number from MetaDataVersionRef.
  final String? studySiteNumber;

  /// The study OID this site is associated with.
  final String? studyOid;

  /// The metadata version OID.
  final String? metaDataVersionOid;

  /// The effective date of the metadata version.
  final DateTime? effectiveDate;

  const RaveSite({
    required this.oid,
    required this.name,
    required this.isActive,
    this.studySiteNumber,
    this.studyOid,
    this.metaDataVersionOid,
    this.effectiveDate,
  });

  @override
  String toString() =>
      'RaveSite(oid: $oid, name: $name, active: $isActive, siteNumber: $studySiteNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaveSite &&
          runtimeType == other.runtimeType &&
          oid == other.oid &&
          name == other.name &&
          isActive == other.isActive &&
          studySiteNumber == other.studySiteNumber &&
          studyOid == other.studyOid;

  @override
  int get hashCode =>
      oid.hashCode ^
      name.hashCode ^
      isActive.hashCode ^
      studySiteNumber.hashCode ^
      studyOid.hashCode;
}
