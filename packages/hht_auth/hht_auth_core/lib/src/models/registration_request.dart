/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:json_annotation/json_annotation.dart';

part 'registration_request.g.dart';

/// Request model for user registration.
@JsonSerializable()
class RegistrationRequest {
  /// Username (6+ chars, no @)
  final String username;

  /// Password hash (Argon2id)
  final String passwordHash;

  /// Salt used for password hashing
  final String salt;

  /// Linking code from enrollment
  final String linkingCode;

  /// App instance UUID
  final String appUuid;

  const RegistrationRequest({
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.linkingCode,
    required this.appUuid,
  });

  /// Creates an instance from JSON data.
  factory RegistrationRequest.fromJson(Map<String, dynamic> json) =>
      _$RegistrationRequestFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$RegistrationRequestToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistrationRequest &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          passwordHash == other.passwordHash &&
          salt == other.salt &&
          linkingCode == other.linkingCode &&
          appUuid == other.appUuid;

  @override
  int get hashCode =>
      username.hashCode ^
      passwordHash.hashCode ^
      salt.hashCode ^
      linkingCode.hashCode ^
      appUuid.hashCode;
}
