// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00102: Display full sponsor branding
//
// Re-exports shared sponsor branding implementation.
// sponsorBrandingHandler(Request) reads SPONSOR_ID from the environment,
// which is baked into the container at build time.

export 'package:shared_functions/shared_functions.dart';
