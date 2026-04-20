// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-o00047: Performance Monitoring
//
// Health check handler - returns server status and component versions

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Component version info, populated from compile-time -D flags.
/// Set once at startup from server.dart, used by health endpoint.
class ServerVersions {
  static String diaryServer = 'unknown';
  static String diaryFunctions = 'unknown';
  static String trialDataTypes = 'unknown';
}

/// Health check endpoint handler
/// Returns server status and component versions for Cloud Run health checks.
Response healthHandler(Request request) {
  final body = jsonEncode({
    'status': 'ok',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'region':
        Platform.environment['GCP_REGION'] ??
        Platform.environment['CLOUD_RUN_REGION'] ??
        'unknown',
    'service': Platform.environment['K_SERVICE'] ?? 'diary-server',
    'versions': {
      'diary_server': ServerVersions.diaryServer,
      'diary_functions': ServerVersions.diaryFunctions,
      'trial_data_types': ServerVersions.trialDataTypes,
    },
  });

  return Response.ok(body, headers: {'Content-Type': 'application/json'});
}
