// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00005: Role-Based Access Control
//
// Portal authentication - verifies Identity Platform tokens and manages user sessions
// Uses service context for login/linking operations, authenticated context for data access

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
  print('[PORTAL_AUTH] portalMeHandler called');

  // Extract bearer token
  final token = extractBearerToken(request.headers['authorization']);
  if (token == null) {
    print('[PORTAL_AUTH] No authorization header found');
    return _jsonResponse({'error': 'Missing authorization header'}, 401);
  }

  print('[PORTAL_AUTH] Got bearer token, verifying...');

  // Verify Identity Platform token
  final verification = await verifyIdToken(token);
  if (!verification.isValid) {
    print('[PORTAL_AUTH] Token verification FAILED: ${verification.error}');
    return _jsonResponse({'error': verification.error ?? 'Invalid token'}, 401);
  }

  final firebaseUid = verification.uid!;
  final email = verification.email;

  print('[PORTAL_AUTH] Token verified: uid=$firebaseUid, email=$email');

  if (email == null) {
    print('[PORTAL_AUTH] Token missing email claim');
    return _jsonResponse({'error': 'Token missing email claim'}, 401);
  }

  final db = Database.instance;

  // Use service context for login/linking - this is a privileged operation
  // that needs to read/update portal_users before user context is established
  const serviceContext = UserContext.service;

  // First, try to find user by firebase_uid (subsequent logins)
  print('[PORTAL_AUTH] Looking up user by firebase_uid: $firebaseUid');
  var result = await db.executeWithContext(
    '''
    SELECT id, firebase_uid, email, name, role::text, status
    FROM portal_users
    WHERE firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
    context: serviceContext,
  );

  print('[PORTAL_AUTH] Firebase UID lookup returned ${result.length} rows');

  if (result.isEmpty) {
    // First login - try to link by email
    print('[PORTAL_AUTH] No match by UID, trying to link by email: $email');
    result = await db.executeWithContext(
      '''
      UPDATE portal_users
      SET firebase_uid = @firebaseUid, updated_at = now()
      WHERE email = @email AND firebase_uid IS NULL
      RETURNING id, firebase_uid, email, name, role::text, status
      ''',
      parameters: {'firebaseUid': firebaseUid, 'email': email},
      context: serviceContext,
    );

    print('[PORTAL_AUTH] Email link update returned ${result.length} rows');

    if (result.isEmpty) {
      // Check if email exists but already linked to different uid
      print('[PORTAL_AUTH] Checking if email exists with different UID');
      final existing = await db.executeWithContext(
        'SELECT firebase_uid FROM portal_users WHERE email = @email',
        parameters: {'email': email},
        context: serviceContext,
      );

      print('[PORTAL_AUTH] Email exists check: ${existing.length} rows');

      if (existing.isNotEmpty && existing.first[0] != null) {
        print('[PORTAL_AUTH] Email already linked to: ${existing.first[0]}');
        return _jsonResponse({
          'error': 'Email already linked to another account',
        }, 403);
      }

      // Email not found in portal_users - not pre-authorized
      print('[PORTAL_AUTH] Email not in portal_users - NOT AUTHORIZED');
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

  // Fetch site assignments for investigators (service context for initial login)
  List<Map<String, dynamic>> sites = [];
  if (userRole == 'Investigator') {
    final siteResult = await db.executeWithContext(
      '''
      SELECT s.site_id, s.site_name, s.site_number
      FROM portal_user_site_access pusa
      JOIN sites s ON pusa.site_id = s.site_id
      WHERE pusa.user_id = @userId::uuid AND s.is_active = true
      ORDER BY s.site_number
      ''',
      parameters: {'userId': userId},
      context: serviceContext,
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
/// Returns PortalUser if authentication succeeds, null if it fails.
/// Uses service context to look up user - subsequent data operations
/// should create authenticated UserContext from the returned PortalUser.
///
/// Example usage:
///   final user = await requirePortalAuth(request, ['Administrator']);
///   if (user == null) return Response.forbidden('...');
///   final context = UserContext.authenticated(
///     userId: user.firebaseUid!,
///     role: user.role,
///   );
///   // Use context for subsequent queries
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

  // Use service context for user lookup - this is identity verification
  const serviceContext = UserContext.service;

  final result = await db.executeWithContext(
    '''
    SELECT id, firebase_uid, email, name, role::text, status
    FROM portal_users
    WHERE firebase_uid = @firebaseUid
    ''',
    parameters: {'firebaseUid': firebaseUid},
    context: serviceContext,
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
    final siteResult = await db.executeWithContext(
      '''
      SELECT s.site_id, s.site_name, s.site_number
      FROM portal_user_site_access pusa
      JOIN sites s ON pusa.site_id = s.site_id
      WHERE pusa.user_id = @userId::uuid
      ''',
      parameters: {'userId': row[0]},
      context: serviceContext,
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
