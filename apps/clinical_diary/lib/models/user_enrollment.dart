// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

/// Represents a user's enrollment with an enrollment code
class UserEnrollment {

  UserEnrollment({
    required this.userId,
    required this.jwtToken,
    required this.enrolledAt,
  });

  /// Create from JSON
  factory UserEnrollment.fromJson(Map<String, dynamic> json) {
    return UserEnrollment(
      userId: json['userId'] as String,
      jwtToken: json['jwtToken'] as String,
      enrolledAt: DateTime.parse(json['enrolledAt'] as String),
    );
  }

  final String userId;
  final String jwtToken;
  final DateTime enrolledAt;

  /// Convert to JSON for secure storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'jwtToken': jwtToken,
      'enrolledAt': enrolledAt.toIso8601String(),
    };
  }
}
