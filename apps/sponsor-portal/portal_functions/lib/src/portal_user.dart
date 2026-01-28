// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-d00036: Create User Dialog Implementation
//   REQ-p00028: Token Revocation and Access Control
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-CAL-p00010: Schema-Driven Data Validation (EDC site sync)
//   REQ-CAL-p00029: Create User Account (Study Coordinator, CRA roles)
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00031: Deactivate User Account
//   REQ-CAL-p00032: Reactivate User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00062: Activation code generation on reactivation
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00066: Capture deactivation/reactivation reason
//   REQ-CAL-p00073: Patient Status Definitions
//
// Portal user management - create users, assign sites, revoke access
// Supports multi-role users with activation code flow
// Supports editing user details with audit logging and session termination

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'database.dart';
import 'email_service.dart';
import 'feature_flags.dart';
import 'patients_sync.dart';
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
  const serviceContext = UserContext.service;

  // Get users with roles aggregated from portal_user_roles
  // Exclude Developer Admin users - they are system bootstrap accounts
  final result = await db.executeWithContext('''
    SELECT
      pu.id,
      pu.email,
      pu.name,
      pu.status,
      pu.linking_code,
      pu.activation_code,
      pu.created_at,
      string_agg(DISTINCT pur.role::text, ',' ORDER BY pur.role::text) as roles,
      COALESCE(
        json_agg(
          json_build_object(
            'site_id', s.site_id,
            'site_name', s.site_name,
            'site_number', s.site_number
          )
        ) FILTER (WHERE s.site_id IS NOT NULL),
        '[]'::json
      ) as sites,
      pu.status_change_reason,
      pu.status_changed_at,
      pu.status_changed_by
    FROM portal_users pu
    LEFT JOIN portal_user_roles pur ON pu.id = pur.user_id
    LEFT JOIN portal_user_site_access pusa ON pu.id = pusa.user_id
    LEFT JOIN sites s ON pusa.site_id = s.site_id
    WHERE NOT EXISTS (
      SELECT 1 FROM portal_user_roles dev_check
      WHERE dev_check.user_id = pu.id
        AND dev_check.role = 'Developer Admin'
    )
    GROUP BY pu.id
    ORDER BY pu.created_at DESC
  ''', context: serviceContext);

  final users = result.map((r) {
    // Parse roles - string_agg returns comma-separated text (not text[])
    // which the postgres v3 package reliably decodes as a Dart String.
    final rolesData = r[7];
    print(
      '[PORTAL_USER] rolesData type=${rolesData.runtimeType}, value=$rolesData',
    );
    List<String> roles = [];
    if (rolesData != null && rolesData is String && rolesData.isNotEmpty) {
      roles = rolesData.split(',');
    } else if (rolesData is List) {
      // Fallback in case postgres package does return a List
      roles = rolesData.cast<String>();
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
      'status_change_reason': r[9] as String?,
      'status_changed_at': (r[10] as DateTime?)?.toIso8601String(),
      'status_changed_by': r[11] as String?,
    };
  }).toList();

  return _jsonResponse({'users': users});
}

