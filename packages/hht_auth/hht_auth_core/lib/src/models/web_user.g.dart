// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebUser _$WebUserFromJson(Map<String, dynamic> json) => WebUser(
      id: json['id'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      sponsorId: json['sponsorId'] as String,
      linkingCode: json['linkingCode'] as String,
      appUuid: json['appUuid'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
      failedAttempts: (json['failedAttempts'] as num?)?.toInt() ?? 0,
      lockedUntil: json['lockedUntil'] == null
          ? null
          : DateTime.parse(json['lockedUntil'] as String),
    );

Map<String, dynamic> _$WebUserToJson(WebUser instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'passwordHash': instance.passwordHash,
      'sponsorId': instance.sponsorId,
      'linkingCode': instance.linkingCode,
      'appUuid': instance.appUuid,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
      'failedAttempts': instance.failedAttempts,
      'lockedUntil': instance.lockedUntil?.toIso8601String(),
    };
