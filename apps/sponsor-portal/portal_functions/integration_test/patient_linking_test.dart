// IMPLEMENTS REQUIREMENTS:
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00073: Patient Status Definitions
//
// Integration tests for patient linking handlers
// Requires PostgreSQL database with schema applied and Firebase Auth emulator

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  // Test user data - using fixed UUIDs for reproducibility
  const testInvestigatorId = '99992000-0000-0000-0000-000000000001';
  const testInvestigatorEmail = 'investigator@linking-test.example.com';
  const testInvestigatorFirebaseUid = 'firebase-linking-investigator-uid';

  const testAdminId = '99992000-0000-0000-0000-000000000002';
  const testAdminEmail = 'admin@linking-test.example.com';
  const testAdminFirebaseUid = 'firebase-linking-admin-uid';

  const testSiteId = 'test-linking-site-001';
  const testSiteName = 'Linking Test Site';

  const testPatientNotConnected = 'test-link-patient-001';
  const testPatientConnected = 'test-link-patient-002';
  const testPatientDisconnected = 'test-link-patient-003';
  const testPatientLinking = 'test-link-patient-004';

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

    // Clean up any previous test data
    await _cleanupTestData();

    final db = Database.instance;

    // Create test site
    await db.execute(
      '''
      INSERT INTO sites (site_id, site_name, site_number, is_active)
      VALUES (@siteId, @siteName, 'LINK-TEST-001', true)
      ON CONFLICT (site_id) DO UPDATE SET site_name = EXCLUDED.site_name
      ''',
      parameters: {'siteId': testSiteId, 'siteName': testSiteName},
    );

    // Create test Investigator user
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Test Investigator', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testInvestigatorId,
        'email': testInvestigatorEmail,
        'firebaseUid': testInvestigatorFirebaseUid,
      },
    );

    // Add Investigator role
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Investigator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testInvestigatorId},
    );

    // Grant site access to Investigator
    await db.execute(
      '''
      INSERT INTO portal_user_site_access (user_id, site_id)
      VALUES (@userId::uuid, @siteId)
      ON CONFLICT (user_id, site_id) DO NOTHING
      ''',
      parameters: {'userId': testInvestigatorId, 'siteId': testSiteId},
    );

    // Create test Admin user (for permission denied tests)
    await db.execute(
      '''
      INSERT INTO portal_users (id, email, name, firebase_uid, status)
      VALUES (@id::uuid, @email, 'Test Admin', @firebaseUid, 'active')
      ON CONFLICT (email) DO NOTHING
      ''',
      parameters: {
        'id': testAdminId,
        'email': testAdminEmail,
        'firebaseUid': testAdminFirebaseUid,
      },
    );

    // Add Administrator role (non-Investigator)
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role)
      VALUES (@userId::uuid, 'Administrator')
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': testAdminId},
    );

    // Create test patients with various statuses
    for (final patient in [
      {
        'id': testPatientNotConnected,
        'status': 'not_connected',
        'key': 'LINK-001',
      },
      {'id': testPatientConnected, 'status': 'connected', 'key': 'LINK-002'},
      {
        'id': testPatientDisconnected,
        'status': 'disconnected',
        'key': 'LINK-003',
      },
      {
        'id': testPatientLinking,
        'status': 'linking_in_progress',
        'key': 'LINK-004',
      },
    ]) {
      await db.execute(
        '''
        INSERT INTO patients (patient_id, site_id, edc_subject_key, mobile_linking_status)
        VALUES (@patientId, @siteId, @subjectKey, @status::mobile_linking_status)
        ON CONFLICT (patient_id) DO UPDATE SET mobile_linking_status = EXCLUDED.mobile_linking_status
        ''',
        parameters: {
          'patientId': patient['id'],
          'siteId': testSiteId,
          'subjectKey': patient['key'],
          'status': patient['status'],
        },
      );
    }

    // Create an active linking code for the linking_in_progress patient
    await db.execute(
      '''
      INSERT INTO patient_linking_codes (patient_id, code, code_hash, generated_by, expires_at)
      VALUES (@patientId, @code, @codeHash, @generatedBy::uuid, @expiresAt)
      ON CONFLICT DO NOTHING
      ''',
      parameters: {
        'patientId': testPatientLinking,
        'code': 'CATEST1234',
        'codeHash': hashLinkingCode('CATEST1234'),
        'generatedBy': testInvestigatorId,
        'expiresAt': DateTime.now().add(Duration(hours: 72)).toIso8601String(),
      },
    );
  });

  tearDownAll(() async {
    await _cleanupTestData();
    await Database.instance.close();
  });

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Request createPostRequest(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: body != null ? jsonEncode(body) : null,
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  Request createGetRequest(String path, {Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost$path'), headers: headers);
  }

  group('generatePatientLinkingCodeHandler', () {
    test('returns 401 without authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/patients/$testPatientNotConnected/link-code',
      );
      final response = await generatePatientLinkingCodeHandler(
        request,
        testPatientNotConnected,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns 401 with invalid Bearer token', () async {
      final request = createPostRequest(
        '/api/v1/portal/patients/$testPatientNotConnected/link-code',
        headers: {'authorization': 'Bearer invalid-token'},
      );
      final response = await generatePatientLinkingCodeHandler(
        request,
        testPatientNotConnected,
      );

      expect(response.statusCode, equals(401));
    });

    test('returns 401 without Bearer prefix', () async {
      final request = createPostRequest(
        '/api/v1/portal/patients/$testPatientNotConnected/link-code',
        headers: {'authorization': 'some-token'},
      );
      final response = await generatePatientLinkingCodeHandler(
        request,
        testPatientNotConnected,
      );

      expect(response.statusCode, equals(401));
    });

    test('returns JSON content type on all error responses', () async {
      final requests = [
        createPostRequest('/api/v1/portal/patients/test/link-code'),
        createPostRequest(
          '/api/v1/portal/patients/test/link-code',
          headers: {'authorization': ''},
        ),
        createPostRequest(
          '/api/v1/portal/patients/test/link-code',
          headers: {'authorization': 'invalid'},
        ),
      ];

      for (final request in requests) {
        final response = await generatePatientLinkingCodeHandler(
          request,
          'test',
        );
        expect(response.headers['content-type'], equals('application/json'));
      }
    });
  });

  group('getPatientLinkingCodeHandler', () {
    test('returns 401 without authorization header', () async {
      final request = createGetRequest(
        '/api/v1/portal/patients/$testPatientLinking/link-code',
      );
      final response = await getPatientLinkingCodeHandler(
        request,
        testPatientLinking,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns JSON content type on all error responses', () async {
      final requests = [
        createGetRequest('/api/v1/portal/patients/test/link-code'),
        createGetRequest(
          '/api/v1/portal/patients/test/link-code',
          headers: {'authorization': ''},
        ),
        createGetRequest(
          '/api/v1/portal/patients/test/link-code',
          headers: {'authorization': 'Bearer invalid'},
        ),
      ];

      for (final request in requests) {
        final response = await getPatientLinkingCodeHandler(request, 'test');
        expect(response.headers['content-type'], equals('application/json'));
      }
    });
  });

  group('disconnectPatientHandler', () {
    test('returns 401 without authorization header', () async {
      final request = createPostRequest(
        '/api/v1/portal/patients/$testPatientConnected/disconnect',
        body: {'reason': 'Device Issues'},
      );
      final response = await disconnectPatientHandler(
        request,
        testPatientConnected,
      );

      expect(response.statusCode, equals(401));
      final json = await getResponseJson(response);
      expect(json['error'], contains('authorization'));
    });

    test('returns JSON content type on all error responses', () async {
      final requests = [
        createPostRequest('/api/v1/portal/patients/test/disconnect'),
        createPostRequest(
          '/api/v1/portal/patients/test/disconnect',
          headers: {'authorization': ''},
        ),
        createPostRequest(
          '/api/v1/portal/patients/test/disconnect',
          headers: {'authorization': 'invalid'},
        ),
      ];

      for (final request in requests) {
        final response = await disconnectPatientHandler(request, 'test');
        expect(response.headers['content-type'], equals('application/json'));
      }
    });
  });

  group('Utility functions', () {
    test('generatePatientLinkingCode produces valid codes', () {
      for (var i = 0; i < 100; i++) {
        final code = generatePatientLinkingCode('CA');

        // Length check
        expect(code.length, equals(10));

        // Prefix check
        expect(code.startsWith('CA'), isTrue);

        // No ambiguous characters
        const ambiguous = ['I', '1', 'O', '0', 'S', '5', 'Z', '2'];
        for (final char in ambiguous) {
          expect(code.substring(2).contains(char), isFalse);
        }
      }
    });

    test('formatLinkingCodeForDisplay formats correctly', () {
      expect(formatLinkingCodeForDisplay('CAABCDEFGH'), equals('CAABC-DEFGH'));
      expect(formatLinkingCodeForDisplay('CA12345678'), equals('CA123-45678'));
      expect(formatLinkingCodeForDisplay('SHORT'), equals('SHORT'));
      expect(formatLinkingCodeForDisplay(''), equals(''));
    });

    test('hashLinkingCode produces consistent SHA-256 hashes', () {
      const code = 'CAABCDEFGH';
      final hash1 = hashLinkingCode(code);
      final hash2 = hashLinkingCode(code);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 is 64 hex chars
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash1), isTrue);
    });

    test('linkingCodeExpiration is 72 hours', () {
      expect(linkingCodeExpiration, equals(Duration(hours: 72)));
    });

    test('validDisconnectReasons contains expected values', () {
      expect(validDisconnectReasons, contains('Device Issues'));
      expect(validDisconnectReasons, contains('Technical Issues'));
      expect(validDisconnectReasons, contains('Other'));
      expect(validDisconnectReasons.length, equals(3));
    });
  });
}

