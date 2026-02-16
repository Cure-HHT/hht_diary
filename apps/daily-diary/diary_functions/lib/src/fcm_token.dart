// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// FCM token registration handler for the diary server.
// The mobile app calls this to register its FCM token so the
// portal server can send push notifications via the shared database.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

/// Simple structured logger for Cloud Run
void _log(String level, String message, [Map<String, dynamic>? data]) {
  final logEntry = {
    'severity': level,
    'message': message,
    'time': DateTime.now().toUtc().toIso8601String(),
    if (data != null) ...data,
  };
  stderr.writeln(jsonEncode(logEntry));
}

/// Register or update FCM token for a patient's device.
/// POST /api/v1/user/fcm-token
/// Authorization: Bearer <jwt>
/// Body: { "fcm_token": "<token>", "platform": "android"|"ios" }
///
/// The token is stored in patient_fcm_tokens (shared with portal server).
/// Uses UPSERT: one active token per patient per platform.
Future<Response> registerFcmTokenHandler(Request request) async {
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

    // Look up user and their linked patient via patient_linking_codes
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

    final patientId = userResult.first[1] as String?;
    if (patientId == null) {
      return _jsonResponse({
        'error': 'No linked patient. Complete patient linking first.',
      }, 409);
    }

    // Parse request body
    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final fcmToken = body['fcm_token'] as String?;
    final platform = body['platform'] as String?;

    if (fcmToken == null || fcmToken.isEmpty) {
      return _jsonResponse({'error': 'Missing fcm_token'}, 400);
    }

    if (platform == null || !['android', 'ios'].contains(platform)) {
      return _jsonResponse({
        'error': 'Invalid platform. Must be "android" or "ios".',
      }, 400);
    }

    // Optional: app version for tracking
    final appVersion = body['app_version'] as String?;

    // Upsert: deactivate any existing active token for this patient+platform,
    // then insert the new one. This handles token rotation cleanly.
    await db.execute(
      '''
      UPDATE patient_fcm_tokens
      SET is_active = false, updated_at = now()
      WHERE patient_id = @patientId
        AND platform = @platform
        AND is_active = true
      ''',
      parameters: {'patientId': patientId, 'platform': platform},
    );

    await db.execute(
      '''
      INSERT INTO patient_fcm_tokens (
        patient_id, fcm_token, platform, app_version, is_active
      )
      VALUES (@patientId, @fcmToken, @platform, @appVersion, true)
      ''',
      parameters: {
        'patientId': patientId,
        'fcmToken': fcmToken,
        'platform': platform,
        'appVersion': appVersion,
      },
    );

    _log('INFO', 'FCM token registered', {
      'patientId': patientId,
      'platform': platform,
      'tokenPrefix': fcmToken.substring(0, 20),
    });

    return _jsonResponse({'success': true});
  } catch (e, stackTrace) {
    _log('ERROR', 'FCM token registration error', {
      'error': e.toString(),
      'stackTrace': stackTrace.toString().split('\n').take(5).join('\n'),
    });
    return _jsonResponse({'error': 'Internal server error: $e'}, 500);
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
