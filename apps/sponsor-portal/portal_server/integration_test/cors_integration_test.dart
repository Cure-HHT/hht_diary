
@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_server.dart';

void main() {
  late TestServer server;
  late http.Client client;

  setUpAll(() async {
    server = TestServer();
    await server.start();
    client = http.Client();
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
  });

  group('CORS Headers', () {
    test('GET responses include Access-Control-Allow-Origin', () async {
      final response =
      await client.get(Uri.parse('${server.baseUrl}/health'));

      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], equals('*'));
    });

    test(
      'OPTIONS preflight includes x-active-role in Access-Control-Allow-Headers',
          () async {
        final request = http.Request(
          'OPTIONS',
          Uri.parse('${server.baseUrl}/api/v1/portal/me'),
        )
          ..headers.addAll({
            'Origin': 'http://localhost:3000',
            'Access-Control-Request-Method': 'GET',
            'Access-Control-Request-Headers':
            'Origin, Content-Type, Authorization, x-active-role',
          });

        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        expect(response.statusCode, equals(200));

        // Validate basic CORS headers
        expect(response.headers['access-control-allow-origin'], equals('*'));
        expect(response.headers['access-control-allow-methods'], isNotNull);

        // Validate allowed headers include x-active-role
        final allowHeaders =
        response.headers['access-control-allow-headers'];

        expect(allowHeaders, isNotNull);

        final normalizedHeaders = allowHeaders!
            .toLowerCase()
            .split(',')
            .map((h) => h.trim())
            .toList();

        expect(normalizedHeaders, contains('x-active-role'));
      },
    );
  });
}