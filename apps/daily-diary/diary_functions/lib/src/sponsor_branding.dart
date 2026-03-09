// IMPLEMENTS REQUIREMENTS:
//   REQ-d00102: Display full sponsor branding
//
// Thin wrapper that delegates to shared_functions/sponsor_branding.
// Preserves the existing sponsorBrandingHandler(Request, String sponsorId)
// signature used by diary_server's router.

import 'package:shelf/shelf.dart';
import 'package:shared_functions/shared_functions.dart' as sf;

export 'package:shared_functions/shared_functions.dart' show SponsorBranding;

/// Get sponsor branding configuration.
///
/// GET /api/v1/sponsor/branding
///
/// Returns the sponsor's branding configuration (title, etc.) plus
/// the asset base URL for constructing asset paths by convention.
///
/// 200: { "sponsorId": "callisto", "title": "Terremoto",
///         "assetBaseUrl": "/callisto" }
/// 503: Sponsor branding not configured
Response sponsorBrandingHandler(Request request, String sponsorId) =>
    sf.sponsorBrandingHandlerWithId(request, sponsorId);
