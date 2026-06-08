// Verifies: DIARY-GUI-participation-status-badge/B — branding is derived from
//   the diary's own (event-sourced) settings projection, set-once-at-link, and
//   the logo URL points at the JWT-gated asset endpoint (resolved by role). No
//   public branding pull.
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

SettingPayload _sponsor(String key, Object? value) => SettingPayload(
  key: key,
  value: value,
  source: SettingSource.sponsor,
  locked: true,
);

void main() {
  test('fromSettings derives title + logo URL pointing at the JWT-gated '
      'asset endpoint', () {
    final config = SponsorBrandingConfig.fromSettings(<String, SettingPayload>{
      'branding.title': _sponsor('branding.title', 'Reference'),
      'branding.logoSha256': _sponsor('branding.logoSha256', 'abc123sha'),
      'branding.logoRole': _sponsor('branding.logoRole', 'logo'),
    });

    expect(config.title, 'Reference');
    expect(config.logoSha256, 'abc123sha');
    expect(config.logoRole, 'logo');
    expect(config.hasLogo, isTrue);
    expect(
      config.appLogoUrl,
      '${AppConfig.apiBase}/api/v1/sponsor/branding/asset/logo',
    );
  });

  test('empty settings -> app-default (null title, no logo)', () {
    final config = SponsorBrandingConfig.fromSettings(
      const <String, SettingPayload>{},
    );
    expect(config.title, isNull);
    expect(config.logoRole, isNull);
    expect(config.appLogoUrl, isNull);
    expect(config.hasLogo, isFalse);
  });

  test('title only (no logo role) -> title set, no logo URL', () {
    final config = SponsorBrandingConfig.fromSettings(<String, SettingPayload>{
      'branding.title': _sponsor('branding.title', 'Reference'),
    });
    expect(config.title, 'Reference');
    expect(config.appLogoUrl, isNull);
    expect(config.hasLogo, isFalse);
  });

  test('a non-String branding value degrades to null (no TypeError)', () {
    final config = SponsorBrandingConfig.fromSettings(<String, SettingPayload>{
      // Unexpected payload shapes: an int title, a list role.
      'branding.title': _sponsor('branding.title', 42),
      'branding.logoRole': _sponsor('branding.logoRole', <Object?>['logo']),
    });
    expect(config.title, isNull);
    expect(config.logoRole, isNull);
    expect(config.appLogoUrl, isNull);
    expect(config.hasLogo, isFalse);
  });
}
