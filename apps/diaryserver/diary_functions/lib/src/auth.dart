// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Authentication handlers - converted from Firebase auth.ts

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'jwt.dart';

// Validation constants
const _minUsernameLength = 6;
final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

/// Validate username format
String? _validateUsername(String? username) {
  if (username == null || username.length < _minUsernameLength) {
    return 'Username must be at least $_minUsernameLength characters';
  }
  if (username.contains('@')) {
    return 'Username cannot contain @ symbol';
  }
  if (!_usernamePattern.hasMatch(username)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  return null;
}

/// Validate password hash format (SHA-256 hex string)
String? _validatePasswordHash(String? passwordHash) {
  if (passwordHash == null || passwordHash.length != 64) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'^[a-f0-9]{64}$', caseSensitive: false).hasMatch(passwordHash)) {
    return 'Invalid password format';
  }
  return null;
}

/// Register handler - creates new user account
/// POST /api/v1/auth/register
/// Body: { username, passwordHash, appUuid }
Future<Response> registerHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final username = body['username'] as String?;
    final passwordHash = body['passwordHash'] as String?;
    final appUuid = body['appUuid'] as String?;

    // Validate username
    final usernameError = _validateUsername(username);
    if (usernameError != null) {
      return _jsonResponse({'error': usernameError}, 400);
    }

    // Validate password hash
    final passwordError = _validatePasswordHash(passwordHash);
    if (passwordError != null) {
      return _jsonResponse({'error': passwordError}, 400);
    }

    if (appUuid == null || appUuid.isEmpty) {
      return _jsonResponse({'error': 'App UUID is required'}, 400);
    }

    final normalizedUsername = username!.toLowerCase();
    final db = Database.instance;

    // Check if username exists
    final existing = await db.execute(
      'SELECT user_id FROM app_users WHERE username = @username',
      parameters: {'username': normalizedUsername},
    );

    if (existing.isNotEmpty) {
      return _jsonResponse({'error': 'Username is already taken'}, 409);
    }

    // Generate credentials
    final userId = generateUserId();
    final authCode = generateAuthCode();

    // Create user
    await db.execute(
      '''
      INSERT INTO app_users (user_id, username, password_hash, auth_code, app_uuid)
      VALUES (@userId, @username, @passwordHash, @authCode, @appUuid)
      ''',
      parameters: {
        'userId': userId,
        'username': normalizedUsername,
        'passwordHash': passwordHash,
        'authCode': authCode,
        'appUuid': appUuid,
      },
    );

    // Generate JWT
    final jwt = createJwtToken(
      authCode: authCode,
      userId: userId,
      username: normalizedUsername,
    );

    return _jsonResponse({
      'jwt': jwt,
      'userId': userId,
      'username': normalizedUsername,
    });
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Login handler - authenticates user
/// POST /api/v1/auth/login
/// Body: { username, passwordHash }
Future<Response> loginHandler(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  try {
    final body = await _parseJson(request);
    if (body == null) {
      return _jsonResponse({'error': 'Invalid JSON body'}, 400);
    }

    final username = body['username'] as String?;
    final passwordHash = body['passwordHash'] as String?;

    if (username == null || username.isEmpty) {
      return _jsonResponse({'error': 'Username is required'}, 400);
    }

    if (passwordHash == null || passwordHash.isEmpty) {
      return _jsonResponse({'error': 'Password is required'}, 400);
    }

    final normalizedUsername = username.toLowerCase();
    final db = Database.instance;

    // Fetch user
    final result = await db.execute(
      '''
      SELECT user_id, auth_code, password_hash
      FROM app_users
      WHERE username = @username
      ''',
      parameters: {'username': normalizedUsername},
    );

    if (result.isEmpty) {
      return _jsonResponse({'error': 'Invalid username or password'}, 401);
    }

    final row = result.first;
    final storedHash = row[2] as String;

    // Verify password
    if (storedHash != passwordHash) {
      return _jsonResponse({'error': 'Invalid username or password'}, 401);
    }

    final userId = row[0] as String;
    final authCode = row[1] as String;

    // Update last active
    await db.execute(
      'UPDATE app_users SET last_active_at = now() WHERE user_id = @userId',
      parameters: {'userId': userId},
    );

    // Generate JWT
    final jwt = createJwtToken(
      authCode: authCode,
      userId: userId,
      username: normalizedUsername,
    );

    return _jsonResponse({
      'jwt': jwt,
      'userId': userId,
      'username': normalizedUsername,
    });
  } catch (e) {
    return _jsonResponse({'error': 'Internal server error'}, 500);
  }
}

/// Change password handler
/// POST /api/v1/auth/change-password
/// Authorization: Bearer <jwt>
/// Body: { currentPasswordHash, newPasswordHash }
Future<Response> changePasswordHandler(Request request) async {
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

    final currentPasswordHash = body['currentPasswordHash'] as String?;
    final newPasswordHash = body['newPasswordHash'] as String?;

    // Validate new password
    final passwordError = _validatePasswordHash(newPasswordHash);
    if (passwordError != null) {
      return _jsonResponse({'error': passwordError}, 400);
    }

    final db = Database.instance;

    // Look up user by authCode
    final result = await db.execute(
      '''
      SELECT user_id, password_hash
      FROM app_users
      WHERE auth_code = @authCode
      ''',
      parameters: {'authCode': auth.authCode},
    );

    if (result.isEmpty) {
      return _jsonResponse({'error': 'User not found'}, 401);
    }

    final row = result.first;
    final storedHash = row[1] as String;

    // Verify current password
    if (storedHash != currentPasswordHash) {
      return _jsonResponse({'error': 'Current password is incorrect'}, 401);
    }

    final userId = row[0] as String;

    // Update password
    await db.execute(
      '''
      UPDATE app_users
      SET password_hash = @newPasswordHash, updated_at = now()
      WHERE user_id = @userId
      ''',
      parameters: {'userId': userId, 'newPasswordHash': newPasswordHash},
    );

    return _jsonResponse({'success': true});
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
