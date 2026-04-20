// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047I: HTTP request tracing with semantic conventions
//
// HTTP server setup using shelf

import 'dart:io';

import 'package:diary_functions/diary_functions.dart'
    show sessionStarted, sessionEnded;
import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'routes.dart';

/// Creates and starts the HTTP server
Future<HttpServer> createServer({required int port}) async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(otelMiddleware())
      .addMiddleware(_activeSessionsMiddleware())
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

      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

// IMPLEMENTS: REQ-o00047
/// Tracks active concurrent sessions (requests) for the diary server.
Middleware _activeSessionsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      sessionStarted();
      try {
        return await innerHandler(request);
      } finally {
        sessionEnded();
      }
    };
  };
}
