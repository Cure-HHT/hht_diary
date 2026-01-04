// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Health check handler - converted from Firebase health.ts

import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Health check endpoint handler
/// Returns server status for Cloud Run health checks
Response healthHandler(Request request) {
  final body = jsonEncode({
    'status': 'ok',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'region': 'europe-west1',
    'service': 'diary-server',
  });

  return Response.ok(body, headers: {'Content-Type': 'application/json'});
}
