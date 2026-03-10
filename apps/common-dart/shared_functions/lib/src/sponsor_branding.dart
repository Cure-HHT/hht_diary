// IMPLEMENTS REQUIREMENTS:
//   REQ-d00102: Display full sponsor branding
//
// Shared sponsor branding configuration loader.
// Reads sponsor-config.json from /app/sponsor-content/{sponsorId}/
// and enriches it with an assetBaseUrl field.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Sponsor branding loaded from the filesystem.
///
/// Reads sponsor-config.json from /app/sponsor-content/{sponsorId}/.
/// The config file is copied into the container at build time from
/// the sponsor's repository content/ directory.
class SponsorBranding {
  final String sponsorId;

  const SponsorBranding(this.sponsorId);

  /// Creates a [SponsorBranding] by reading SPONSOR_ID from the environment.
  factory SponsorBranding.fromEnvironment() =>
      SponsorBranding(Platform.environment['SPONSOR_ID'] ?? '');

  String get _contentPath => '/app/sponsor-content/$sponsorId';

  bool get isConfigured =>
      sponsorId.isNotEmpty &&
      File('$_contentPath/sponsor-config.json').existsSync();

  /// Load and parse sponsor-config.json, enriching with assetBaseUrl.
  Map<String, dynamic>? loadConfig() {
    try {
      final file = File('$_contentPath/sponsor-config.json');
      if (!file.existsSync()) return null;
      final config =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      config['assetBaseUrl'] = '/$sponsorId';
      return config;
    } catch (e) {
      print('[SPONSOR_BRANDING] Failed to load config: $e');
      return null;
    }
  }
}

/// Sponsor branding handler where [sponsorId] is supplied as a parameter.
///
/// Used by `diary_functions` where the sponsorId comes from the route.
///
/// GET /api/v1/sponsor/branding
///
/// 200: { "sponsorId": "callisto", "title": "Terremoto",
///         "assetBaseUrl": "/callisto" }
/// 503: Sponsor branding not configured
Response sponsorBrandingHandlerWithId(Request request, String sponsorId) {
  final branding = SponsorBranding(sponsorId);
  final config = branding.loadConfig();
  if (config == null) {
    return Response(
      503,
      body: jsonEncode({
        'error': 'Sponsor branding not configured',
        'message':
            'Failed to load sponsor branding configuration for SPONSOR_ID:$sponsorId',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
  return Response.ok(
    jsonEncode(config),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Sponsor branding handler that reads sponsorId from the SPONSOR_ID env var.
///
/// Used by `portal_functions` where the sponsorId is baked into the container.
///
/// GET /api/v1/sponsor/branding
///
/// 200: { "sponsorId": "callisto", "title": "Terremoto",
///         "assetBaseUrl": "/callisto" }
/// 503: Sponsor branding not configured
Response sponsorBrandingHandler(Request request) =>
    sponsorBrandingHandlerWithId(
      request,
      Platform.environment['SPONSOR_ID'] ?? '',
    );
