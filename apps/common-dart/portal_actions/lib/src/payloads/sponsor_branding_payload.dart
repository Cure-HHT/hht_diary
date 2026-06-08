// Implements: DIARY-DEV-sponsor-branding-source/A+B — typed payload for the
//   sponsor_branding_configured event: sponsor metadata + an asset MANIFEST.
//   Each asset is a role + uri + sha256 + contentType + byteLength pointer;
//   image bytes are NEVER serialized into the event payload (only the hash and
//   the local-serving pointer are stored in the event log).

/// One entry in the sponsor branding asset manifest. Carries the content hash
/// and a serving pointer, never the image bytes.
// Implements: DIARY-DEV-sponsor-branding-source/B
class BrandingAsset {
  const BrandingAsset({
    required this.role,
    required this.uri,
    required this.sha256,
    required this.contentType,
    required this.byteLength,
  });

  /// Logical asset role, e.g. `logo`.
  final String role;

  /// JWT-gated serving URI the diary fetches the bytes from.
  final String uri;

  /// Hex SHA-256 of the asset bytes (integrity + change detection).
  final String sha256;

  /// MIME type, e.g. `image/png`.
  final String contentType;

  /// Size of the asset bytes in bytes.
  final int byteLength;

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'uri': uri,
    'sha256': sha256,
    'contentType': contentType,
    'byteLength': byteLength,
  };

  factory BrandingAsset.fromJson(Map<String, Object?> json) => BrandingAsset(
    role: json['role'] as String,
    uri: json['uri'] as String,
    sha256: json['sha256'] as String,
    contentType: json['contentType'] as String,
    byteLength: (json['byteLength'] as num).toInt(),
  );
}

/// Event payload for `sponsor_branding_configured`: the sponsor identity, a
/// display title, and the asset manifest.
// Implements: DIARY-DEV-sponsor-branding-source/A+B
class SponsorBrandingConfiguredPayload {
  const SponsorBrandingConfiguredPayload({
    required this.sponsorId,
    required this.title,
    required this.assets,
  });

  final String sponsorId;
  final String title;
  final List<BrandingAsset> assets;

  Map<String, Object?> toJson() => <String, Object?>{
    'sponsorId': sponsorId,
    'title': title,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  factory SponsorBrandingConfiguredPayload.fromJson(
    Map<String, Object?> json,
  ) => SponsorBrandingConfiguredPayload(
    sponsorId: json['sponsorId'] as String,
    title: json['title'] as String,
    assets: ((json['assets'] as List?) ?? const [])
        .map((a) => BrandingAsset.fromJson((a as Map).cast<String, Object?>()))
        .toList(),
  );
}
