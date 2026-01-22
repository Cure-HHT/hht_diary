// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00041: Sponsor Role Mapping Schema
//
// Integration tests for sponsor handlers
// Requires PostgreSQL database with schema applied

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    // Initialize database
    final sslEnv = Platform.environment['DB_SSL'];
    final useSsl = sslEnv == 'true';

    final config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: useSsl,
    );

    await Database.instance.initialize(config);

    // Ensure test data exists
    final db = Database.instance;
    await db.execute('''
      INSERT INTO sponsor_role_mapping (sponsor_id, sponsor_role_name, mapped_role)
      VALUES
        ('test-sponsor', 'Test Admin Role', 'Administrator'),
        ('test-sponsor', 'Test Investigator Role', 'Investigator'),
        ('test-sponsor', 'Test Auditor Role', 'Auditor')
      ON CONFLICT (sponsor_id, sponsor_role_name) DO NOTHING
      ''');
  });

  tearDownAll(() async {
    // Clean up test data
    final db = Database.instance;
    await db.execute(
      "DELETE FROM sponsor_role_mapping WHERE sponsor_id = 'test-sponsor'",
    );
    await Database.instance.close();
  });

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  group('sponsorRoleMappingsHandler', () {
    test('returns 405 for non-GET requests', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/v1/sponsor/roles?sponsorId=test'),
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(405));
      final json = await getResponseJson(response);
      expect(json['error'], contains('Method not allowed'));
    });

    test('returns 400 when sponsorId is missing', () async {
      final request = createGetRequest('/api/v1/sponsor/roles');
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('sponsorId'));
    });

    test('returns 400 for empty sponsorId', () async {
      final request = createGetRequest('/api/v1/sponsor/roles?sponsorId=');
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(400));
      final json = await getResponseJson(response);
      expect(json['error'], contains('sponsorId'));
    });

    test('returns role mappings for known sponsor', () async {
      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=test-sponsor',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('test-sponsor'));
      expect(json['mappings'], isA<List>());

      final mappings = json['mappings'] as List;
      expect(mappings.length, greaterThanOrEqualTo(3));

      // Check that mappings contain the expected fields
      for (final mapping in mappings) {
        expect(mapping, containsPair('sponsorName', isA<String>()));
        expect(mapping, containsPair('systemRole', isA<String>()));
      }
    });

    test('returns empty mappings for unknown sponsor', () async {
      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=nonexistent',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('nonexistent'));
      expect(json['mappings'], isEmpty);
    });

    test('normalizes sponsorId to lowercase', () async {
      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=TEST-SPONSOR',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('test-sponsor'));
    });

    test('trims whitespace from sponsorId', () async {
      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=%20test-sponsor%20',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      expect(json['sponsorId'], equals('test-sponsor'));
    });

    test('returns JSON content type', () async {
      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=test-sponsor',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.headers['Content-Type'], equals('application/json'));
    });

    test('excludes Developer Admin from returned mappings', () async {
      // First add a Developer Admin mapping (it should be excluded from results)
      final db = Database.instance;
      await db.execute('''
        INSERT INTO sponsor_role_mapping (sponsor_id, sponsor_role_name, mapped_role)
        VALUES ('test-sponsor', 'System Developer', 'Developer Admin')
        ON CONFLICT (sponsor_id, sponsor_role_name) DO NOTHING
        ''');

      final request = createGetRequest(
        '/api/v1/sponsor/roles?sponsorId=test-sponsor',
      );
      final response = await sponsorRoleMappingsHandler(request);

      expect(response.statusCode, equals(200));
      final json = await getResponseJson(response);
      final mappings = json['mappings'] as List;

      // Verify Developer Admin is not in the results
      final hasDevAdmin = mappings.any(
        (m) =>
            m['systemRole'] == 'Developer Admin' ||
            m['sponsorName'] == 'System Developer',
      );
      expect(hasDevAdmin, isFalse);

      // Clean up
      await db.execute(
        "DELETE FROM sponsor_role_mapping WHERE sponsor_id = 'test-sponsor' AND sponsor_role_name = 'System Developer'",
      );
    });
  });
}
