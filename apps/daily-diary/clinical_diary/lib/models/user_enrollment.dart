import 'package:clinical_diary/config/sponsor_registry.dart';

/// Represents a user's linking to a clinical trial
// Implements: DIARY-PRD-mobile-application/A
// Implements: DIARY-PRD-linking-code-lifecycle
// Implements: DIARY-PRD-participant-disconnection
// Implements: DIARY-PRD-participant-reactivate
class UserEnrollment {
  UserEnrollment({
    required this.userId,
    required this.jwtToken,
    required this.enrolledAt,
    this.sponsorId,
    this.backendUrl,
    this.participantId,
    this.siteId,
    this.siteName,
    this.sitePhoneNumber,
    this.studyParticipantId,
    this.linkingCode,
    this.sponsorSettings = const <Object?>[],
  });

  /// Create from JSON
  factory UserEnrollment.fromJson(Map<String, dynamic> json) {
    return UserEnrollment(
      userId: json['userId'] as String,
      jwtToken: json['jwtToken'] as String,
      enrolledAt: DateTime.parse(json['enrolledAt'] as String),
      sponsorId: json['sponsorId'] as String?,
      backendUrl: json['backendUrl'] as String?,
      participantId: json['participantId'] as String?,
      siteId: json['siteId'] as String?,
      siteName: json['siteName'] as String?,
      sitePhoneNumber: json['sitePhoneNumber'] as String?,
      studyParticipantId: json['studyParticipantId'] as String?,
      linkingCode: json['linkingCode'] as String?,
      sponsorSettings:
          (json['sponsorSettings'] as List?)?.cast<Object?>() ??
          const <Object?>[],
    );
  }

  final String userId;
  final String jwtToken;
  final DateTime enrolledAt;

  /// Sponsor ID for this linking (e.g., 'callisto')
  /// Determines which backend to use for API calls
  final String? sponsorId;

  /// Backend URL for this sponsor's diary-server
  /// Used for subsequent API calls (sync, records, etc.)
  final String? backendUrl;

  /// Participant ID from linking code (links to participants table)
  final String? participantId;

  /// Site ID where the participant is linked
  final String? siteId;

  /// Human-readable site name
  final String? siteName;

  /// Site phone number for participant contact
  // Implements: DIARY-PRD-notification-disconnection
  final String? sitePhoneNumber;

  /// De-identified participant ID for the study (from EDC)
  final String? studyParticipantId;

  /// The linking code used to connect this device (CUR-1049)
  /// Distinct from participantId — this is what the user sees on the profile screen
  final String? linkingCode;

  /// The `sponsor_settings` batch carried in the `/link` response: a list of
  /// `{key, value, locked}` entries the diary applies once at the link
  /// transition via `apply_sponsor_settings` (set-once-at-link). Empty when the
  /// portal delivered no sponsor settings.
  final List<Object?> sponsorSettings;

  /// Whether this linking includes clinical trial connection
  bool get isLinkedToClinicalTrial => participantId != null && siteId != null;
  SponsorInfo? get sponsorDetail => SponsorRegistry.getById(sponsorId ?? '');

  /// Convert to JSON for secure storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'jwtToken': jwtToken,
      'enrolledAt': enrolledAt.toIso8601String(),
      if (sponsorId != null) 'sponsorId': sponsorId,
      if (backendUrl != null) 'backendUrl': backendUrl,
      if (participantId != null) 'participantId': participantId,
      if (siteId != null) 'siteId': siteId,
      if (siteName != null) 'siteName': siteName,
      if (sitePhoneNumber != null) 'sitePhoneNumber': sitePhoneNumber,
      if (studyParticipantId != null) 'studyParticipantId': studyParticipantId,
      if (linkingCode != null) 'linkingCode': linkingCode,
      if (sponsorSettings.isNotEmpty) 'sponsorSettings': sponsorSettings,
    };
  }
}
