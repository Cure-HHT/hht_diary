// Sponsor branding, derived from the diary's own event-sourced settings
// projection (set-once-at-link). The portal composes a sponsor-settings batch
// into the /link response; the diary applies it through the sponsor-settings
// path and reads it back here. There is no public branding pull: logo bytes are
// fetched JWT-gated by role from the diary-server asset endpoint.

import 'package:clinical_diary/config/app_config.dart';
import 'package:diary_shared_model/diary_shared_model.dart';

/// Sponsor branding resolved from the locked `branding.*` settings keys.
class SponsorBrandingConfig {
  const SponsorBrandingConfig({this.title, this.logoSha256, this.logoRole});

  /// Derive branding from the diary's `{key: SettingPayload}` settings map.
  /// Reads the `branding.*` keys delivered at link time; absent keys leave the
  /// corresponding field null (app-default).
  // Implements: DIARY-GUI-participation-status-badge/B
  factory SponsorBrandingConfig.fromSettings(
    Map<String, SettingPayload> settings,
  ) {
    // Degrade a non-String (or absent) branding value to null rather than
    // throwing a TypeError on an unexpected payload shape.
    String? s(String k) {
      final v = settings[k]?.value;
      return v is String ? v : null;
    }

    return SponsorBrandingConfig(
      title: s('branding.title'),
      logoSha256: s('branding.logoSha256'),
      logoRole: s('branding.logoRole'),
    );
  }

  /// Human-readable sponsor title (null -> app default).
  final String? title;

  /// SHA-256 of the logo asset bytes — the content-addressed cache key used to
  /// fetch and verify the logo via the JWT-gated asset endpoint.
  final String? logoSha256;

  /// Logo asset role, the path segment the JWT-gated asset endpoint serves by.
  final String? logoRole;

  /// Fallback branding when no sponsor settings are present (app default).
  static const fallback = SponsorBrandingConfig();

  /// JWT-gated asset-endpoint URL for the app logo, resolved by [logoRole].
  /// Null when no logo role is configured.
  String? get appLogoUrl {
    final role = logoRole;
    if (role == null) return null;
    return '${AppConfig.apiBase}/api/v1/sponsor/branding/asset/$role';
  }

  bool get hasLogo => appLogoUrl != null;
}
