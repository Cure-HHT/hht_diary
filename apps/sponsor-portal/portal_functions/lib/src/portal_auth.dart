// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Portal authentication - verifies Identity Platform tokens and manages user sessions

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'identity_platform.dart';

/// Portal user information from database
class PortalUser {
  final String id;
  final String? firebaseUid;
  final String email;
  final String name;
  final String role;
  final String status;
  final List<Map<String, dynamic>> sites;

  PortalUser({
    required this.id,
    this.firebaseUid,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    this.sites = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
    'status': status,
    'sites': sites,
  };
}

/// Get current portal user from Identity Platform token
/// GET /api/portal/me
/// Authorization: Bearer <Identity Platform ID token>
///
/// On first login, links firebase_uid to portal_users record by email match.
/// Returns 403 if email is not pre-authorized in portal_users table.
Future<Response> portalMeHandler(Request request) async {
  // Extract bearer token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  // Verify Identity Platform token
  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;
  final email = verification.email;

  if (email == null) {
    return _jsonResponse({'error': 'Token missing email claim'}, 401);
  }

  final db = Database.instance;

  // First, try to find user by firebase_uid (subsequent logins)
  var result = await db.execute(
    '''
    SELECT id, firebase_uid, email, name, role::text, status
    FROM portal_users
    WHERE firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
  );

  if (result.isEmpty) {
    // First login - try to link by email
    result = await db.execute(
      '''
      UPDATE portal_users
      SET firebase_uid = @firebaseUid, updated_at = now()
      WHERE email = @email AND firebase_uid IS NULL
      RETURNING id, firebase_uid, email, name, role::text, status
      ''',
      parameters: {'firebaseUid': firebaseUid, 'email': email},
    );

    if (result.isEmpty) {
      // Check if email exists but already linked to different uid
      final existing = await db.execute(
        'SELECT firebase_uid FROM portal_users WHERE email = @email',
        parameters: {'email': email},
      );

      if (existing.isNotEmpty && existing.first[0] != null) {
        return _jsonResponse({
          'error': 'Email already linked to another account',
        }, 403);
      }

      // Email not found in portal_users - not pre-authorized
      return _jsonResponse({
        'error': 'User not authorized for portal access',
      }, 403);
    }
  }

  final row = result.first;
  final userId = row[0] as String;
  final userEmail = row[2] as String;
  final userName = row[3] as String;
  final userRole = row[4] as String;
  final userStatus = row[5] as String;

  // Check if account is revoked
  if (userStatus == 'revoked') {
    return _jsonResponse({'error': 'Account access has been revoked'}, 403);
  }

  // Fetch site assignments for investigators
  List<Map<String, dynamic>> sites = [];
  if (userRole == 'Investigator') {
    final siteResult = await db.execute(
      '''
      SELECT s.site_id, s.site_name, s.site_number
      FROM portal_user_site_access pusa
      JOIN sites s ON pusa.site_id = s.site_id
      WHERE pusa.user_id = @userId::uuid AND s.is_active = true
      ORDER BY s.site_number
      ''',
      parameters: {'userId': userId},
    );

    sites = siteResult.map((r) {
      return {
        'site_id': r[0] as String,
        'site_name': r[1] as String,
        'site_number': r[2] as String,
      };
    }).toList();
  }

  final user = PortalUser(
    id: userId,
    firebaseUid: firebaseUid,
    email: userEmail,
    name: userName,
    role: userRole,
    status: userStatus,
    sites: sites,
  );

  return _jsonResponse(user.toJson());
}

/// Middleware to require portal authentication
///
/// Returns null if authentication succeeds (caller should continue).
/// Returns Response with error if authentication fails.
Future<PortalUser?> requirePortalAuth(
  Request request, [
  List<String>? allowedRoles,
]) async {
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    return null;
  }

  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    return null;
  }

  final firebaseUid = verification.uid!;

  final db = Database.instance;
  final result = await db.execute(
    '''
    SELECT id, firebase_uid, email, name, role::text, status
    FROM portal_users
    WHERE firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
  );

  if (result.isEmpty) {
    return null;
  }

  final row = result.first;
  final userRole = row[4] as String;
  final userStatus = row[5] as String;

  if (userStatus == 'revoked') {
    return null;
  }

  // Check role restriction
  if (allowedRoles != null && !allowedRoles.contains(userRole)) {
    return null;
  }

  // Fetch sites if investigator
  List<Map<String, dynamic>> sites = [];
  if (userRole == 'Investigator') {
    final siteResult = await db.execute(
      '''
      SELECT s.site_id, s.site_name, s.site_number
      FROM portal_user_site_access pusa
      JOIN sites s ON pusa.site_id = s.site_id
      WHERE pusa.user_id = @userId::uuid
      ''',
      parameters: {'userId': row[0]},
    );

    sites = siteResult
        .map(
          (r) => {
            'site_id': r[0] as String,
            'site_name': r[1] as String,
            'site_number': r[2] as String,
          },
        )
        .toList();
  }

  return PortalUser(
    id: row[0] as String,
    firebaseUid: row[1] as String?,
    email: row[2] as String,
    name: row[3] as String,
    role: userRole,
    status: userStatus,
    sites: sites,
  );
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
