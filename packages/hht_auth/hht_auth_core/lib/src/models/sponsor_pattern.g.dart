// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sponsor_pattern.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SponsorPattern _$SponsorPatternFromJson(Map<String, dynamic> json) =>
    SponsorPattern(
      patternPrefix: json['patternPrefix'] as String,
      sponsorId: json['sponsorId'] as String,
      sponsorName: json['sponsorName'] as String,
      portalUrl: json['portalUrl'] as String,
      firestoreProject: json['firestoreProject'] as String,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      decommissionedAt: json['decommissionedAt'] == null
          ? null
          : DateTime.parse(json['decommissionedAt'] as String),
    );

Map<String, dynamic> _$SponsorPatternToJson(SponsorPattern instance) =>
    <String, dynamic>{
      'patternPrefix': instance.patternPrefix,
      'sponsorId': instance.sponsorId,
      'sponsorName': instance.sponsorName,
      'portalUrl': instance.portalUrl,
      'firestoreProject': instance.firestoreProject,
      'active': instance.active,
      'createdAt': instance.createdAt.toIso8601String(),
      'decommissionedAt': instance.decommissionedAt?.toIso8601String(),
    };
