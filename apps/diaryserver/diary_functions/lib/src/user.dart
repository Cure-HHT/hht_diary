// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// User enrollment and data sync handlers - converted from Firebase user.ts
// Sync writes to record_audit (event store), not separate tables

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

// Valid enrollment code pattern: CUREHHT followed by a digit (0-9)
final _enrollmentCodePattern = RegExp(r'^CUREHHT[0-9]$', caseSensitive: false);

/// Enrollment handler - enrolls user in a clinical study
/// POST /api/v1/user/enroll
/// Authorization: Bearer <jwt>
/// Body: { code }
///
/// Links existing app user to a clinical study via enrollment code
Future<Response> enrollHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT - user must already have an account
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final code = body['code'] as String?;

    if (code == null || code.isEmpty) {
      return _jsonResponse({'error': 'Enrollment code is required'}, 400);
    }

    final normalizedCode = code.toUpperCase();
    if (!_enrollmentCodePattern.hasMatch(normalizedCode)) {
      return _jsonResponse({'error': 'Invalid enrollment code'}, 400);
    }

    final db = Database.instance;

    // Check if code has been used
    final existing = await db.execute(
      'SELECT enrollment_id FROM study_enrollments WHERE enrollment_code = @code',
      parameters: {'code': normalizedCode},
    );

    if (existing.isNotEmpty) {
      return _jsonResponse({
        'error': 'This enrollment code has already been used',
      }, 409);
    }

    // Verify user exists
    final userResult = await db.execute(
      'SELECT user_id FROM app_users WHERE auth_code = @authCode',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final userId = userResult.first[0] as String;

    // Extract sponsor from enrollment code (e.g., CUREHHT1 -> curehht)
    final sponsorId = normalizedCode
        .replaceAll(RegExp(r'[0-9]$'), '')
        .toLowerCase();

    // Create study enrollment
    await db.execute(
      '''
      INSERT INTO study_enrollments (user_id, enrollment_code, sponsor_id, status)
      VALUES (@userId, @code, @sponsorId, 'ACTIVE')
      ''',
      parameters: {
        'userId': userId,
        'code': normalizedCode,
        'sponsorId': sponsorId,
      },
    );

    return _jsonResponse({
      'success': true,
      'enrollmentCode': normalizedCode,
      'sponsorId': sponsorId,
    });
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Sync handler - appends events to record_audit (event store)
/// POST /api/v1/user/sync
/// Authorization: Bearer <jwt>
/// Body: { events: [...] }
///
/// Events from append_only_datastore are written to record_audit
Future<Response> syncHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final db = Database.instance;

    // Look up user and their enrollment
    final userResult = await db.execute(
      '''
      SELECT u.user_id, e.site_id, e.patient_id
      FROM app_users u
      LEFT JOIN study_enrollments e ON u.user_id = e.user_id AND e.status = 'ACTIVE'
      WHERE u.auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final row = userResult.first;
    final userId = row[0] as String;
    final siteId = row[1] as String?;
    final patientId = row[2] as String? ?? userId; // Use userId if no patientId

    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final events = body['events'];
    if (events is! List) {
      return _jsonResponse({'error': 'Events must be an array'}, 400);
    }

    final syncedEventIds = <String>[];

    // Insert events into record_audit (event store)
    for (final event in events) {
      if (event is! Map) continue;

      final eventId = event['event_id'] as String?;
      if (eventId == null) continue;

      // Check if event already exists
      final existing = await db.execute(
        'SELECT audit_id FROM record_audit WHERE event_uuid = @eventId::uuid',
        parameters: {'eventId': eventId},
      );

      if (existing.isEmpty) {
        // Map client event to record_audit columns
        final eventType = event['event_type'] as String? ?? 'USER_CREATE';
        final operation = _mapEventTypeToOperation(eventType);

        await db.execute(
          '''
          INSERT INTO record_audit (
            event_uuid, patient_id, site_id, operation, data,
            created_by, role, client_timestamp, change_reason
          ) VALUES (
            @eventId::uuid, @patientId, @siteId, @operation, @data::jsonb,
            @userId, 'USER', @clientTimestamp::timestamptz, @changeReason
          )
          ''',
          parameters: {
            'eventId': eventId,
            'patientId': patientId,
            'siteId': siteId ?? 'DEFAULT', // Fallback for non-enrolled users
            'operation': operation,
            'data': jsonEncode(event['data'] ?? {}),
            'userId': userId,
            'clientTimestamp':
                event['client_timestamp'] ?? DateTime.now().toIso8601String(),
            'changeReason':
                event['metadata']?['change_reason'] ?? 'Synced from mobile app',
          },
        );

        syncedEventIds.add(eventId);
      }
    }

    // Update last active
    await db.execute(
      'UPDATE app_users SET last_active_at = now() WHERE user_id = @userId',
      parameters: {'userId': userId},
    );

    return _jsonResponse({
      'success': true,
      'syncedCount': syncedEventIds.length,
      'syncedEventIds': syncedEventIds,
    });
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error: $e'}, 500);
  }
}

/// Get records handler - returns current state from record_state
/// POST /api/v1/user/records
/// Authorization: Bearer <jwt>
Future<Response> getRecordsHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final db = Database.instance;

    // Look up user and patient_id
    final userResult = await db.execute(
      '''
      SELECT u.user_id, e.patient_id
      FROM app_users u
      LEFT JOIN study_enrollments e ON u.user_id = e.user_id AND e.status = 'ACTIVE'
      WHERE u.auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final row = userResult.first;
    final userId = row[0] as String;
    final patientId = row[1] as String? ?? userId;

    // Fetch current state from record_state (materialized view)
    final recordsResult = await db.execute(
      '''
      SELECT event_uuid, current_data, version, updated_at
      FROM record_state
      WHERE patient_id = @patientId AND is_deleted = false
      ORDER BY updated_at DESC
      ''',
      parameters: {'patientId': patientId},
    );

    final records = recordsResult.map((r) {
      return {
        'event_uuid': r[0],
        'data': r[1], // Already JSONB, will be serialized
        'version': r[2],
        'updated_at': (r[3] as DateTime).toIso8601String(),
      };
    }).toList();

    return _jsonResponse({'records': records});
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Map client event type to record_audit operation
String _mapEventTypeToOperation(String eventType) {
  switch (eventType.toLowerCase()) {
    case 'create':
    case 'nosebleedrecorded':
    case 'surveysubmitted':
      return 'USER_CREATE';
    case 'update':
    case 'nosebleedupdated':
      return 'USER_UPDATE';
    case 'delete':
    case 'nosebleeddeleted':
      return 'USER_DELETE';
    default:
      return 'USER_CREATE';
  }
}

Future<Map<String, dynamic>?> _parseJson(Request request) async {
  try {
    final body = await request.readAsString();
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
