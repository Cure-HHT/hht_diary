// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Integration tests for portal server API endpoints
// Requires PostgreSQL database and Firebase Auth emulator

@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:portal_functions/portal_functions.dart';
import 'package:test/test.dart';

import 'test_server.dart';

void main() {
  late TestServer server;
  late http.Client client;

  // Test user data
  const testAdminId = '99990000-0000-0000-0000-000000000101';
  const testAdminEmail = 'admin@portal-api-test.example.com';
  const testAdminFirebaseUid = 'firebase-admin-api-test-uid';

  setUpAll(() async {
    server = TestServer();
    await server.start();
    client = http.Client();

    // Clean up and create test data
    final db = Database.instance;

    // Clean up previous test data
    await db.execute(
      'DELETE FROM portal_user_roles WHERE user_id = @adminId::uuid',
      parameters: {'adminId': testAdminId},
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@portal-api-test.example.com'},
    );

    // Create test admin user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, role, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Test API Admin', 'Administrator', @firebaseUid, 'active')
      ''',
      parameters: {
        'id': testAdminId,
        'email': testAdminEmail,
        'firebaseUid': testAdminFirebaseUid,
      },
    );
  });

  tearDownAll(() async {
    // Clean up test data
    final db = Database.instance;
    await db.execute(
      'DELETE FROM portal_user_roles WHERE user_id = @adminId::uuid',
      parameters: {'adminId': testAdminId},
    );
    await db.execute(
      'DELETE FROM portal_users WHERE email LIKE @pattern',
      parameters: {'pattern': '%@portal-api-test.example.com'},
    );

    client.close();
    await server.stop();
  });

  /// Create a Firebase emulator JWT token for testing
  String createEmulatorToken({required String uid, required String email}) {
    // Firebase Auth emulator accepts tokens with 'none' algorithm
    final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': uid,
          'user_id': uid,
          'email': email,
          'email_verified': true,
          'iat': now,
          'exp': now + 3600,
        }),
      ),
    );
    return '$header.$payload.';
  }

  group('Health Endpoint', () {
    test('GET /health returns 200', () async {
      final response = await client.get(Uri.parse('${server.baseUrl}/health'));

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['status'], equals('ok'));
    });
  });

  group('Sponsor Config Endpoint', () {
    test('GET /api/v1/sponsor/config without sponsorId returns 400', () async {
      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/sponsor/config'),
      );

      expect(response.statusCode, equals(400));
    });

    test(
      'GET /api/v1/sponsor/config with valid sponsorId returns 200',
      () async {
        final response = await client.get(
          Uri.parse(
            '${server.baseUrl}/api/v1/sponsor/config?sponsorId=curehht',
          ),
        );

        expect(response.statusCode, equals(200));
        final body = jsonDecode(response.body);
        expect(body['sponsorId'], equals('curehht'));
      },
    );

    test(
      'GET /api/v1/sponsor/config with unknown sponsorId returns default config',
      () async {
        final response = await client.get(
          Uri.parse(
            '${server.baseUrl}/api/v1/sponsor/config?sponsorId=unknown',
          ),
        );

        // Returns 200 with default config for unknown sponsors
        expect(response.statusCode, equals(200));
      },
    );
  });

  group('Portal Me Endpoint', () {
    test('GET /api/v1/portal/me without token returns 401', () async {
      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/portal/me'),
      );

      expect(response.statusCode, equals(401));
    });

    test('GET /api/v1/portal/me with valid token returns user info', () async {
      final token = createEmulatorToken(
        uid: testAdminFirebaseUid,
        email: testAdminEmail,
      );

      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/portal/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['email'], equals(testAdminEmail));
      // Role is returned as active_role in the response (snake_case)
      expect(body['active_role'], equals('Administrator'));
    });

    test(
      'GET /api/v1/portal/me with unbound uid returns 401 uid_not_bound',
      () async {
        // REQ-d00167-A: auth gate is uid-only. A token whose uid has no
        // matching portal_users row is rejected with 401 + uid_not_bound.
        final token = createEmulatorToken(
          uid: 'unknown-firebase-uid',
          email: 'unknown@example.com',
        );

        final response = await client.get(
          Uri.parse('${server.baseUrl}/api/v1/portal/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(401));
        final body = jsonDecode(response.body);
        expect(body['code'], equals('uid_not_bound'));
      },
    );
  });

  group('Portal Users Endpoint', () {
    test('GET /api/v1/portal/users without token returns 403', () async {
      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/portal/users'),
      );

      // Returns 403 because no valid auth context
      expect(response.statusCode, equals(403));
    });

    test('GET /api/v1/portal/users as admin returns user list', () async {
      final token = createEmulatorToken(
        uid: testAdminFirebaseUid,
        email: testAdminEmail,
      );

      final response = await client.get(
        Uri.parse('${server.baseUrl}/api/v1/portal/users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      // Response is a map with 'users' key containing the list
      expect(body['users'], isA<List>());
      expect(body['users'], isNotEmpty);
    });
  });

  group('Activation Endpoints', () {
    test(
      'GET /api/v1/portal/activate/<code> with invalid code returns 401',
      () async {
        final response = await client.get(
          Uri.parse('${server.baseUrl}/api/v1/portal/activate/INVALID-CODE'),
        );

        expect(response.statusCode, equals(401));
      },
    );

    test(
      'POST /api/v1/portal/activate with unknown code returns 400 code_invalid',
      () async {
        // REQ-d00166-A,B: /portal/activate is bearer-free under server-owned
        // activation. The handler accepts {code, password} from any caller
        // and rejects unknown codes with 400 code_invalid.
        final response = await client.post(
          Uri.parse('${server.baseUrl}/api/v1/portal/activate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': 'XXXXX-XXXXX',
            'password': 'irrelevant-pw-12345',
          }),
        );

        expect(response.statusCode, equals(400));
        final body = jsonDecode(response.body);
        expect(body['code'], equals('code_invalid'));
      },
    );
  });

  group('CORS Headers', () {
    test('Response includes CORS headers', () async {
      final response = await client.get(Uri.parse('${server.baseUrl}/health'));

      expect(response.headers['access-control-allow-origin'], equals('*'));
    });

    test('OPTIONS request returns 200 with CORS headers', () async {
      final request = http.Request(
        'OPTIONS',
        Uri.parse('${server.baseUrl}/api/v1/portal/me'),
      );
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      expect(response.headers['access-control-allow-methods'], isNotNull);
    });
  });
}
