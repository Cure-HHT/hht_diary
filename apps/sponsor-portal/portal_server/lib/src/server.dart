// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// HTTP server setup using shelf

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'routes.dart';

/// Creates and starts the HTTP server
Future<HttpServer> createServer({required int port}) async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
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
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};
