// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegistrationRequest _$RegistrationRequestFromJson(Map<String, dynamic> json) =>
    RegistrationRequest(
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      linkingCode: json['linkingCode'] as String,
      appUuid: json['appUuid'] as String,
    );

Map<String, dynamic> _$RegistrationRequestToJson(
        RegistrationRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'passwordHash': instance.passwordHash,
      'salt': instance.salt,
      'linkingCode': instance.linkingCode,
      'appUuid': instance.appUuid,
    };
