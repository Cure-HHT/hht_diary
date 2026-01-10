// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Unit tests for diary server HTTP server setup

@TestOn('vm')
library;

import 'dart:io';

import 'package:diary_server/diary_server.dart';
import 'package:test/test.dart';

void main() {
  group('createServer', () {
    HttpServer? server;

    tearDown(() async {
      await server?.close(force: true);
      server = null;
    });

    test('creates server on specified port', () async {
      // Use a random high port to avoid conflicts
      final port = 38080 + DateTime.now().millisecond % 1000;

      server = await createServer(port: port);

      expect(server, isNotNull);
      expect(server!.port, equals(port));
    });

    test('server responds to health check', () async {
      final port = 38080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/health');
        final response = await request.close();

        expect(response.statusCode, equals(200));
      } finally {
        client.close();
      }
    });

    test('server adds CORS headers to responses', () async {
      final port = 38080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/health');
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
      final port = 38080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        final request = await client.open(
          'OPTIONS',
          'localhost',
          port,
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
      final port = 38080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      // InternetAddress.anyIPv4 should allow connections
      expect(server!.address.type, equals(InternetAddressType.IPv4));
    });
  });
}
