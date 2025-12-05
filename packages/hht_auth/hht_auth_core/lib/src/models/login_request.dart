/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:json_annotation/json_annotation.dart';

part 'login_request.g.dart';

/// Request model for user login.
@JsonSerializable()
class LoginRequest {
  /// Username
  final String username;

  /// Password (plaintext - will be hashed after salt retrieval)
  final String password;

  /// App instance UUID
  final String appUuid;

  const LoginRequest({
    required this.username,
    required this.password,
    required this.appUuid,
  });

  /// Creates an instance from JSON data.
  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginRequest &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password &&
          appUuid == other.appUuid;

  @override
  int get hashCode =>
      username.hashCode ^ password.hashCode ^ appUuid.hashCode;
}
