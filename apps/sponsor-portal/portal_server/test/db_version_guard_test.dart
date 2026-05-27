// Verifies: DIARY-DEV-schema-version-check/C
//
// Unit tests for the _dbVersionGuardMiddleware.
// Uses setSchemaStaleForTesting to control process-global state without a DB.
// Also asserts that 503 responses carry CORS headers (portal serves browsers).

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:portal_functions/portal_functions.dart'
    show resetDbVersionCheckState, setSchemaStaleForTesting;
import 'package:portal_server/portal_server.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-server-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });

  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  setUp(resetDbVersionCheckState);
  tearDown(resetDbVersionCheckState);

  group('_dbVersionGuardMiddleware (via createServer)', () {
    HttpServer? server;

    tearDown(() async {
      await server?.close(force: true);
      server = null;
    });

    test('normal route returns 503 when schema is stale', () async {
      setSchemaStaleForTesting(stale: true);
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        final request = await client.get(
          'localhost',
          server!.port,
          '/api/v1/auth/login',
        );
        final response = await request.close();
        expect(response.statusCode, equals(503));

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['error'], equals('database schema version behind'));
        expect(json, containsPair('needs', isA<int>()));
        expect(json, contains('found'));
      } finally {
        client.close();
      }
    });

    test(
      '503 response carries CORS headers so browsers can read the error',
      () async {
        setSchemaStaleForTesting(stale: true);
        server = await createServer(port: 0);

        final client = HttpClient();
        try {
          final request = await client.get(
            'localhost',
            server!.port,
            '/api/v1/auth/login',
          );
          final response = await request.close();
          expect(response.statusCode, equals(503));

          // CORS header must be present so browsers can read the error body.
          expect(
            response.headers.value('access-control-allow-origin'),
            equals('*'),
          );
        } finally {
          client.close();
        }
      },
    );

    test('/health returns 200 even when schema is stale', () async {
      setSchemaStaleForTesting(stale: true);
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

    test('normal route passes through when schema is not stale', () async {
      // stale flag stays false (setUp called resetDbVersionCheckState)
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        // /health should return 200, not 503
        final request = await client.get('localhost', server!.port, '/health');
        final response = await request.close();
        expect(response.statusCode, equals(200));
      } finally {
        client.close();
      }
    });

    test('non-health route passes through when schema is not stale', () async {
      server = await createServer(port: 0);

      final client = HttpClient();
      try {
        // A real route that returns non-503 when DB is healthy
        final request = await client.get(
          'localhost',
          server!.port,
          '/api/v1/auth/login',
        );
        final response = await request.close();
        expect(response.statusCode, isNot(equals(503)));
      } finally {
        client.close();
      }
    });
  });
}
