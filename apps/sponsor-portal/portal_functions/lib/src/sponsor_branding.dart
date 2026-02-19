// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Sponsor branding configuration endpoint.
// Returns sponsor branding (title, asset base URL) from baked-in
// sponsor-config.json. The config file is copied into the container
// at build time from the sponsor's repository content/ directory.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Sponsor branding loaded from the filesystem.
///
/// The SPONSOR_ID environment variable identifies which sponsor's
/// content directory to read from /app/sponsor-content/{sponsorId}/.
class SponsorBranding {
  static String get sponsorId => Platform.environment['SPONSOR_ID'] ?? '';

  static String get _contentPath => '/app/sponsor-content/$sponsorId';

  static bool get isConfigured =>
      sponsorId.isNotEmpty &&
      File('$_contentPath/sponsor-config.json').existsSync();

  /// Load and parse sponsor-config.json, enriching with assetBaseUrl.
  static Map<String, dynamic>? loadConfig() {
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
Response sponsorBrandingHandler(Request request) {
  if (!SponsorBranding.isConfigured) {
    return Response(
      503,
      body: jsonEncode({
        'error': 'Sponsor branding not configured',
        'message': 'SPONSOR_ID is not set or sponsor-config.json is missing.',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final config = SponsorBranding.loadConfig();
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
