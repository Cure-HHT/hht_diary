// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047I: HTTP request tracing with semantic conventions
//
// HTTP server setup using shelf

import 'dart:io';

import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'routes.dart';

/// Creates and starts the HTTP server
Future<HttpServer> createServer({required int port}) async {
  final apiHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(otelMiddleware())
      .addMiddleware(_corsMiddleware())
      .addHandler(createRouter().call);

  final staticHandler = createStaticHandler(
    '/app/web',
    defaultDocument: 'index.html',
    serveFilesOutsidePath: false,
  );

  Future<Response> appHandler(Request request) async {
    // Always let existing API/router behavior run first.
    final apiResponse = await apiHandler(request);

    // If an existing route handled the request, keep current behavior unchanged.
    if (apiResponse.statusCode != 404) {
      return apiResponse;
    }

    // Never SPA-fallback API or health-style endpoints.
    final path = request.requestedUri.path;
    if (path == 'health' ||
        path == 'ready' ||
        path.startsWith('api/') ||
        path.startsWith('auth/')) {
      return apiResponse;
    }

    // Try serving static files from the Flutter web build output.
    final staticResponse = await staticHandler(request);
    if (staticResponse.statusCode != 404) {
      return staticResponse;
    }

    // SPA fallback for browser navigations only.
    final accept = request.headers['accept'] ?? '';
    if (request.method == 'GET' && accept.contains('text/html')) {
      return staticHandler(
        Request(
          'GET',
          Uri.parse('http://localhost/index.html'),
          headers: request.headers,
          context: request.context,
        ),
      );
    }

    // Preserve existing 404 behavior for everything else.
    return apiResponse;
  }

  return shelf_io.serve(appHandler, InternetAddress.anyIPv4, port);
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
      'Origin, Content-Type, Authorization, X-Active-Role',
};
