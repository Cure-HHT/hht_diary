// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-PRD-participant
//
// Typed payload for the diary-originated `participant_linked` event (surface P4):
// the participant-identity facts established when the device links to a study.
// Read by the portal to correlate "device linked to participant" — so it lives in
// the shared model. Per DIARY-DEV-shared-events-catalog/D it carries NO session
// token (`jwtToken`), NO one-time linking code, and NO infra URL — those stay in
// `flutter_secure_storage` / app config and are not event-log material.
library;

/// Payload for a `participant_linked` event.
class ParticipantLinkedPayload {
  const ParticipantLinkedPayload({
    required this.userId,
    required this.linkedAt,
    this.participantId,
    this.studyParticipantId,
    this.siteId,
    this.sponsorId,
  });

  /// The diary/portal user id established at link (always present).
  final String userId;

  /// ISO 8601 timestamp the link succeeded.
  final String linkedAt;

  /// The trial participant id the device is linked to (portal correlation key).
  final String? participantId;

  /// The study's own participant identifier, when distinct from [participantId].
  final String? studyParticipantId;

  /// The trial site id.
  final String? siteId;

  /// The sponsor the device linked to.
  final String? sponsorId;

  factory ParticipantLinkedPayload.fromJson(Map<String, Object?> json) {
    return ParticipantLinkedPayload(
      userId: json['user_id']! as String,
      linkedAt: json['linked_at']! as String,
      participantId: json['participant_id'] as String?,
      studyParticipantId: json['study_participant_id'] as String?,
      siteId: json['site_id'] as String?,
      sponsorId: json['sponsor_id'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'linked_at': linkedAt,
    if (participantId != null) 'participant_id': participantId,
    if (studyParticipantId != null) 'study_participant_id': studyParticipantId,
    if (siteId != null) 'site_id': siteId,
    if (sponsorId != null) 'sponsor_id': sponsorId,
  };
}
