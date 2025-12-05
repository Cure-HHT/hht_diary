// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sponsor_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SponsorConfig _$SponsorConfigFromJson(Map<String, dynamic> json) =>
    SponsorConfig(
      sponsorId: json['sponsorId'] as String,
      sponsorName: json['sponsorName'] as String,
      sessionTimeoutMinutes: (json['sessionTimeoutMinutes'] as num).toInt(),
      branding:
          SponsorBranding.fromJson(json['branding'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SponsorConfigToJson(SponsorConfig instance) =>
    <String, dynamic>{
      'sponsorId': instance.sponsorId,
      'sponsorName': instance.sponsorName,
      'sessionTimeoutMinutes': instance.sessionTimeoutMinutes,
      'branding': instance.branding,
    };

SponsorBranding _$SponsorBrandingFromJson(Map<String, dynamic> json) =>
    SponsorBranding(
      logoUrl: json['logoUrl'] as String,
      primaryColor: json['primaryColor'] as String,
      secondaryColor: json['secondaryColor'] as String,
      welcomeMessage: json['welcomeMessage'] as String?,
    );

Map<String, dynamic> _$SponsorBrandingToJson(SponsorBranding instance) =>
    <String, dynamic>{
      'logoUrl': instance.logoUrl,
      'primaryColor': instance.primaryColor,
      'secondaryColor': instance.secondaryColor,
      'welcomeMessage': instance.welcomeMessage,
    };
