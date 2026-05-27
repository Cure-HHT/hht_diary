// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047I: HTTP request tracing with semantic conventions
//
// HTTP server setup using shelf

import 'dart:convert';
import 'dart:io';

import 'package:otel_common/otel_common.dart';
import 'package:portal_functions/portal_functions.dart'
    show isSchemaStale, foundDbVersion, expectedMinDbVersion;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'routes.dart';

/// Creates and starts the HTTP server
Future<HttpServer> createServer({required int port}) async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(otelMiddleware())
      .addMiddleware(_corsMiddleware())
      .addMiddleware(_dbVersionGuardMiddleware())
      .addHandler(createRouter().call);

  return shelf_io.serve(handler, InternetAddress.anyIPv4, port);
}

/// CORS middleware for browser requests
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Handle preflight
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      try {
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      } catch (e, stack) {
        // Log the error for debugging
        print('Handler error: $e\n$stack');
        // Return error response with CORS headers so browser can read it
        return Response.internalServerError(
          body: '{"error": "Internal server error"}',
          headers: {..._corsHeaders, 'Content-Type': 'application/json'},
        );
      }
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
      'Origin, Content-Type, Authorization, X-Active-Role, X-Patient-Id',
};

/// Returns 503 with a JSON body when the DB schema version is behind.
/// Passes `/health` through unconditionally so Cloud Run readiness probes
/// can report the problem rather than hiding it behind the old revision.
///
/// Placement: registered AFTER [_corsMiddleware] in the pipeline so it runs
/// INSIDE the CORS wrapper. The 503 response flows back through
/// [_corsMiddleware], which appends CORS headers — ensuring browsers can read
/// the error body without an opaque network failure.
// Implements: DIARY-OPS-db-schema-version-check/D+E
Middleware _dbVersionGuardMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (isSchemaStale && request.url.path != 'health') {
        return Response(
          503,
          body: jsonEncode({
            'error': 'database schema version behind',
            'needs': expectedMinDbVersion,
            'found': foundDbVersion,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return innerHandler(request);
    };
  };
}
