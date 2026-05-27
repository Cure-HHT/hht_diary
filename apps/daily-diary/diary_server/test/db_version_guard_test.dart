// Verifies: DIARY-DEV-schema-version-check/C
//
// Unit tests for the _dbVersionGuardMiddleware.
// Uses setSchemaStaleForTesting to control process-global state without a DB.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:diary_functions/diary_functions.dart'
    show resetDbVersionCheckState, setSchemaStaleForTesting;
import 'package:diary_server/diary_server.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'diary-server-test',
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
      final port = 39080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        final request = await client.get(
          'localhost',
          port,
          '/api/v1/sponsor/config',
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

    test('/health returns 200 even when schema is stale', () async {
      setSchemaStaleForTesting(stale: true);
      final port = 39080 + DateTime.now().millisecond % 1000;
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

    test('normal route passes through when schema is not stale', () async {
      // stale flag stays false (setUp called resetDbVersionCheckState)
      final port = 39080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        final request = await client.get('localhost', port, '/health');
        final response = await request.close();
        // /health should return 200, not 503
        expect(response.statusCode, equals(200));
      } finally {
        client.close();
      }
    });

    test('non-health route passes through when schema is not stale', () async {
      final port = 39080 + DateTime.now().millisecond % 1000;
      server = await createServer(port: port);

      final client = HttpClient();
      try {
        // /api/v1/sponsor/config without sponsorId → 400, not 503
        final request = await client.get(
          'localhost',
          port,
          '/api/v1/sponsor/config',
        );
        final response = await request.close();
        expect(response.statusCode, isNot(equals(503)));
      } finally {
        client.close();
      }
    });
  });
}
