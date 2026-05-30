// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-PRD-participant
//
// Typed payload for the diary-originated `patient_linked` event (surface P4):
// the participant-identity facts established when the device links to a study.
// Read by the portal to correlate "device linked to patient" — so it lives in
// the shared model. Per DIARY-DEV-shared-events-catalog/D it carries NO session
// token (`jwtToken`), NO one-time linking code, and NO infra URL — those stay in
// `flutter_secure_storage` / app config and are not event-log material.
library;

/// Payload for a `patient_linked` event.
class PatientLinkedPayload {
  const PatientLinkedPayload({
    required this.userId,
    required this.linkedAt,
    this.patientId,
    this.studyPatientId,
    this.siteId,
    this.sponsorId,
  });

  /// The diary/portal user id established at link (always present).
  final String userId;

  /// ISO 8601 timestamp the link succeeded.
  final String linkedAt;

  /// The trial patient id the device is linked to (portal correlation key).
  final String? patientId;

  /// The study's own patient identifier, when distinct from [patientId].
  final String? studyPatientId;

  /// The trial site id.
  final String? siteId;

  /// The sponsor the device linked to.
  final String? sponsorId;

  factory PatientLinkedPayload.fromJson(Map<String, Object?> json) {
    return PatientLinkedPayload(
      userId: json['user_id']! as String,
      linkedAt: json['linked_at']! as String,
      patientId: json['patient_id'] as String?,
      studyPatientId: json['study_patient_id'] as String?,
      siteId: json['site_id'] as String?,
      sponsorId: json['sponsor_id'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'linked_at': linkedAt,
    if (patientId != null) 'patient_id': patientId,
    if (studyPatientId != null) 'study_patient_id': studyPatientId,
    if (siteId != null) 'site_id': siteId,
    if (sponsorId != null) 'sponsor_id': sponsorId,
  };
}
