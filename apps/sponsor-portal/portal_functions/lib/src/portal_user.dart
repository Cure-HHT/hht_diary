// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: Create User Dialog Implementation
//   REQ-p00028: Token Revocation and Access Control
//
// Portal user management - create users, assign sites, revoke access

import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'portal_auth.dart';

/// Roles that can manage other users
const _adminRoles = ['Administrator', 'Developer Admin'];

/// Roles that can view all users
const _viewAllRoles = ['Administrator', 'Developer Admin', 'Auditor'];

/// Get all portal users (Admin/Auditor only)
/// GET /api/portal/users
Future<Response> getPortalUsersHandler(Request request) async {
  final user = await requirePortalAuth(request, _viewAllRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  final db = Database.instance;
  final result = await db.execute('''
    SELECT
      pu.id,
      pu.email,
      pu.name,
      pu.role::text,
      pu.status,
      pu.linking_code,
      pu.created_at,
      COALESCE(
        json_agg(
          json_build_object(
            'site_id', s.site_id,
            'site_name', s.site_name,
            'site_number', s.site_number
          )
        ) FILTER (WHERE s.site_id IS NOT NULL),
        '[]'::json
      ) as sites
    FROM portal_users pu
    LEFT JOIN portal_user_site_access pusa ON pu.id = pusa.user_id
    LEFT JOIN sites s ON pusa.site_id = s.site_id
    GROUP BY pu.id
    ORDER BY pu.created_at DESC
  ''');

  final users = result.map((r) {
    final sitesJson = r[7];
    List<dynamic> sites = [];
    if (sitesJson != null) {
      if (sitesJson is String) {
        sites = jsonDecode(sitesJson) as List<dynamic>;
      } else if (sitesJson is List) {
        sites = sitesJson;
      }
    }

    return {
      'id': r[0] as String,
      'email': r[1] as String,
      'name': r[2] as String,
      'role': r[3] as String,
      'status': r[4] as String,
      'linking_code': r[5] as String?,
      'created_at': (r[6] as DateTime).toIso8601String(),
      'sites': sites,
    };
  }).toList();

  return _jsonResponse({'users': users});
}

/// Create new portal user (Admin only)
/// POST /api/portal/users
/// Body: { name, email, role, site_ids: [] }
Future<Response> createPortalUserHandler(Request request) async {
  final user = await requirePortalAuth(request, _adminRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final name = body['name'] as String?;
  final email = body['email'] as String?;
  final role = body['role'] as String?;
  final siteIds = (body['site_ids'] as List?)?.cast<String>() ?? [];

  // Validation
  if (name == null || name.isEmpty) {
    return _jsonResponse({'error': 'Name is required'}, 400);
  }

  if (email == null || email.isEmpty || !email.contains('@')) {
    return _jsonResponse({'error': 'Valid email is required'}, 400);
  }

  if (role == null || role.isEmpty) {
    return _jsonResponse({'error': 'Role is required'}, 400);
  }

  // Validate role is a valid enum value
  const validRoles = [
    'Investigator',
    'Sponsor',
    'Auditor',
    'Analyst',
    'Administrator',
    'Developer Admin',
  ];
  if (!validRoles.contains(role)) {
    return _jsonResponse({'error': 'Invalid role: $role'}, 400);
  }

  // Investigators must have site assignments
  if (role == 'Investigator' && siteIds.isEmpty) {
    return _jsonResponse({
      'error': 'Investigators require at least one site assignment',
    }, 400);
  }

  // Non-admin users cannot create admin users
  if ((role == 'Administrator' || role == 'Developer Admin') &&
      user.role != 'Developer Admin') {
    return _jsonResponse({
      'error': 'Only Developer Admin can create admin users',
    }, 403);
  }

  // Generate linking code for Investigators
  final linkingCode = role == 'Investigator' ? _generateLinkingCode() : null;

  final db = Database.instance;

  // Check for duplicate email
  final existing = await db.execute(
    'SELECT id FROM portal_users WHERE email = @email',
    parameters: {'email': email},
  );
  if (existing.isNotEmpty) {
    return _jsonResponse({'error': 'Email already exists'}, 409);
  }

  // Create user
  final createResult = await db.execute(
    '''
    INSERT INTO portal_users (email, name, role, linking_code)
    VALUES (@email, @name, @role::portal_user_role, @linkingCode)
    RETURNING id
    ''',
    parameters: {
      'email': email,
      'name': name,
      'role': role,
      'linkingCode': linkingCode,
    },
  );

  final newUserId = createResult.first[0] as String;

  // Create site assignments for Investigators
  if (role == 'Investigator' && siteIds.isNotEmpty) {
    for (final siteId in siteIds) {
      await db.execute(
        '''
        INSERT INTO portal_user_site_access (user_id, site_id)
        VALUES (@userId::uuid, @siteId)
        ON CONFLICT (user_id, site_id) DO NOTHING
        ''',
        parameters: {'userId': newUserId, 'siteId': siteId},
      );
    }
  }

  return _jsonResponse({
    'id': newUserId,
    'email': email,
    'name': name,
    'role': role,
    'linking_code': linkingCode,
    'site_ids': siteIds,
  }, 201);
}

/// Update portal user (Admin only)
/// PATCH /api/portal/users/:userId
/// Body: { status: 'revoked' } or { site_ids: [...] }
Future<Response> updatePortalUserHandler(Request request, String userId) async {
  final user = await requirePortalAuth(request, _adminRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  // Prevent self-revocation
  if (userId == user.id) {
    return _jsonResponse({'error': 'Cannot modify your own account'}, 400);
  }

  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final db = Database.instance;

  // Check user exists
  final existing = await db.execute(
    'SELECT role::text FROM portal_users WHERE id = @userId::uuid',
    parameters: {'userId': userId},
  );
  if (existing.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final targetRole = existing.first[0] as String;

  // Non-developer admins cannot modify admin users
  if ((targetRole == 'Administrator' || targetRole == 'Developer Admin') &&
      user.role != 'Developer Admin') {
    return _jsonResponse({
      'error': 'Only Developer Admin can modify admin users',
    }, 403);
  }

  // Handle status update (revocation)
  final status = body['status'] as String?;
  if (status != null) {
    if (status != 'revoked' && status != 'active') {
      return _jsonResponse({'error': 'Invalid status'}, 400);
    }

    await db.execute(
      '''
      UPDATE portal_users
      SET status = @status, updated_at = now()
      WHERE id = @userId::uuid
      ''',
      parameters: {'userId': userId, 'status': status},
    );
  }

  // Handle site assignment update
  final siteIds = body['site_ids'] as List?;
  if (siteIds != null) {
    // Clear existing assignments
    await db.execute(
      'DELETE FROM portal_user_site_access WHERE user_id = @userId::uuid',
      parameters: {'userId': userId},
    );

    // Add new assignments
    for (final siteId in siteIds.cast<String>()) {
      await db.execute(
        '''
        INSERT INTO portal_user_site_access (user_id, site_id)
        VALUES (@userId::uuid, @siteId)
        ON CONFLICT (user_id, site_id) DO NOTHING
        ''',
        parameters: {'userId': userId, 'siteId': siteId},
      );
    }
  }

  return _jsonResponse({'success': true});
}

/// Get available sites (for user creation dialog)
/// GET /api/portal/sites
Future<Response> getPortalSitesHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  final db = Database.instance;
  final result = await db.execute('''
    SELECT site_id, site_name, site_number
    FROM sites
    WHERE is_active = true
    ORDER BY site_number
  ''');

  final sites = result.map((r) {
    return {
      'site_id': r[0] as String,
      'site_name': r[1] as String,
      'site_number': r[2] as String,
    };
  }).toList();

  return _jsonResponse({'sites': sites});
}

/// Generate a random linking code in XXXXX-XXXXX format
String _generateLinkingCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  String part() =>
      List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  return '${part()}-${part()}';
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
