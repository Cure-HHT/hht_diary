// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00073: Patient Status Definitions
//
// User linking and data sync handlers
// Patient linking uses patient_linking_codes (via sponsor portal)
// Sync writes to record_audit (event store), not separate tables

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

/// Hash a linking code using SHA-256 for secure validation lookup
/// Must match the hash algorithm used in sponsor portal (REQ-d00078)
String _hashLinkingCode(String code) {
  final bytes = utf8.encode(code);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Link handler - links app user to a patient via linking code
/// POST /api/v1/user/link
/// Authorization: Bearer <jwt>
/// Body: { code, appUuid? }
///
/// Validates linking code from sponsor portal and links app user to patient.
/// This is the mobile app side of the patient linking flow (REQ-p70007, REQ-d00078).
Future<Response> linkHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    // Verify JWT
    final auth = verifyAuthHeader(request.headers['authorization']);
    if (auth == null) {
      return _jsonResponse({'error': 'Invalid or missing authorization'}, 401);
    }

    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    // Extract and normalize the code
    final code = (body['code'] as String?)?.toUpperCase().replaceAll('-', '');
    if (code == null || code.isEmpty) {
      return _jsonResponse({'error': 'Missing linking code'}, 400);
    }

    // Validate code format: 10 characters (2-char prefix + 8 random)
    if (code.length != 10) {
      return _jsonResponse({
        'error': 'Invalid code format. Expected 10 characters.',
      }, 400);
    }

    final appUuid = body['appUuid'] as String?;
    final db = Database.instance;

    // Get the authenticated user
    final userResult = await db.execute(
      'SELECT user_id FROM app_users WHERE auth_code = @authCode',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final userId = userResult.first[0] as String;

    // Hash the code for lookup (REQ-d00078)
    final codeHash = _hashLinkingCode(code);

    // Look up the linking code in patient_linking_codes
    // Must be: not expired, not used, not revoked
    final codeResult = await db.execute(
      '''
      SELECT
        plc.id,
        plc.patient_id,
        p.site_id,
        p.edc_subject_key,
        s.site_name,
        s.site_number
      FROM patient_linking_codes plc
      JOIN patients p ON plc.patient_id = p.patient_id
      JOIN sites s ON p.site_id = s.site_id
      WHERE plc.code_hash = @codeHash
        AND plc.expires_at > now()
        AND plc.used_at IS NULL
        AND plc.revoked_at IS NULL
      ''',
      parameters: {'codeHash': codeHash},
    );

    if (codeResult.isEmpty) {
      // Check if code exists but is expired/used/revoked for better error message
      final checkResult = await db.execute(
        'SELECT used_at, expires_at, revoked_at FROM patient_linking_codes WHERE code_hash = @codeHash',
        parameters: {'codeHash': codeHash},
      );

      if (checkResult.isEmpty) {
        return _jsonResponse({
          'error': 'Invalid linking code. Please check the code and try again.',
        }, 400);
      }

      final row = checkResult.first;
      final usedAt = row[0];
      final expiresAt = row[1] as DateTime;
      final revokedAt = row[2];

      if (usedAt != null) {
        return _jsonResponse({
          'error':
              'This linking code has already been used. Please request a new code from your research coordinator.',
        }, 409);
      }

      if (revokedAt != null) {
        return _jsonResponse({
          'error':
              'This linking code has been revoked. Please request a new code from your research coordinator.',
        }, 410);
      }

      if (expiresAt.isBefore(DateTime.now())) {
        return _jsonResponse({
          'error':
              'This linking code has expired. Please request a new code from your research coordinator.',
        }, 410);
      }

      return _jsonResponse({'error': 'Invalid linking code.'}, 400);
    }

    final codeRow = codeResult.first;
    final codeId = codeRow[0] as String;
    final patientId = codeRow[1] as String;
    final siteId = codeRow[2] as String;
    final edcSubjectKey = codeRow[3] as String;
    final siteName = codeRow[4] as String;
    final siteNumber = codeRow[5] as String;

    // Mark the code as used (REQ-p70007.J - single-use)
    await db.execute(
      '''
      UPDATE patient_linking_codes
      SET used_at = now(),
          used_by_user_id = @userId,
          used_by_app_uuid = @appUuid
      WHERE id = @codeId::uuid
      ''',
      parameters: {'codeId': codeId, 'userId': userId, 'appUuid': appUuid},
    );

    // Update patient linking status to 'connected' (REQ-CAL-p00073)
    await db.execute(
      '''
      UPDATE patients
      SET mobile_linking_status = 'connected',
          updated_at = now()
      WHERE patient_id = @patientId
      ''',
      parameters: {'patientId': patientId},
    );

    // Note: The app user → patient → site relationship is established through:
    // - patient_linking_codes.used_by_user_id → app_users.user_id
    // - patient_linking_codes.patient_id → patients.patient_id
    // - patients.site_id → sites.site_id
    // user_site_assignments is for portal users (coordinators, investigators), not app users.

    // Update app_users last_active_at
    await db.execute(
      'UPDATE app_users SET last_active_at = now() WHERE user_id = @userId',
      parameters: {'userId': userId},
    );

    return _jsonResponse({
      'success': true,
      'patientId': patientId,
      'siteId': siteId,
      'siteName': siteName,
      'siteNumber': siteNumber,
      'studyPatientId': edcSubjectKey,
    });
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error: $e'}, 500);
  }
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

    // Look up user and their linked patient/site via patient_linking_codes
    final userResult = await db.execute(
      '''
      SELECT u.user_id, p.site_id, p.patient_id, p.edc_subject_key
      FROM app_users u
      LEFT JOIN patient_linking_codes plc ON u.user_id = plc.used_by_user_id
        AND plc.used_at IS NOT NULL
      LEFT JOIN patients p ON plc.patient_id = p.patient_id
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
    final patientId =
        row[2] as String? ?? userId; // Use userId if no linked patient

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

    // Look up user and linked patient via patient_linking_codes
    final userResult = await db.execute(
      '''
      SELECT u.user_id, p.patient_id
      FROM app_users u
      LEFT JOIN patient_linking_codes plc ON u.user_id = plc.used_by_user_id
        AND plc.used_at IS NOT NULL
      LEFT JOIN patients p ON plc.patient_id = p.patient_id
      WHERE u.auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final row = userResult.first;
    final userId = row[0] as String;
    final patientId =
        row[1] as String? ?? userId; // Use userId if no linked patient

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