Future<void> _cleanupTestData() async {
  final db = Database.instance;

  // Clean up in correct order for foreign key constraints
  const testPatientId1 = 'test-link-patient-001';
  const testPatientId2 = 'test-link-patient-002';
  const testPatientId3 = 'test-link-patient-003';
  const testPatientId4 = 'test-link-patient-004';

  const testUserId1 = '99992000-0000-0000-0000-000000000001';
  const testUserId2 = '99992000-0000-0000-0000-000000000002';

  // Delete linking codes by patient
  await db.execute(
    'DELETE FROM patient_linking_codes WHERE patient_id IN (@p1, @p2, @p3, @p4)',
    parameters: {
      'p1': testPatientId1,
      'p2': testPatientId2,
      'p3': testPatientId3,
      'p4': testPatientId4,
    },
  );

  // Delete admin action logs by target_resource
  await db.execute(
    "DELETE FROM admin_action_log WHERE target_resource LIKE 'patient:test-link-%'",
  );

  // Delete patients
  await db.execute(
    'DELETE FROM patients WHERE patient_id IN (@p1, @p2, @p3, @p4)',
    parameters: {
      'p1': testPatientId1,
      'p2': testPatientId2,
      'p3': testPatientId3,
      'p4': testPatientId4,
    },
  );

  // Delete user site access
  await db.execute(
    'DELETE FROM portal_user_site_access WHERE user_id IN (@u1::uuid, @u2::uuid)',
    parameters: {'u1': testUserId1, 'u2': testUserId2},
  );

  // Delete user roles
  await db.execute(
    'DELETE FROM portal_user_roles WHERE user_id IN (@u1::uuid, @u2::uuid)',
    parameters: {'u1': testUserId1, 'u2': testUserId2},
  );

  // Delete users
  await db.execute(
    'DELETE FROM portal_users WHERE email LIKE @pattern',
    parameters: {'pattern': '%@linking-test.example.com'},
  );

  // Delete test site
  await db.execute("DELETE FROM sites WHERE site_id = 'test-linking-site-001'");
}
