// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// User linking and data sync handlers
// Patient linking uses patient_linking_codes (via sponsor portal)
// Sync writes to record_audit (event store), not separate tables

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

/// Link handler - links app user to a patient via linking code
/// POST /api/v1/user/link
/// Authorization: Bearer <jwt>
/// Body: { code }
///
/// Validates linking code from sponsor portal and links app user to patient.
/// This is the mobile app side of the patient linking flow.
/// TODO: Implement linking code validation against patient_linking_codes table
Future<Response> linkHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  // Patient linking will be implemented in a future ticket
  // The sponsor portal generates codes via patient_linking_codes table
  // This endpoint will validate the code and create the link
  return _jsonResponse({
    'error':
        'Patient linking not yet implemented. Use sponsor portal to generate linking codes.',
  }, 501);
}

/// Legacy enrollment handler - DEPRECATED
/// Use linkHandler instead for patient linking via sponsor portal codes
Future<Response> enrollHandler(Request request) async {
  return _jsonResponse({
    'error':
        'Legacy enrollment deprecated. Use /api/v1/user/link with sponsor portal linking codes.',
  }, 410); // 410 Gone
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

    // Look up user and their site assignment
    final userResult = await db.execute(
      '''
      SELECT u.user_id, usa.site_id, usa.study_patient_id
      FROM app_users u
      LEFT JOIN user_site_assignments usa ON u.user_id = usa.patient_id
        AND usa.enrollment_status = 'ACTIVE'
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

    // Look up user and patient_id from site assignment
    final userResult = await db.execute(
      '''
      SELECT u.user_id, usa.study_patient_id
      FROM app_users u
      LEFT JOIN user_site_assignments usa ON u.user_id = usa.patient_id
        AND usa.enrollment_status = 'ACTIVE'
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
