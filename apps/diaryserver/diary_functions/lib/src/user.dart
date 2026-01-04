// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//
// User enrollment and data sync handlers - converted from Firebase user.ts

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

// Valid enrollment code pattern: CUREHHT followed by a digit (0-9)
final _enrollmentCodePattern = RegExp(r'^CUREHHT[0-9]$', caseSensitive: false);

/// Enrollment handler - registers user with enrollment code
/// POST /api/v1/user/enroll
/// Body: { code }
Future<Response> enrollHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
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
      'SELECT user_id FROM app_users WHERE enrollment_code = @code',
      parameters: {'code': normalizedCode},
    );

    if (existing.isNotEmpty) {
      return _jsonResponse(
        {'error': 'This enrollment code has already been used'},
        409,
      );
    }

    // Generate credentials
    final userId = generateUserId();
    final authCode = generateAuthCode();

    // Create user
    await db.execute(
      '''
      INSERT INTO app_users (user_id, auth_code, enrollment_code)
      VALUES (@userId, @authCode, @code)
      ''',
      parameters: {
        'userId': userId,
        'authCode': authCode,
        'code': normalizedCode,
      },
    );

    // Generate JWT
    final jwt = createJwtToken(authCode: authCode, userId: userId);

    return _jsonResponse({'jwt': jwt, 'userId': userId});
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Sync records handler - appends records (append-only pattern)
/// POST /api/v1/user/sync
/// Authorization: Bearer <jwt>
/// Body: { records: [...] }
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

    // Look up user by authCode
    final userResult = await db.execute(
      'SELECT user_id FROM app_users WHERE auth_code = @authCode',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final userId = userResult.first[0] as String;

    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final records = body['records'];
    if (records is! List) {
      return _jsonResponse({'error': 'Records must be an array'}, 400);
    }

    // Insert records (append-only)
    for (final record in records) {
      if (record is! Map || record['id'] == null) continue;

      final recordId = record['id'] as String;

      // Check if record exists
      final existing = await db.execute(
        '''
        SELECT id FROM user_records
        WHERE user_id = @userId AND record_id = @recordId
        ''',
        parameters: {'userId': userId, 'recordId': recordId},
      );

      if (existing.isEmpty) {
        await db.execute(
          '''
          INSERT INTO user_records (user_id, record_id, data, synced_at)
          VALUES (@userId, @recordId, @data, now())
          ''',
          parameters: {
            'userId': userId,
            'recordId': recordId,
            'data': jsonEncode(record),
          },
        );
      }
    }

    // Update last active
    await db.execute(
      'UPDATE app_users SET last_active_at = now() WHERE user_id = @userId',
      parameters: {'userId': userId},
    );

    return _jsonResponse({'success': true});
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Get records handler - returns all records for user
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

    // Look up user by authCode
    final userResult = await db.execute(
      'SELECT user_id FROM app_users WHERE auth_code = @authCode',
      parameters: {'authCode': auth.authCode},
    );

    if (userResult.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final userId = userResult.first[0] as String;

    // Fetch records
    final recordsResult = await db.execute(
      '''
      SELECT record_id, data, synced_at
      FROM user_records
      WHERE user_id = @userId
      ORDER BY synced_at DESC
      ''',
      parameters: {'userId': userId},
    );

    final records = recordsResult.map((row) {
      final data = jsonDecode(row[1] as String) as Map<String, dynamic>;
      return {
        'id': row[0],
        ...data,
        'syncedAt': (row[2] as DateTime).toIso8601String(),
      };
    }).toList();

    return _jsonResponse({'records': records});
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
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
