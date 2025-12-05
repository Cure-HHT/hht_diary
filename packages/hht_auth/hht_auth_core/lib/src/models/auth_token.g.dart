// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthToken _$AuthTokenFromJson(Map<String, dynamic> json) => AuthToken(
      sub: json['sub'] as String,
      username: json['username'] as String,
      sponsorId: json['sponsorId'] as String,
      sponsorUrl: json['sponsorUrl'] as String,
      appUuid: json['appUuid'] as String,
      iat: DateTime.parse(json['iat'] as String),
      exp: DateTime.parse(json['exp'] as String),
    );

Map<String, dynamic> _$AuthTokenToJson(AuthToken instance) => <String, dynamic>{
      'sub': instance.sub,
      'username': instance.username,
      'sponsorId': instance.sponsorId,
      'sponsorUrl': instance.sponsorUrl,
      'appUuid': instance.appUuid,
      'iat': instance.iat.toIso8601String(),
      'exp': instance.exp.toIso8601String(),
    };
