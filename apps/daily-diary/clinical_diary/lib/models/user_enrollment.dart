// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00049: Mobile Linking Codes

/// Represents a user's enrollment/linking to a clinical trial
class UserEnrollment {
  UserEnrollment({
    required this.userId,
    required this.jwtToken,
    required this.enrolledAt,
    this.patientId,
    this.siteId,
    this.siteName,
    this.studyPatientId,
  });

  /// Create from JSON
  factory UserEnrollment.fromJson(Map<String, dynamic> json) {
    return UserEnrollment(
      userId: json['userId'] as String,
      jwtToken: json['jwtToken'] as String,
      enrolledAt: DateTime.parse(json['enrolledAt'] as String),
      patientId: json['patientId'] as String?,
      siteId: json['siteId'] as String?,
      siteName: json['siteName'] as String?,
      studyPatientId: json['studyPatientId'] as String?,
    );
  }

  final String userId;
  final String jwtToken;
  final DateTime enrolledAt;

  /// Patient ID from linking code (links to patients table)
  final String? patientId;

  /// Site ID where the patient is enrolled
  final String? siteId;

  /// Human-readable site name
  final String? siteName;

  /// De-identified patient ID for the study (from EDC)
  final String? studyPatientId;

  /// Whether this enrollment includes clinical trial linking
  bool get isLinkedToClinicalTrial => patientId != null && siteId != null;

  /// Convert to JSON for secure storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'jwtToken': jwtToken,
      'enrolledAt': enrolledAt.toIso8601String(),
      if (patientId != null) 'patientId': patientId,
      if (siteId != null) 'siteId': siteId,
      if (siteName != null) 'siteName': siteName,
      if (studyPatientId != null) 'studyPatientId': studyPatientId,
    };
  }
}
