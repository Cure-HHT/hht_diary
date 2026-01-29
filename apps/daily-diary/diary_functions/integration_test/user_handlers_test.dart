// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// Integration tests for user handlers (enroll, sync, getRecords)
// Requires PostgreSQL database to be running

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:diary_functions/diary_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    // Initialize database
    // For local dev, default to no SSL (docker container doesn't support it)
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
  });

  tearDownAll(() async {
    await Database.instance.close();
  });

  Future<Map<String, dynamic>> getResponseJson(Response response) async {
    final chunks = await response.read().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Request createPostRequest(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json', ...?headers},
    );
  }

  /// Creates valid event data that passes the validate_diary_data trigger.
  /// The trigger requires: id (UUID), versioned_type, and event_data (object).
  /// For epistaxis: event_data needs id, startTime, lastModified.
  /// For survey: event_data needs id, completedAt, lastModified, survey array.
  Map<String, dynamic> createValidEventData({
    String type = 'epistaxis',
    String? severity,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final eventDataId = generateUserId();

    if (type == 'survey') {
      return {
        'id': generateUserId(),
        'versioned_type': 'survey-v1.0',
        'event_data': {
          'id': eventDataId,
          'completedAt': now,
          'lastModified': now,
          'survey': [
            {
              'question_id': 'q1',
              'question_text': 'Test question',
              'response': 'Test response',
            },
          ],
        },
      };
    }

    // Default: epistaxis
    return {
      'id': generateUserId(),
      'versioned_type': 'epistaxis-v1.0',
      'event_data': {
        'id': eventDataId,
        'startTime': now,
        'lastModified': now,
        if (severity != null) 'severity': severity,
      },
    };
  }

  /// Helper to create a user and return auth token
  Future<(String userId, String authToken)> createTestUser() async {
    final username = 'usertest_${DateTime.now().millisecondsSinceEpoch}';
    const passwordHash =
        '5e884898da28047d9166540d34e4b5eb9d06d6b9f7c0c0d3a75a3a75e8e0ab57';

    final request = createPostRequest('/api/v1/auth/register', {
      'username': username,
      'passwordHash': passwordHash,
      'appUuid': 'test-app-uuid',
    });

    final response = await registerHandler(request);
    final json = await getResponseJson(response);
    return (json['userId'] as String, json['jwt'] as String);
  }

  // enrollHandler is DEPRECATED - use linkHandler with sponsor portal codes
  group('enrollHandler (deprecated)', () {
    test('returns 410 Gone - legacy enrollment deprecated', () async {
      final request = createPostRequest('/api/v1/user/enroll', {
        'code': 'CUREHHT1',
      });

      final response = await enrollHandler(request);
      expect(response.statusCode, equals(410)); // Gone

      final json = await getResponseJson(response);
      expect(json['error'], contains('deprecated'));
    });
  });

  group('linkHandler', () {
    test(
      'returns 501 Not Implemented - patient linking not yet implemented',
      () async {
        final request = createPostRequest('/api/v1/user/link', {
          'code': 'CAXXXXXXXX',
        });

        final response = await linkHandler(request);
        expect(response.statusCode, equals(501));

        final json = await getResponseJson(response);
        expect(json['error'], contains('not yet implemented'));
      },
    );
  });

  group('syncHandler', () {
    late String testAuthToken;
    late String testUserId;

    setUpAll(() async {
      final (userId, token) = await createTestUser();
      testUserId = userId;
      testAuthToken = token;

      // Ensure DEFAULT site exists for testing
      await Database.instance.execute('''
        INSERT INTO sites (site_id, site_name, site_number, is_active)
        VALUES ('DEFAULT', 'Default Test Site', 'TEST-000', true)
        ON CONFLICT (site_id) DO UPDATE SET is_active = true
        ''');

      // Insert site assignment so the user can sync events
      // user_site_assignments links app user (patient_id) to site and study patient ID
      final studyPatientId = 'TEST-${DateTime.now().millisecondsSinceEpoch}';
      await Database.instance.execute(
        '''
        INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
        VALUES (@userId, 'DEFAULT', @studyPatientId, 'ACTIVE')
        ON CONFLICT (patient_id, site_id) DO NOTHING
        ''',
        parameters: {'userId': testUserId, 'studyPatientId': studyPatientId},
      );
    });

    tearDownAll(() async {
      // Clean up test data
      await Database.instance.execute(
        'DELETE FROM record_audit WHERE created_by = @userId',
        parameters: {'userId': testUserId},
      );
      await Database.instance.execute(
        'DELETE FROM user_site_assignments WHERE patient_id = @userId',
        parameters: {'userId': testUserId},
      );
      await Database.instance.execute(
        'DELETE FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );
    });

    test('returns 405 for non-POST requests', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/sync'),
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 401 without authorization', () async {
      final request = createPostRequest('/api/v1/user/sync', {'events': []});

      final response = await syncHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 400 when events is not an array', () async {
      final request = createPostRequest(
        '/api/v1/user/sync',
        {'events': 'not an array'},
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(400));

      final json = await getResponseJson(response);
      expect(json['error'], contains('array'));
    });

    test('syncs empty events array successfully', () async {
      final request = createPostRequest(
        '/api/v1/user/sync',
        {'events': []},
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['syncedCount'], equals(0));
      expect(json['syncedEventIds'], isEmpty);
    });

    test('syncs events with create operation', () async {
      final eventId = generateUserId(); // Generate unique UUID
      final request = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {
              'event_id': eventId,
              'event_type': 'create',
              'client_timestamp': DateTime.now().toIso8601String(),
              'data': createValidEventData(severity: 'moderate'),
              'metadata': {'change_reason': 'Initial entry'},
            },
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['success'], isTrue);
      expect(json['syncedCount'], equals(1));
      expect(json['syncedEventIds'], contains(eventId));
    });

    test('skips duplicate events (idempotent)', () async {
      final eventId = generateUserId();
      final validData = createValidEventData();

      // First sync
      final request1 = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {'event_id': eventId, 'event_type': 'create', 'data': validData},
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response1 = await syncHandler(request1);
      final json1 = await getResponseJson(response1);
      expect(json1['syncedCount'], equals(1));

      // Second sync with same event_id
      final request2 = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {'event_id': eventId, 'event_type': 'create', 'data': validData},
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response2 = await syncHandler(request2);
      final json2 = await getResponseJson(response2);
      expect(json2['syncedCount'], equals(0)); // Already synced
    });

    test('maps nosebleedrecorded to USER_CREATE', () async {
      final eventId = generateUserId();
      final request = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {
              'event_id': eventId,
              'event_type': 'nosebleedrecorded',
              'data': createValidEventData(severity: 'moderate'),
            },
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(200));

      // Verify operation was mapped correctly
      final result = await Database.instance.execute(
        'SELECT operation FROM record_audit WHERE event_uuid = @eventId::uuid',
        parameters: {'eventId': eventId},
      );
      expect(result.first[0], equals('USER_CREATE'));
    });

    test('maps nosebleedupdated to USER_UPDATE', () async {
      final eventId = generateUserId();
      final request = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {
              'event_id': eventId,
              'event_type': 'nosebleedupdated',
              'data': createValidEventData(severity: 'severe'),
            },
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(200));

      final result = await Database.instance.execute(
        'SELECT operation FROM record_audit WHERE event_uuid = @eventId::uuid',
        parameters: {'eventId': eventId},
      );
      expect(result.first[0], equals('USER_UPDATE'));
    });

    test('maps nosebleeddeleted to USER_DELETE', () async {
      // Testing delete through sync handler is complex due to:
      // 1. Delete trigger requires existing record_state entry
      // 2. Sync handler's idempotency blocks same event_uuid
      // 3. FK constraints prevent cleaning up record_audit
      //
      // Solution: Temporarily disable triggers to test the sync handler's
      // event type mapping in isolation. Then re-enable triggers.

      final eventId = generateUserId();
      final validData = createValidEventData();

      // Disable triggers to allow inserting without validation
      await Database.instance.execute(
        "SET session_replication_role = 'replica'",
      );

      try {
        // Sync the delete event - mapping should work
        final deleteRequest = createPostRequest(
          '/api/v1/user/sync',
          {
            'events': [
              {
                'event_id': eventId,
                'event_type': 'nosebleeddeleted',
                'data': validData,
              },
            ],
          },
          headers: {'Authorization': 'Bearer $testAuthToken'},
        );

        final response = await syncHandler(deleteRequest);
        final json = await getResponseJson(response);

        if (response.statusCode != 200) {
          fail('Sync failed with ${response.statusCode}: ${json['error']}');
        }

        // Verify the delete event was synced with correct operation
        final result = await Database.instance.execute(
          'SELECT operation FROM record_audit WHERE event_uuid = @eventId::uuid',
          parameters: {'eventId': eventId},
        );
        expect(result.first[0], equals('USER_DELETE'));
      } finally {
        // Re-enable triggers
        await Database.instance.execute(
          "SET session_replication_role = 'origin'",
        );

        // Cleanup the test data (with triggers disabled to avoid validation)
        await Database.instance.execute(
          "SET session_replication_role = 'replica'",
        );
        await Database.instance.execute(
          'DELETE FROM record_audit WHERE event_uuid = @eventId::uuid',
          parameters: {'eventId': eventId},
        );
        await Database.instance.execute(
          "SET session_replication_role = 'origin'",
        );
      }
    });

    test('syncs multiple events at once', () async {
      final event1 = generateUserId();
      final event2 = generateUserId();
      final event3 = generateUserId();

      final request = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {
              'event_id': event1,
              'event_type': 'create',
              'data': createValidEventData(),
            },
            {
              'event_id': event2,
              'event_type': 'update',
              'data': createValidEventData(),
            },
            {
              'event_id': event3,
              'event_type': 'surveysubmitted',
              'data': createValidEventData(type: 'survey'),
            },
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['syncedCount'], equals(3));
      expect(json['syncedEventIds'], containsAll([event1, event2, event3]));
    });

    test('skips events without event_id', () async {
      final validEventId = generateUserId();
      final validData = createValidEventData();

      final request = createPostRequest(
        '/api/v1/user/sync',
        {
          'events': [
            {'event_type': 'create', 'data': validData}, // No event_id
            {
              'event_id': validEventId,
              'event_type': 'create',
              'data': validData,
            },
          ],
        },
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await syncHandler(request);
      final json = await getResponseJson(response);

      expect(json['syncedCount'], equals(1));
      expect(json['syncedEventIds'], contains(validEventId));
    });

    test('updates last_active_at on sync', () async {
      // Get current last_active_at
      final before = await Database.instance.execute(
        'SELECT last_active_at FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );
      final lastActiveBefore = before.first[0];

      // Wait a bit to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 100));

      // Sync
      final request = createPostRequest(
        '/api/v1/user/sync',
        {'events': []},
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );
      await syncHandler(request);

      // Check last_active_at was updated
      final after = await Database.instance.execute(
        'SELECT last_active_at FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );
      final lastActiveAfter = after.first[0];

      expect(lastActiveAfter, isNotNull);
      if (lastActiveBefore != null) {
        expect(
          (lastActiveAfter as DateTime).isAfter(lastActiveBefore as DateTime),
          isTrue,
        );
      }
    });
  });

  group('getRecordsHandler', () {
    late String testAuthToken;
    late String testUserId;

    setUpAll(() async {
      final (userId, token) = await createTestUser();
      testUserId = userId;
      testAuthToken = token;
    });

    tearDownAll(() async {
      // Clean up
      await Database.instance.execute(
        'DELETE FROM record_audit WHERE created_by = @userId',
        parameters: {'userId': testUserId},
      );
      await Database.instance.execute(
        'DELETE FROM app_users WHERE user_id = @userId',
        parameters: {'userId': testUserId},
      );
    });

    test('returns 405 for non-POST requests', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/user/records'),
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(405));
    });

    test('returns 401 without authorization', () async {
      final request = createPostRequest('/api/v1/user/records', {});

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns empty records for new user', () async {
      final request = createPostRequest(
        '/api/v1/user/records',
        {},
        headers: {'Authorization': 'Bearer $testAuthToken'},
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(200));

      final json = await getResponseJson(response);
      expect(json['records'], isA<List>());
    });

    test('returns 401 with invalid JWT', () async {
      final request = createPostRequest(
        '/api/v1/user/records',
        {},
        headers: {'Authorization': 'Bearer invalid.token.here'},
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(401));
    });

    test('returns 401 with missing Bearer prefix', () async {
      final request = createPostRequest(
        '/api/v1/user/records',
        {},
        headers: {'Authorization': testAuthToken},
      );

      final response = await getRecordsHandler(request);
      expect(response.statusCode, equals(401));
    });
  });
}
