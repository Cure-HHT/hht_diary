/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00084: Sponsor Configuration Loading

import 'package:json_annotation/json_annotation.dart';

part 'sponsor_config.g.dart';

/// Sponsor-specific configuration fetched from the Sponsor Portal.
///
/// After authentication, the client uses the `sponsorUrl` from the auth token
/// to fetch this configuration directly from the Sponsor Portal API.
@JsonSerializable()
class SponsorConfig {
  /// Unique sponsor identifier
  final String sponsorId;

  /// Human-readable sponsor name
  final String sponsorName;

  /// Session timeout in minutes (default 2, range 1-30)
  final int sessionTimeoutMinutes;

  /// Sponsor-specific branding
  final SponsorBranding branding;

  const SponsorConfig({
    required this.sponsorId,
    required this.sponsorName,
    required this.sessionTimeoutMinutes,
    required this.branding,
  });

  /// Creates an instance from JSON data.
  factory SponsorConfig.fromJson(Map<String, dynamic> json) =>
      _$SponsorConfigFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$SponsorConfigToJson(this);

  /// Creates a default config for fallback when portal fetch fails.
  factory SponsorConfig.defaults({
    required String sponsorId,
    String? sponsorName,
  }) {
    return SponsorConfig(
      sponsorId: sponsorId,
      sponsorName: sponsorName ?? 'Clinical Diary',
      sessionTimeoutMinutes: 2,
      branding: SponsorBranding.defaults(),
    );
  }

  /// Creates a copy of this config with the specified fields replaced.
  SponsorConfig copyWith({
    String? sponsorId,
    String? sponsorName,
    int? sessionTimeoutMinutes,
    SponsorBranding? branding,
  }) {
    return SponsorConfig(
      sponsorId: sponsorId ?? this.sponsorId,
      sponsorName: sponsorName ?? this.sponsorName,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      branding: branding ?? this.branding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SponsorConfig &&
          runtimeType == other.runtimeType &&
          sponsorId == other.sponsorId &&
          sponsorName == other.sponsorName &&
          sessionTimeoutMinutes == other.sessionTimeoutMinutes &&
          branding == other.branding;

  @override
  int get hashCode =>
      sponsorId.hashCode ^
      sponsorName.hashCode ^
      sessionTimeoutMinutes.hashCode ^
      branding.hashCode;
}

/// Sponsor-specific branding configuration.
@JsonSerializable()
class SponsorBranding {
  /// Logo URL
  final String logoUrl;

  /// Primary color (hex string, e.g., "#FF5733")
  final String primaryColor;

  /// Secondary color (hex string)
  final String secondaryColor;

  /// Welcome message displayed after login (optional)
  final String? welcomeMessage;

  const SponsorBranding({
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    this.welcomeMessage,
  });

  /// Creates an instance from JSON data.
  factory SponsorBranding.fromJson(Map<String, dynamic> json) =>
      _$SponsorBrandingFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$SponsorBrandingToJson(this);

  /// Creates default branding for fallback.
  factory SponsorBranding.defaults() {
    return const SponsorBranding(
      logoUrl: '',
      primaryColor: '#1976D2',
      secondaryColor: '#424242',
    );
  }

  /// Creates a copy of this branding with the specified fields replaced.
  SponsorBranding copyWith({
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? welcomeMessage,
  }) {
    return SponsorBranding(
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SponsorBranding &&
          runtimeType == other.runtimeType &&
          logoUrl == other.logoUrl &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          welcomeMessage == other.welcomeMessage;

  @override
  int get hashCode =>
      logoUrl.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      welcomeMessage.hashCode;
}
