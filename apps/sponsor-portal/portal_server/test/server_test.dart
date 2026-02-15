// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Unit tests for portal server HTTP server setup

@TestOn('vm')
library;

import 'dart:io';

import 'package:portal_server/portal_server.dart';
import 'package:test/test.dart';

void main() {
  group('createServer', () {
    HttpServer? server;

    tearDown(() async {
      await server?.close(force: true);
      server = null;
    });

    test('creates server on specified port', () async {
      // Use port 0 to let the OS assign an available port
      server = await createServer(port: 0);

      expect(server, isNotNull);
      expect(server!.port, greaterThan(0));
    });

    test('server responds to health check', () async {
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        final request = await client.get('localhost', server!.port, '/health');
        final response = await request.close();

        expect(response.statusCode, equals(200));
      } finally {
        client.close();
      }
    });

    test('server adds CORS headers to responses', () async {
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        final request = await client.get('localhost', server!.port, '/health');
        final response = await request.close();

        expect(
          response.headers.value('Access-Control-Allow-Origin'),
          equals('*'),
        );
        expect(
          response.headers.value('Access-Control-Allow-Methods'),
          contains('GET'),
        );
      } finally {
        client.close();
      }
    });

    test('server handles OPTIONS preflight requests', () async {
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        final request = await client.open(
          'OPTIONS',
          'localhost',
          server!.port,
          '/api/v1/auth/login',
        );
        final response = await request.close();

        expect(response.statusCode, equals(200));
        expect(
          response.headers.value('Access-Control-Allow-Origin'),
          equals('*'),
        );
        expect(
          response.headers.value('Access-Control-Allow-Headers'),
          contains('Authorization'),
        );
      } finally {
        client.close();
      }
    });

    test('server binds to IPv4 any address', () async {
      server = await createServer(port: 0);

      // InternetAddress.anyIPv4 should allow connections
      expect(server!.address.type, equals(InternetAddressType.IPv4));
    });
  });
}
