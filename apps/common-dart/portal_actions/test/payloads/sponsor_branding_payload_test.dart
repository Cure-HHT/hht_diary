// Verifies: DIARY-DEV-sponsor-branding-source/A+B — the branding payload is a
//   pure metadata + asset MANIFEST (role + uri + sha256 + contentType +
//   byteLength); image bytes are NEVER serialized into the event payload.
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('BrandingAsset round-trips toJson/fromJson', () {
    const asset = BrandingAsset(
      role: 'logo',
      uri: '/api/v1/sponsor/branding/asset/logo',
      sha256: 'abc123',
      contentType: 'image/png',
      byteLength: 4096,
    );
    final back = BrandingAsset.fromJson(asset.toJson());
    expect(back.role, 'logo');
    expect(back.uri, '/api/v1/sponsor/branding/asset/logo');
    expect(back.sha256, 'abc123');
    expect(back.contentType, 'image/png');
    expect(back.byteLength, 4096);
  });

  test('encoded asset map carries no image bytes (no bytes/data key)', () {
    const asset = BrandingAsset(
      role: 'logo',
      uri: '/api/v1/sponsor/branding/asset/logo',
      sha256: 'abc123',
      contentType: 'image/png',
      byteLength: 4096,
    );
    final json = asset.toJson();
    expect(json.containsKey('bytes'), isFalse);
    expect(json.containsKey('data'), isFalse);
  });

  test('SponsorBrandingConfiguredPayload round-trips toJson/fromJson', () {
    const payload = SponsorBrandingConfiguredPayload(
      sponsorId: 'reference',
      title: 'Reference Study',
      assets: [
        BrandingAsset(
          role: 'logo',
          uri: '/api/v1/sponsor/branding/asset/logo',
          sha256: 'deadbeef',
          contentType: 'image/png',
          byteLength: 1024,
        ),
      ],
    );
    final back = SponsorBrandingConfiguredPayload.fromJson(payload.toJson());
    expect(back.sponsorId, 'reference');
    expect(back.title, 'Reference Study');
    expect(back.assets, hasLength(1));
    expect(back.assets.single.sha256, 'deadbeef');
  });

  test('payload toJson contains no raw image bytes', () {
    const payload = SponsorBrandingConfiguredPayload(
      sponsorId: 'reference',
      title: 'Reference Study',
      assets: [
        BrandingAsset(
          role: 'logo',
          uri: '/api/v1/sponsor/branding/asset/logo',
          sha256: 'deadbeef',
          contentType: 'image/png',
          byteLength: 1024,
        ),
      ],
    );
    final encoded = payload.toJson();
    final assetMap = (encoded['assets'] as List).single as Map;
    expect(assetMap.containsKey('bytes'), isFalse);
    expect(assetMap.containsKey('data'), isFalse);
  });
}
