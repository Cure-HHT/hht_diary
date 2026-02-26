// IMPLEMENTS REQUIREMENTS:
//   REQ-d00102: Display full sponsor branding
// Sponsor branding configuration endpoint.
// Returns sponsor branding (title, asset base URL) from baked-in
// sponsor-config.json. The config file is copied into the container
// at build time from the sponsor's repository content/ directory.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Sponsor branding loaded from the filesystem.
/// content directory to read from /app/sponsor-content/{sponsorId}/.
class SponsorBranding {
  /// Load and parse sponsor-config.json, enriching with assetBaseUrl.
  static Map<String, dynamic>? loadConfig(String sponsorId) {
    try {
      String contentPath = '/app/sponsor-content/$sponsorId';
      final file = File('$contentPath/sponsor-config.json');
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

/// Get sponsor branding configuration.
///
/// GET /api/v1/sponsor/branding
///
/// Returns the sponsor's branding configuration (title, etc.) plus
/// the asset base URL for constructing asset paths by convention.
/// No query parameter needed — reads SPONSOR_ID from environment.
///
/// 200: { "sponsorId": "callisto", "title": "Terremoto",
///         "assetBaseUrl": "/callisto" }
/// 503: Sponsor branding not configured
Response sponsorBrandingHandler(Request request, String sponsorId) {
  final config = SponsorBranding.loadConfig(sponsorId);
  if (config == null) {
    return Response(
      500,
      body: jsonEncode({
        'error': 'Failed to load sponsor branding configuration',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  return Response.ok(
    jsonEncode(config),
    headers: {'Content-Type': 'application/json'},
  );
}
