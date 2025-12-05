/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:json_annotation/json_annotation.dart';

part 'auth_token.g.dart';

/// JWT payload model representing an authenticated session.
///
/// Contains user identification, sponsor information, and token lifecycle data.
/// Tokens are short-lived (15 minutes for web) and must be refreshed.
@JsonSerializable()
class AuthToken {
  /// User document ID (UUID v4)
  final String sub;

  /// Username
  final String username;

  /// Sponsor identifier from linking code
  final String sponsorId;

  /// Sponsor Portal base URL
  final String sponsorUrl;

  /// Device/app instance UUID
  final String appUuid;

  /// Issued at timestamp
  final DateTime iat;

  /// Expiration timestamp
  final DateTime exp;

  const AuthToken({
    required this.sub,
    required this.username,
    required this.sponsorId,
    required this.sponsorUrl,
    required this.appUuid,
    required this.iat,
    required this.exp,
  });

  /// Creates an instance from JSON data.
  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$AuthTokenToJson(this);

  /// Returns true if the token has expired.
  bool get isExpired => DateTime.now().isAfter(exp);

  /// Returns the remaining time until expiration.
  ///
  /// Returns [Duration.zero] if the token is already expired.
  Duration get remainingTime {
    final remaining = exp.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Creates a copy of this token with the specified fields replaced.
  AuthToken copyWith({
    String? sub,
    String? username,
    String? sponsorId,
    String? sponsorUrl,
    String? appUuid,
    DateTime? iat,
    DateTime? exp,
  }) {
    return AuthToken(
      sub: sub ?? this.sub,
      username: username ?? this.username,
      sponsorId: sponsorId ?? this.sponsorId,
      sponsorUrl: sponsorUrl ?? this.sponsorUrl,
      appUuid: appUuid ?? this.appUuid,
      iat: iat ?? this.iat,
      exp: exp ?? this.exp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthToken &&
          runtimeType == other.runtimeType &&
          sub == other.sub &&
          username == other.username &&
          sponsorId == other.sponsorId &&
          sponsorUrl == other.sponsorUrl &&
          appUuid == other.appUuid &&
          iat == other.iat &&
          exp == other.exp;

  @override
  int get hashCode =>
      sub.hashCode ^
      username.hashCode ^
      sponsorId.hashCode ^
      sponsorUrl.hashCode ^
      appUuid.hashCode ^
      iat.hashCode ^
      exp.hashCode;

  @override
  String toString() {
    return 'AuthToken(sub: $sub, username: $username, sponsorId: $sponsorId, '
        'sponsorUrl: $sponsorUrl, appUuid: $appUuid, iat: $iat, exp: $exp)';
  }
}
