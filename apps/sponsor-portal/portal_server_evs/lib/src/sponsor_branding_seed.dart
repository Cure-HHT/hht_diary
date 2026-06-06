// Implements: DIARY-DEV-sponsor-branding-source/C+D — idempotent boot seed of
//   the portal's event-sourced sponsor branding. Reads the sponsor's
//   sponsor-config.json + asset files from the content overlay, builds the
//   asset MANIFEST (role + uri + sha256 + contentType + byteLength — never the
//   bytes), and appends a sponsor_branding_configured event ONLY when the
//   materialized sponsor_branding row is absent or its content (title / any
//   asset sha256) has changed. Otherwise it is a no-op, so it runs safely on
//   every boot outside the seed-once gate.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';

/// Role -> local content-overlay path (relative to `<contentRoot>/<sponsorId>`).
/// The serving handler shares this constant; a request role string is NEVER
/// turned into a path except by lookup here.
const Map<String, String> sponsorBrandingAssetPaths = <String, String>{
  'logo': 'portal/assets/images/app_logo.png',
};

/// Public serving URI per role (the diary fetches the bytes here, JWT-gated).
const Map<String, String> _sponsorBrandingAssetUris = <String, String>{
  'logo': '/api/v1/sponsor/branding/asset/logo',
};

const Map<String, String> _sponsorBrandingAssetContentTypes = <String, String>{
  'logo': 'image/png',
};

/// Idempotent boot seed for sponsor branding. [sponsorId] defaults from the
/// SPONSOR_ID env var; [contentRoot] is the content-overlay mount.
// Implements: DIARY-DEV-sponsor-branding-source/C+D
Future<void> seedSponsorBranding({
  required EventStore eventStore,
  required StorageBackend backend,
  String contentRoot = '/app/sponsor-content',
  String? sponsorId,
}) async {
  final sid = sponsorId ?? Platform.environment['SPONSOR_ID'];
  if (sid == null || sid.isEmpty) {
    stderr.writeln('seedSponsorBranding: no SPONSOR_ID; skipping');
    return;
  }

  final configFile = File('$contentRoot/$sid/sponsor-config.json');
  if (!configFile.existsSync()) {
    stderr.writeln(
        'seedSponsorBranding: ${configFile.path} missing; skipping ($sid)');
    return;
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  final title = (config['title'] as String?) ?? sid;

  // Build the asset manifest from the content overlay (hash + pointer only).
  final assets = <BrandingAsset>[];
  for (final entry in sponsorBrandingAssetPaths.entries) {
    final role = entry.key;
    final file = File('$contentRoot/$sid/${entry.value}');
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    assets.add(BrandingAsset(
      role: role,
      uri: _sponsorBrandingAssetUris[role] ??
          '/api/v1/sponsor/branding/asset/$role',
      sha256: sha256.convert(bytes).toString(),
      contentType:
          _sponsorBrandingAssetContentTypes[role] ?? 'application/octet-stream',
      byteLength: bytes.length,
    ));
  }

  // Compare against the materialized row: seed only on absence or change.
  final rows = await backend.findViewRows('sponsor_branding');
  Map<String, Object?>? current;
  for (final r in rows) {
    if (r['sponsorId'] == sid) {
      current = r;
      break;
    }
  }
  if (current != null && !_brandingChanged(current, title, assets)) {
    return; // unchanged -> no-op
  }

  await eventStore.append(
    entryType: 'sponsor_branding_configured',
    aggregateType: 'sponsor_branding',
    aggregateId: sid,
    eventType: 'sponsor_branding_configured',
    data: SponsorBrandingConfiguredPayload(
      sponsorId: sid,
      title: title,
      assets: assets,
    ).toJson(),
    initiator: const AutomationInitiator(service: 'portal-branding-seed'),
  );
}

/// True if the materialized [row]'s title or asset sha256 set differs from the
/// freshly-read [title] + [assets].
bool _brandingChanged(
  Map<String, Object?> row,
  String title,
  List<BrandingAsset> assets,
) {
  if (row['title'] != title) return true;
  final existing = <String, String>{};
  for (final a in (row['assets'] as List? ?? const [])) {
    final m = (a as Map).cast<String, Object?>();
    existing[m['role'] as String] = m['sha256'] as String? ?? '';
  }
  if (existing.length != assets.length) return true;
  for (final a in assets) {
    if (existing[a.role] != a.sha256) return true;
  }
  return false;
}
