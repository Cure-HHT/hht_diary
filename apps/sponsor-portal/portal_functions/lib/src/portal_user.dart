// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: Create User Dialog Implementation
//   REQ-p00028: Token Revocation and Access Control
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-CAL-p00010: Schema-Driven Data Validation (EDC site sync)
//
// Portal user management - create users, assign sites, revoke access
// Supports multi-role users with activation code flow

import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'database.dart';
import 'portal_auth.dart';
import 'sites_sync.dart';

/// Roles that can manage other users
const _adminRoles = ['Administrator', 'Developer Admin'];

/// Roles that can view all users
const _viewAllRoles = ['Administrator', 'Developer Admin', 'Auditor'];

/// Get all portal users (Admin/Auditor only)
/// GET /api/v1/portal/users
/// Returns users with all their roles from portal_user_roles table
Future<Response> getPortalUsersHandler(Request request) async {
  final user = await requirePortalAuth(request, _viewAllRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  final db = Database.instance;

  // Get users with roles aggregated from portal_user_roles
  final result = await db.execute('''
    SELECT
      pu.id,
      pu.email,
      pu.name,
      pu.status,
      pu.linking_code,
      pu.activation_code,
      pu.created_at,
      COALESCE(
        array_agg(DISTINCT pur.role::text) FILTER (WHERE pur.role IS NOT NULL),
        ARRAY[]::text[]
      ) as roles,
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
    LEFT JOIN portal_user_roles pur ON pu.id = pur.user_id
    LEFT JOIN portal_user_site_access pusa ON pu.id = pusa.user_id
    LEFT JOIN sites s ON pusa.site_id = s.site_id
    GROUP BY pu.id
    ORDER BY pu.created_at DESC
  ''');

  final users = result.map((r) {
    // Parse roles array
    final rolesData = r[7];
    List<String> roles = [];
    if (rolesData != null) {
      if (rolesData is List) {
        roles = rolesData.cast<String>();
      }
    }

    // Parse sites JSON
    final sitesJson = r[8];
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
      'status': r[3] as String,
      'linking_code': r[4] as String?,
      'activation_code': r[5] as String?,
      'created_at': (r[6] as DateTime).toIso8601String(),
      'roles': roles,
      'sites': sites,
    };
  }).toList();

  return _jsonResponse({'users': users});
}