/// Get a single portal user by ID (Admin/Auditor only)
/// GET /api/v1/portal/users/:userId
/// Returns user with roles, sites, and pending email change
Future<Response> getPortalUserHandler(Request request, String userId) async {
  final user = await requirePortalAuth(request, _viewAllRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  final result = await db.executeWithContext(
    '''
    SELECT
      pu.id,
      pu.email,
      pu.name,
      pu.status,
      pu.created_at,
      pu.tokens_revoked_at,
      string_agg(DISTINCT pur.role::text, ',' ORDER BY pur.role::text) as roles,
      COALESCE(
        json_agg(
          DISTINCT jsonb_build_object(
            'site_id', s.site_id,
            'site_name', s.site_name,
            'site_number', s.site_number
          )
        ) FILTER (WHERE s.site_id IS NOT NULL),
        '[]'::json
      ) as sites,
      pu.status_change_reason,
      pu.status_changed_at,
      pu.status_changed_by
    FROM portal_users pu
    LEFT JOIN portal_user_roles pur ON pu.id = pur.user_id
    LEFT JOIN portal_user_site_access pusa ON pu.id = pusa.user_id
    LEFT JOIN sites s ON pusa.site_id = s.site_id
    WHERE pu.id = @userId::uuid
    GROUP BY pu.id
  ''',
    parameters: {'userId': userId},
    context: serviceContext,
  );

  if (result.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final r = result.first;

  // Parse roles - string_agg returns comma-separated text
  final rolesData = r[6];
  print(
    '[PORTAL_USER] single user rolesData type=${rolesData.runtimeType}, value=$rolesData',
  );
  List<String> roles = [];
  if (rolesData != null && rolesData is String && rolesData.isNotEmpty) {
    roles = rolesData.split(',');
  } else if (rolesData is List) {
    // Fallback in case postgres package does return a List
    roles = rolesData.cast<String>();
  }

  // Parse sites
  List<dynamic> sites = [];
  final sitesJson = r[7];
  if (sitesJson != null) {
    if (sitesJson is String) {
      sites = jsonDecode(sitesJson) as List<dynamic>;
    } else if (sitesJson is List) {
      sites = sitesJson;
    }
  }

  // Check for pending email change
  final pendingEmail = await db.executeWithContext(
    '''
    SELECT new_email, requested_at, expires_at
    FROM portal_pending_email_changes
    WHERE user_id = @userId::uuid
      AND verified_at IS NULL
      AND expires_at > now()
    ORDER BY requested_at DESC
    LIMIT 1
  ''',
    parameters: {'userId': userId},
    context: serviceContext,
  );

  Map<String, dynamic>? pendingEmailChange;
  if (pendingEmail.isNotEmpty) {
    pendingEmailChange = {
      'new_email': pendingEmail.first[0] as String,
      'requested_at': (pendingEmail.first[1] as DateTime).toIso8601String(),
      'expires_at': (pendingEmail.first[2] as DateTime).toIso8601String(),
    };
  }

  return _jsonResponse({
    'id': r[0] as String,
    'email': r[1] as String,
    'name': r[2] as String,
    'status': r[3] as String,
    'created_at': (r[4] as DateTime).toIso8601String(),
    'tokens_revoked_at': (r[5] as DateTime?)?.toIso8601String(),
    'roles': roles,
    'sites': sites,
    'status_change_reason': r[8] as String?,
    'status_changed_at': (r[9] as DateTime?)?.toIso8601String(),
    'status_changed_by': r[10] as String?,
    if (pendingEmailChange != null) 'pending_email_change': pendingEmailChange,
  });
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

  // Validate all roles are valid assignable system roles
  // Note: Sponsor-specific role names (e.g., Callisto's "Study Coordinator")
  // are mapped to system roles via sponsor_role_mapping table at the UI layer.
  // The backend only accepts system role names.
  // Developer Admin is NOT assignable - it's a system bootstrap role only.
  const assignableRoles = [
    'Investigator',
    'Sponsor',
    'Auditor',
    'Analyst',
    'Administrator',
  ];
  for (final role in roles) {
    if (role == 'Developer Admin') {
      return _jsonResponse({
        'error': 'Developer Admin role cannot be assigned',
      }, 403);
    }
    if (!assignableRoles.contains(role)) {
      return _jsonResponse({'error': 'Invalid role: $role'}, 400);
    }
  }

  // Roles that require site assignment
  // Investigator is site-scoped (views only their assigned sites' data)
  const siteRequiredRoles = ['Investigator'];
  final needsSites = roles.any((r) => siteRequiredRoles.contains(r));

  if (needsSites && siteIds.isEmpty) {
    return _jsonResponse({
      'error': 'site assignment required for selected role(s)',
    }, 400);
  }

  // Note: Developer Admin role is already blocked above in assignableRoles check.
  // Regular Admins CAN create other Admins - this is the normal bootstrap flow.

  // NOTE: Linking codes are ONLY for patients (diary app device linking).
  // Portal users (Admins, Investigators, etc.) only need activation codes.
  // Patient enrollment is handled separately, not through this endpoint.

  // Generate activation code for all new users
  final activationCode = _generateCode();
  final activationExpiry = DateTime.now().add(const Duration(days: 14));

  print('[PORTAL_USER] Generated activation_code=$activationCode for $email');

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Check for duplicate email
  final existing = await db.executeWithContext(
    'SELECT id FROM portal_users WHERE email = @email',
    parameters: {'email': email},
    context: serviceContext,
  );
  if (existing.isNotEmpty) {
    return _jsonResponse({'error': 'Email already exists'}, 409);
  }

  // Create user with pending status
  // NOTE: linking_code is NULL for portal users - only patients get linking codes
  final createResult = await db.executeWithContext(
    '''
    INSERT INTO portal_users (
      email, name, activation_code,
      activation_code_expires_at, status
    )
    VALUES (
      @email, @name, @activationCode,
      @activationExpiry, 'pending'
    )
    RETURNING id
    ''',
    parameters: {
      'email': email,
      'name': name,
      'activationCode': activationCode,
      'activationExpiry': activationExpiry,
    },
    context: serviceContext,
  );

  final newUserId = createResult.first[0] as String;
  print(
    '[PORTAL_USER] INSERT complete: userId=$newUserId, activation_code=$activationCode',
  );

  // Verify the code was stored correctly
  final verifyResult = await db.executeWithContext(
    'SELECT activation_code FROM portal_users WHERE id = @id::uuid',
    parameters: {'id': newUserId},
    context: serviceContext,
  );
  final storedCode = verifyResult.isNotEmpty
      ? verifyResult.first[0]
      : 'NOT_FOUND';
  print(
    '[PORTAL_USER] VERIFY: stored_code=$storedCode, matches=${storedCode == activationCode}',
  );

  // Create role assignments in portal_user_roles
  for (final role in roles) {
    await db.executeWithContext(
      '''
      INSERT INTO portal_user_roles (user_id, role, assigned_by)
      VALUES (@userId::uuid, @role::portal_user_role, @assignedBy::uuid)
      ON CONFLICT (user_id, role) DO NOTHING
      ''',
      parameters: {'userId': newUserId, 'role': role, 'assignedBy': user.id},
      context: serviceContext,
    );
  }

  // Create site assignments for site-based roles
  if (needsSites && siteIds.isNotEmpty) {
    for (final siteId in siteIds) {
      await db.executeWithContext(
        '''
        INSERT INTO portal_user_site_access (user_id, site_id)
        VALUES (@userId::uuid, @siteId)
        ON CONFLICT (user_id, site_id) DO NOTHING
        ''',
        parameters: {'userId': newUserId, 'siteId': siteId},
        context: serviceContext,
      );
    }
  }

  // Try to send activation email if feature is enabled
  bool emailSent = false;
  String? emailError;

  if (FeatureFlags.emailActivation) {
    // Construct activation URL from environment or request
    final portalBaseUrl =
        Platform.environment['PORTAL_URL'] ??
        Platform.environment['PORTAL_BASE_URL'] ??
        'http://localhost:8081';
    final activationUrl = '$portalBaseUrl/activate?code=$activationCode';

    final emailResult = await EmailService.instance.sendActivationCode(
      recipientEmail: email,
      recipientName: name,
      activationCode: activationCode,
      activationUrl: activationUrl,
      sentByUserId: user.id,
    );

    emailSent = emailResult.success;
    emailError = emailResult.error;

    if (emailSent) {
      print('[PORTAL_USER] Activation email sent to $email');
    } else {
      print('[PORTAL_USER] Failed to send activation email: $emailError');
    }
  }

  print(
    '[PORTAL_USER] RESPONSE: activation_code=$activationCode (returning to client)',
  );

  // NOTE: linking_code not included - portal users don't need linking codes
  // Linking codes are only for patients (diary app device linking)
  return _jsonResponse({
    'id': newUserId,
    'email': email,
    'name': name,
    'roles': roles,
    'status': 'pending',
    'activation_code': activationCode,
    'site_ids': siteIds,
    'email_sent': emailSent,
    if (emailError != null) 'email_error': emailError,
  }, 201);
}

/// Update portal user (Admin only)
/// PATCH /api/v1/portal/users/:userId
/// Body: { name, roles: [...], site_ids: [...], status, regenerate_activation }
///
/// Supports updating name, roles, sites, and status.
/// Changes to roles/sites trigger session termination (tokens_revoked_at).
/// All changes are logged to portal_user_audit_log.
Future<Response> updatePortalUserHandler(Request request, String userId) async {
  final user = await requirePortalAuth(request, _adminRoles);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  // Prevent self-modification
  if (userId == user.id) {
    return _jsonResponse({'error': 'Cannot modify your own account'}, 400);
  }

  final body = await _parseJson(request);
  if (body == null) {
    return _jsonResponse({'error': 'Invalid JSON body'}, 400);
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Get target user with current state
  final userResult = await db.executeWithContext(
    'SELECT id, name, email, status FROM portal_users WHERE id = @userId::uuid',
    parameters: {'userId': userId},
    context: serviceContext,
  );
  if (userResult.isEmpty) {
    return _jsonResponse({'error': 'User not found'}, 404);
  }

  final currentName = userResult.first[1] as String;
  final currentStatus = userResult.first[3] as String;

  // Get target user's current roles
  final rolesResult = await db.executeWithContext(
    '''
    SELECT COALESCE(
      array_agg(role::text ORDER BY role),
      ARRAY[]::text[]
    ) as roles
    FROM portal_user_roles
    WHERE user_id = @userId::uuid
    ''',
    parameters: {'userId': userId},
    context: serviceContext,
  );
  List<String> targetRoles = [];
  if (rolesResult.isNotEmpty && rolesResult.first[0] != null) {
    targetRoles = (rolesResult.first[0] as List).cast<String>();
  }

  // Get target user's current sites
  final sitesResult = await db.executeWithContext(
    '''
    SELECT COALESCE(
      array_agg(site_id ORDER BY site_id),
      ARRAY[]::text[]
    ) as site_ids
    FROM portal_user_site_access
    WHERE user_id = @userId::uuid
    ''',
    parameters: {'userId': userId},
    context: serviceContext,
  );
  List<String> currentSiteIds = [];
  if (sitesResult.isNotEmpty && sitesResult.first[0] != null) {
    currentSiteIds = (sitesResult.first[0] as List).cast<String>();
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

  // Track whether permissions changed (requires session termination)
  bool permissionsChanged = false;

  // Handle name update
  final newName = body['name'] as String?;
  if (newName != null && newName.isNotEmpty && newName != currentName) {
    await db.executeWithContext(
      'UPDATE portal_users SET name = @name, updated_at = now() WHERE id = @userId::uuid',
      parameters: {'userId': userId, 'name': newName},
      context: serviceContext,
    );

    await _logAudit(
      db,
      userId: userId,
      changedBy: user.id,
      action: 'update_name',
      before: {'name': currentName},
      after: {'name': newName},
    );
  }

  // Handle status update (revocation/reactivation)
  final status = body['status'] as String?;
  if (status != null) {
    if (status != 'revoked' && status != 'active' && status != 'pending') {
      return _jsonResponse({'error': 'Invalid status'}, 400);
    }

    // Capture optional reason for status change (REQ-CAL-p00066)
    final reason = body['reason'] as String?;

    // Reactivation from revoked: generate new activation code, set pending,
    // and send activation email (REQ-CAL-p00032, REQ-CAL-p00062)
    if (status == 'active' && currentStatus == 'revoked') {
      final activationCode = _generateCode();
      final activationExpiry = DateTime.now().add(const Duration(days: 14));

      await db.executeWithContext(
        '''
        UPDATE portal_users
        SET status = 'pending',
            activation_code = @code,
            activation_code_expires_at = @expiry,
            status_change_reason = @reason,
            status_changed_at = now(),
            status_changed_by = @changedBy::uuid,
            updated_at = now()
        WHERE id = @userId::uuid
        ''',
        parameters: {
          'userId': userId,
          'code': activationCode,
          'expiry': activationExpiry,
          'reason': reason,
          'changedBy': user.id,
        },
        context: serviceContext,
      );

      await _logAudit(
        db,
        userId: userId,
        changedBy: user.id,
        action: 'update_status',
        before: {'status': currentStatus},
        after: {'status': 'pending', if (reason != null) 'reason': reason},
      );

      // Send activation email
      final currentEmail = userResult.first[2] as String;
      bool emailSent = false;
      String? emailError;

      if (FeatureFlags.emailActivation) {
        final portalBaseUrl =
            Platform.environment['PORTAL_URL'] ??
            Platform.environment['PORTAL_BASE_URL'] ??
            'http://localhost:8081';
        final activationUrl = '$portalBaseUrl/activate?code=$activationCode';

        final emailResult = await EmailService.instance.sendActivationCode(
          recipientEmail: currentEmail,
          recipientName: currentName,
          activationCode: activationCode,
          activationUrl: activationUrl,
          sentByUserId: user.id,
        );

        emailSent = emailResult.success;
        emailError = emailResult.error;

        if (emailSent) {
          print('[PORTAL_USER] Reactivation email sent to $currentEmail');
        } else {
          print('[PORTAL_USER] Failed to send reactivation email: $emailError');
        }
      }

      print(
        '[PORTAL_USER] User $userId reactivated: '
        'status=pending, activation_code=$activationCode',
      );

      return _jsonResponse({
        'success': true,
        'activation_code': activationCode,
        'email_sent': emailSent,
        if (emailError != null) 'email_error': emailError,
      });
    }

    // Standard status update (deactivation or other transitions)
    await db.executeWithContext(
      '''
      UPDATE portal_users
      SET status = @status,
          status_change_reason = @reason,
          status_changed_at = now(),
          status_changed_by = @changedBy::uuid,
          updated_at = now()
      WHERE id = @userId::uuid
      ''',
      parameters: {
        'userId': userId,
        'status': status,
        'reason': reason,
        'changedBy': user.id,
      },
      context: serviceContext,
    );

    await _logAudit(
      db,
      userId: userId,
      changedBy: user.id,
      action: 'update_status',
      before: {'status': currentStatus},
      after: {'status': status, if (reason != null) 'reason': reason},
    );

    if (status == 'revoked') {
      permissionsChanged = true;
    }
  }

  // Handle roles update
  final newRoles = body['roles'] as List?;
  if (newRoles != null) {
    final newRolesList = newRoles.cast<String>();

    // Validate roles
    const assignableRoles = [
      'Investigator',
      'Sponsor',
      'Auditor',
      'Analyst',
      'Administrator',
    ];
    for (final role in newRolesList) {
      if (role == 'Developer Admin') {
        return _jsonResponse({
          'error': 'Developer Admin role cannot be assigned',
        }, 403);
      }
      if (!assignableRoles.contains(role)) {
        return _jsonResponse({'error': 'Invalid role: $role'}, 400);
      }
    }

    // Clear existing role assignments
    await db.executeWithContext(
      'DELETE FROM portal_user_roles WHERE user_id = @userId::uuid',
      parameters: {'userId': userId},
      context: serviceContext,
    );

    // Add new role assignments
    for (final role in newRolesList) {
      await db.executeWithContext(
        '''
        INSERT INTO portal_user_roles (user_id, role, assigned_by)
        VALUES (@userId::uuid, @role::portal_user_role, @assignedBy::uuid)
        ON CONFLICT (user_id, role) DO NOTHING
        ''',
        parameters: {'userId': userId, 'role': role, 'assignedBy': user.id},
        context: serviceContext,
      );
    }

    // Check if roles actually changed
    final sortedOld = List<String>.from(targetRoles)..sort();
    final sortedNew = List<String>.from(newRolesList)..sort();
    if (sortedOld.join(',') != sortedNew.join(',')) {
      permissionsChanged = true;

      await _logAudit(
        db,
        userId: userId,
        changedBy: user.id,
        action: 'update_roles',
        before: {'roles': targetRoles},
        after: {'roles': newRolesList},
      );
    }
  }

  // Handle site assignment update
  final siteIds = body['site_ids'] as List?;
  if (siteIds != null) {
    final newSiteIds = siteIds.cast<String>();

    // Clear existing assignments
    await db.executeWithContext(
      'DELETE FROM portal_user_site_access WHERE user_id = @userId::uuid',
      parameters: {'userId': userId},
      context: serviceContext,
    );

    // Add new assignments
    for (final siteId in newSiteIds) {
      await db.executeWithContext(
        '''
        INSERT INTO portal_user_site_access (user_id, site_id)
        VALUES (@userId::uuid, @siteId)
        ON CONFLICT (user_id, site_id) DO NOTHING
        ''',
        parameters: {'userId': userId, 'siteId': siteId},
        context: serviceContext,
      );
    }

    // Check if sites actually changed
    final sortedOld = List<String>.from(currentSiteIds)..sort();
    final sortedNew = List<String>.from(newSiteIds)..sort();
    if (sortedOld.join(',') != sortedNew.join(',')) {
      permissionsChanged = true;

      await _logAudit(
        db,
        userId: userId,
        changedBy: user.id,
        action: 'update_sites',
        before: {'site_ids': currentSiteIds},
        after: {'site_ids': newSiteIds},
      );
    }
  }

  // Handle regenerating activation code
  if (body['regenerate_activation'] == true) {
    final activationCode = _generateCode();
    final activationExpiry = DateTime.now().add(const Duration(days: 14));

    await db.executeWithContext(
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
      context: serviceContext,
    );

    return _jsonResponse({'success': true, 'activation_code': activationCode});
  }

  // Terminate active sessions if permissions changed
  if (permissionsChanged) {
    await db.executeWithContext(
      '''
      UPDATE portal_users
      SET tokens_revoked_at = now(), updated_at = now()
      WHERE id = @userId::uuid
      ''',
      parameters: {'userId': userId},
      context: serviceContext,
    );

    await _logAudit(
      db,
      userId: userId,
      changedBy: user.id,
      action: 'revoke_sessions',
      before: null,
      after: {'reason': 'permissions_changed'},
    );

    print(
      '[PORTAL_USER] Sessions terminated for user $userId due to permission changes',
    );
  }

  return _jsonResponse({
    'success': true,
    'sessions_terminated': permissionsChanged,
  });
}

/// Log an audit entry for user modifications
Future<void> _logAudit(
  Database db, {
  required String userId,
  required String changedBy,
  required String action,
  required Map<String, dynamic>? before,
  required Map<String, dynamic>? after,
}) async {
  await db.executeWithContext(
    '''
    INSERT INTO portal_user_audit_log (user_id, changed_by, action, before_value, after_value)
    VALUES (@userId::uuid, @changedBy::uuid, @action,
            @before::jsonb, @after::jsonb)
    ''',
    parameters: {
      'userId': userId,
      'changedBy': changedBy,
      'action': action,
      'before': before != null ? jsonEncode(before) : null,
      'after': after != null ? jsonEncode(after) : null,
    },
    context: UserContext.service,
  );
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
  const serviceContext = UserContext.service;
  final result = await db.executeWithContext('''
    SELECT site_id, site_name, site_number, edc_synced_at
    FROM sites
    WHERE is_active = true
    ORDER BY site_number
  ''', context: serviceContext);

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

/// Get patients synced from EDC (RAVE)
/// GET /api/v1/portal/patients
///
/// Automatically syncs patients from EDC if:
/// - No patients exist in the database
/// - Patients were last synced more than 1 day ago
///
/// IMPLEMENTS REQUIREMENTS:
///   REQ-CAL-p00063: EDC Patient Ingestion
///   REQ-CAL-p00073: Patient Status Definitions
Future<Response> getPortalPatientsHandler(Request request) async {
  final user = await requirePortalAuth(request);
  if (user == null) {
    return _jsonResponse({'error': 'Unauthorized'}, 403);
  }

  // Ensure sites are synced first (patients FK to sites)
  final sitesSyncResult = await syncSitesIfNeeded();
  if (sitesSyncResult != null && sitesSyncResult.hasError) {
    print('Sites sync warning: ${sitesSyncResult.error}');
  }

  // Sync patients from EDC if needed (stale or missing)
  final syncResult = await syncPatientsIfNeeded();
  if (syncResult != null && syncResult.hasError) {
    print('Patients sync warning: ${syncResult.error}');
  }

  final db = Database.instance;
  const serviceContext = UserContext.service;

  // Investigators (Study Coordinators) only see patients from assigned sites
  final isInvestigator = user.activeRole == 'Investigator';
  final siteIds = isInvestigator
      ? user.sites.map((s) => s['site_id'] as String).toList()
      : <String>[];

  late final List<List<dynamic>> result;
  if (isInvestigator && siteIds.isNotEmpty) {
    result = await db.executeWithContext(
      '''
      SELECT
        p.patient_id,
        p.site_id,
        p.edc_subject_key,
        p.mobile_linking_status::text,
        p.edc_synced_at,
        s.site_name,
        s.site_number
      FROM patients p
      JOIN sites s ON p.site_id = s.site_id
      WHERE p.site_id = ANY(@siteIds)
      ORDER BY p.patient_id
    ''',
      parameters: {'siteIds': siteIds},
      context: serviceContext,
    );
  } else if (isInvestigator && siteIds.isEmpty) {
    // Investigator with no assigned sites sees no patients
    result = [];
  } else {
    // Admins, Sponsors, Auditors see all patients
    result = await db.executeWithContext('''
      SELECT
        p.patient_id,
        p.site_id,
        p.edc_subject_key,
        p.mobile_linking_status::text,
        p.edc_synced_at,
        s.site_name,
        s.site_number
      FROM patients p
      JOIN sites s ON p.site_id = s.site_id
      ORDER BY p.patient_id
    ''', context: serviceContext);
  }

  final patients = result.map((r) {
    return {
      'patient_id': r[0] as String,
      'site_id': r[1] as String,
      'edc_subject_key': r[2] as String,
      'mobile_linking_status': r[3] as String,
      'edc_synced_at': (r[4] as DateTime?)?.toIso8601String(),
      'site_name': r[5] as String,
      'site_number': r[6] as String,
    };
  }).toList();

  final response = <String, dynamic>{'patients': patients};
  if (syncResult != null) {
    response['sync'] = syncResult.toJson();
  }

  // Include user's assigned sites for Investigators (UI needs for "My Sites")
  if (isInvestigator) {
    response['assigned_sites'] = user.sites;
  }

  return _jsonResponse(response);
}

/// Verify an email change using a verification token
/// POST /api/v1/portal/email-verification/:token
///
/// Validates the token, updates the user's email, and revokes sessions.
Future<Response> verifyEmailChangeHandler(Request request, String token) async {
  final db = Database.instance;
  const serviceContext = UserContext.service;
  final tokenHash = hashVerificationToken(token);

  // Find pending change with matching token
  final result = await db.executeWithContext(
    '''
    SELECT pec.id, pec.user_id, pec.new_email, pec.expires_at, pu.email as old_email
    FROM portal_pending_email_changes pec
    JOIN portal_users pu ON pec.user_id = pu.id
    WHERE pec.token_hash = @tokenHash
      AND pec.verified_at IS NULL
    LIMIT 1
  ''',
    parameters: {'tokenHash': tokenHash},
    context: serviceContext,
  );

  if (result.isEmpty) {
    return _jsonResponse({
      'error': 'Invalid or expired verification link',
    }, 400);
  }

  final changeId = result.first[0] as String;
  final userId = result.first[1] as String;
  final newEmail = result.first[2] as String;
  final expiresAt = result.first[3] as DateTime;
  final oldEmail = result.first[4] as String;

  // Check expiration
  if (DateTime.now().isAfter(expiresAt)) {
    return _jsonResponse({'error': 'Verification link has expired'}, 400);
  }

  // Check new email isn't already taken
  final emailExists = await db.executeWithContext(
    'SELECT id FROM portal_users WHERE email = @email AND id != @userId::uuid',
    parameters: {'email': newEmail, 'userId': userId},
    context: serviceContext,
  );
  if (emailExists.isNotEmpty) {
    return _jsonResponse({'error': 'Email address is already in use'}, 409);
  }

  // Update email
  await db.executeWithContext(
    'UPDATE portal_users SET email = @email, updated_at = now() WHERE id = @userId::uuid',
    parameters: {'email': newEmail, 'userId': userId},
    context: serviceContext,
  );

  // Mark verification as used
  await db.executeWithContext(
    'UPDATE portal_pending_email_changes SET verified_at = now() WHERE id = @id::uuid',
    parameters: {'id': changeId},
    context: serviceContext,
  );

  // Revoke sessions
  await db.executeWithContext(
    'UPDATE portal_users SET tokens_revoked_at = now() WHERE id = @userId::uuid',
    parameters: {'userId': userId},
    context: serviceContext,
  );

  // Audit log
  await _logAudit(
    db,
    userId: userId,
    changedBy: userId,
    action: 'update_email',
    before: {'email': oldEmail},
    after: {'email': newEmail},
  );

  return _jsonResponse({'success': true, 'email': newEmail});
}

/// Generate a cryptographic verification token (URL-safe)
String generateVerificationToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// Hash a verification token using SHA-256
String hashVerificationToken(String token) {
  return sha256.convert(utf8.encode(token)).toString();
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
