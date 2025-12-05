/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00081: User Document Schema

import 'package:json_annotation/json_annotation.dart';

part 'web_user.g.dart';

/// Firestore user document model for web authentication.
///
/// Stores user credentials, sponsor association, and account security data.
/// Documents are stored in the `web_users` collection with UUID v4 as document ID.
@JsonSerializable()
class WebUser {
  /// UUID v4 document ID
  final String id;

  /// User-chosen username (6+ chars, no @)
  final String username;

  /// Argon2id password hash
  final String passwordHash;

  /// Sponsor identifier from linking code
  final String sponsorId;

  /// Original linking code used during registration
  final String linkingCode;

  /// App instance UUID at registration
  final String appUuid;

  /// Account creation timestamp
  final DateTime createdAt;

  /// Last successful login timestamp
  final DateTime? lastLoginAt;

  /// Failed login attempt counter (for rate limiting)
  final int failedAttempts;

  /// Account lockout expiry timestamp
  final DateTime? lockedUntil;

  const WebUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.sponsorId,
    required this.linkingCode,
    required this.appUuid,
    required this.createdAt,
    this.lastLoginAt,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  /// Creates an instance from JSON data.
  factory WebUser.fromJson(Map<String, dynamic> json) =>
      _$WebUserFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$WebUserToJson(this);

  /// Returns true if the account is currently locked.
  ///
  /// Account is considered locked if [lockedUntil] is set and is in the future.
  bool get isLocked {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  /// Creates a copy of this user with the specified fields replaced.
  ///
  /// To explicitly set optional fields to null, pass null.
  /// To leave them unchanged, don't pass the parameter.
  WebUser copyWith({
    String? id,
    String? username,
    String? passwordHash,
    String? sponsorId,
    String? linkingCode,
    String? appUuid,
    DateTime? createdAt,
    Object? lastLoginAt = _unset,
    int? failedAttempts,
    Object? lockedUntil = _unset,
  }) {
    return WebUser(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      sponsorId: sponsorId ?? this.sponsorId,
      linkingCode: linkingCode ?? this.linkingCode,
      appUuid: appUuid ?? this.appUuid,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt == _unset
          ? this.lastLoginAt
          : lastLoginAt as DateTime?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil:
          lockedUntil == _unset ? this.lockedUntil : lockedUntil as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          passwordHash == other.passwordHash &&
          sponsorId == other.sponsorId &&
          linkingCode == other.linkingCode &&
          appUuid == other.appUuid &&
          createdAt == other.createdAt &&
          lastLoginAt == other.lastLoginAt &&
          failedAttempts == other.failedAttempts &&
          lockedUntil == other.lockedUntil;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      passwordHash.hashCode ^
      sponsorId.hashCode ^
      linkingCode.hashCode ^
      appUuid.hashCode ^
      createdAt.hashCode ^
      lastLoginAt.hashCode ^
      failedAttempts.hashCode ^
      lockedUntil.hashCode;

  @override
  String toString() {
    return 'WebUser(id: $id, username: $username, sponsorId: $sponsorId, '
        'linkingCode: $linkingCode, createdAt: $createdAt, '
        'lastLoginAt: $lastLoginAt, failedAttempts: $failedAttempts, '
        'lockedUntil: $lockedUntil)';
  }
}

// Sentinel value for copyWith to distinguish between "not passed" and "null"
const _unset = Object();