/// Create new portal user (Admin only)
/// POST /api/v1/portal/users
/// Body: { name, email, roles: [], site_ids: [] }
///
/// Creates user with status='pending' and generates activation code.
/// For backwards compatibility, also accepts single 'role' field.
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

  // Accept either 'roles' array or single 'role' for backwards compat
  List<String> roles = [];
  if (body['roles'] != null) {
    roles = (body['roles'] as List).cast<String>();
  } else if (body['role'] != null) {
    roles = [body['role'] as String];
  }

  final siteIds = (body['site_ids'] as List?)?.cast<String>() ?? [];

  // Validation
  if (name == null || name.isEmpty) {
    return _jsonResponse({'error': 'Name is required'}, 400);
  }

  if (email == null || email.isEmpty || !email.contains('@')) {
    return _jsonResponse({'error': 'Valid email is required'}, 400);
  }

  if (roles.isEmpty) {
    return _jsonResponse({'error': 'At least one role is required'}, 400);
  }

  // Validate all roles are valid enum values
  const validRoles = [
    'Investigator',
    'Sponsor',
    'Auditor',
    'Analyst',
    'Administrator',
    'Developer Admin',
  ];
  for (final role in roles) {
    if (!validRoles.contains(role)) {
      return _jsonResponse({'error': 'Invalid role: $role'}, 400);
    }
  }

  // Investigators must have site assignments
  if (roles.contains('Investigator') && siteIds.isEmpty) {
    return _jsonResponse({
      'error': 'Investigators require at least one site assignment',
    }, 400);
  }

  // Non-developer admin users cannot create admin users
  final creatingAdminRole =
      roles.contains('Administrator') || roles.contains('Developer Admin');
  if (creatingAdminRole && !user.hasRole('Developer Admin')) {
    return _jsonResponse({
      'error': 'Only Developer Admin can create admin users',
    }, 403);
  }

  // Generate linking code for Investigators
  final linkingCode = roles.contains('Investigator') ? _generateCode() : null;

  // Generate activation code for all new users
  final activationCode = _generateCode();
  final activationExpiry = DateTime.now().add(const Duration(days: 14));

  final db = Database.instance;

  // Check for duplicate email
  final existing = await db.execute(
    'SELECT id FROM portal_users WHERE email = @email',
    parameters: {'email': email},
  );
  if (existing.isNotEmpty) {
    return _jsonResponse({'error': 'Email already exists'}, 409);
  }

  // Create user with pending status
  final createResult = await db.execute(
    '''
    INSERT INTO portal_users (
      email, name, linking_code, activation_code,
      activation_code_expires_at, status
    )
    VALUES (
      @email, @name, @linkingCode, @activationCode,
      @activationExpiry, 'pending'
    )
    RETURNING id
    ''',
    parameters: {
      'email': email,
      'name': name,
      'linkingCode': linkingCode,
      'activationCode': activationCode,
      'activationExpiry': activationExpiry,
    },
  );

  final newUserId = createResult.first[0] as String;

  // Create role assignments in portal_user_roles
  for (final role in roles) {
    await db.execute(
      '''
      INSERT INTO portal_user_roles (user_id, role, assigned_by)
      VALUES (@userId::uuid, @role::portal_user_role, @assignedBy::uuid)
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': newUserId, 'role': role, 'assignedBy': user.id},
    );
  }

  // Create site assignments for Investigators
  if (roles.contains('Investigator') && siteIds.isNotEmpty) {
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
    'roles': roles,
    'status': 'pending',
    'linking_code': linkingCode,
    'activation_code': activationCode,
    'site_ids': siteIds,
  }, 201);
}

/// Update portal user (Admin only)
/// PATCH /api/v1/portal/users/:userId
/// Body: { status: 'revoked'|'active' } or { site_ids: [...] } or { roles: [...] }
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

  // Check user exists and get their roles
  final existing = await db.execute(
    '''
    SELECT COALESCE(
      array_agg(role::text),
      ARRAY[]::text[]
    ) as roles
    FROM portal_user_roles
    WHERE user_id = @userId::uuid
    ''',
    parameters: {'userId': userId},
  );

  final userExists = await db.execute(
    'SELECT id FROM portal_users WHERE id = @userId::uuid',
    parameters: {'userId': userId},
  );
  if (userExists.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  // Get target user's roles
  List<String> targetRoles = [];
  if (existing.isNotEmpty && existing.first[0] != null) {
    targetRoles = (existing.first[0] as List).cast<String>();
  }

  // Non-developer admins cannot modify admin users
  final isTargetAdmin =
      targetRoles.contains('Administrator') ||
      targetRoles.contains('Developer Admin');
  if (isTargetAdmin && !user.hasRole('Developer Admin')) {
    return _jsonResponse({
      'error': 'Only Developer Admin can modify admin users',
    }, 403);
  }

  // Handle status update (revocation/activation)
  final status = body['status'] as String?;
  if (status != null) {
    if (status != 'revoked' && status != 'active' && status != 'pending') {
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

  // Handle roles update
  final newRoles = body['roles'] as List?;
  if (newRoles != null) {
    // Clear existing role assignments
    await db.execute(
      'DELETE FROM portal_user_roles WHERE user_id = @userId::uuid',
      parameters: {'userId': userId},
    );

    // Add new role assignments
    for (final role in newRoles.cast<String>()) {
      await db.execute(
        '''
        INSERT INTO portal_user_roles (user_id, role, assigned_by)
        VALUES (@userId::uuid, @role::portal_user_role, @assignedBy::uuid)
        ON CONFLICT (user_id, role) DO NOTHING
        ''',
        parameters: {'userId': userId, 'role': role, 'assignedBy': user.id},
      );
    }
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

  // Handle regenerating activation code
  if (body['regenerate_activation'] == true) {
    final activationCode = _generateCode();
    final activationExpiry = DateTime.now().add(const Duration(days: 14));

    await db.execute(
      '''
      UPDATE portal_users
      SET activation_code = @code,
          activation_code_expires_at = @expiry,
          status = 'pending',
          updated_at = now()
      WHERE id = @userId::uuid
      ''',
      parameters: {
        'userId': userId,
        'code': activationCode,
        'expiry': activationExpiry,
      },
    );

    return _jsonResponse({'success': true, 'activation_code': activationCode});
  }

  return _jsonResponse({'success': true});
}

/// Get available sites (for user creation dialog)
/// GET /api/v1/portal/sites
///
/// Automatically syncs sites from EDC (RAVE) if:
/// - No sites exist in the database
/// - Sites were last synced more than 1 day ago
Future<Response> getPortalSitesHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  // Sync sites from EDC if needed (stale or missing)
  final syncResult = await syncSitesIfNeeded();
  if (syncResult != null && syncResult.hasError) {
    // Log error but continue - we may still have cached sites
    // In production, this would go to a structured logging system
    print('Sites sync warning: ${syncResult.error}');
  }

  final db = Database.instance;
  final result = await db.execute('''
    SELECT site_id, site_name, site_number, edc_synced_at
    FROM sites
    WHERE is_active = true
    ORDER BY site_number
  ''');

  final sites = result.map((r) {
    return {
      'site_id': r[0] as String,
      'site_name': r[1] as String,
      'site_number': r[2] as String,
      'edc_synced_at': (r[3] as DateTime?)?.toIso8601String(),
    };
  }).toList();

  // Include sync info in response for transparency
  final response = <String, dynamic>{'sites': sites};
  if (syncResult != null) {
    response['sync'] = syncResult.toJson();
  }

  return _jsonResponse(response);
}

/// Generate a random code in XXXXX-XXXXX format
/// Used for both linking codes and activation codes
String _generateCode() {
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
