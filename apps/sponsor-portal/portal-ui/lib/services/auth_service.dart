// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//
// Portal authentication service using Firebase Auth (Identity Platform)
// Supports both TOTP (for Developer Admin) and Email OTP (for other users)

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// MFA type for the user
enum MfaType {
  totp, // Authenticator app (Developer Admin)
  emailOtp, // Email-based OTP (all other users)
  none; // No MFA required (fallback)

  static MfaType fromString(String? type) {
    switch (type) {
      case 'totp':
        return MfaType.totp;
      case 'email_otp':
        return MfaType.emailOtp;
      case 'none':
        return MfaType.none;
      default:
        return MfaType.emailOtp; // Default to email OTP
    }
  }
}

/// Result of an email OTP operation
class EmailOtpResult {
  final bool success;
  final String? error;
  final String? maskedEmail;
  final int? expiresIn;

  EmailOtpResult.success({this.maskedEmail, this.expiresIn})
    : success = true,
      error = null;

  EmailOtpResult.failure(this.error)
    : success = false,
      maskedEmail = null,
      expiresIn = null;
}

/// User roles in the portal
enum UserRole {
  investigator,
  sponsor,
  auditor,
  analyst,
  administrator,
  developerAdmin;

  static UserRole fromString(String role) {
    switch (role) {
      case 'Investigator':
        return UserRole.investigator;
      case 'Sponsor':
        return UserRole.sponsor;
      case 'Auditor':
        return UserRole.auditor;
      case 'Analyst':
        return UserRole.analyst;
      case 'Administrator':
        return UserRole.administrator;
      case 'Developer Admin':
        return UserRole.developerAdmin;
      default:
        return UserRole.investigator;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.investigator:
        return 'Investigator';
      case UserRole.sponsor:
        return 'Sponsor';
      case UserRole.auditor:
        return 'Auditor';
      case UserRole.analyst:
        return 'Analyst';
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.developerAdmin:
        return 'Developer Admin';
    }
  }

  bool get isAdmin =>
      this == UserRole.administrator || this == UserRole.developerAdmin;
}

/// Portal user information from server
/// Supports multiple roles per user with an active role selection
class PortalUser {
  final String id;
  final String email;
  final String name;
  final List<UserRole> roles;
  final UserRole activeRole;
  final String status;
  final List<Map<String, dynamic>> sites;
  final MfaType mfaType;
  final bool emailOtpRequired;

  PortalUser({
    required this.id,
    required this.email,
    required this.name,
    required this.roles,
    required this.activeRole,
    required this.status,
    this.sites = const [],
    this.mfaType = MfaType.emailOtp,
    this.emailOtpRequired = false,
  });

  /// Get the display role (backwards compatibility)
  UserRole get role => activeRole;

  /// Check if user has a specific role
  bool hasRole(UserRole role) => roles.contains(role);

  /// Check if user is an admin (Administrator or Developer Admin)
  bool get isAdmin =>
      roles.contains(UserRole.administrator) ||
      roles.contains(UserRole.developerAdmin);

  /// Check if user has multiple roles
  bool get hasMultipleRoles => roles.length > 1;

  factory PortalUser.fromJson(Map<String, dynamic> json) {
    // Parse roles array, fall back to single role for backwards compatibility
    List<UserRole> roles;
    if (json['roles'] != null) {
      roles = (json['roles'] as List)
          .map((r) => UserRole.fromString(r as String))
          .toList();
    } else if (json['role'] != null) {
      roles = [UserRole.fromString(json['role'] as String)];
    } else {
      roles = [UserRole.investigator]; // Default
    }

    // Parse active role, default to first role
    final activeRoleStr = json['active_role'] as String?;
    final activeRole = activeRoleStr != null
        ? UserRole.fromString(activeRoleStr)
        : roles.first;

    // Parse MFA type
    final mfaType = MfaType.fromString(json['mfa_type'] as String?);
    final emailOtpRequired = json['email_otp_required'] as bool? ?? false;

    return PortalUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      roles: roles,
      activeRole: activeRole,
      status: json['status'] as String,
      sites:
          (json['sites'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          [],
      mfaType: mfaType,
      emailOtpRequired: emailOtpRequired,
    );
  }

  bool canAccessSite(String siteId) {
    // Admins, Sponsors, Auditors, and Analysts can access all sites
    if (activeRole != UserRole.investigator) {
      return true;
    }
    // Investigators can only access assigned sites
    return sites.any((s) => s['site_id'] == siteId);
  }

  /// Create a copy with a different active role
  PortalUser copyWithActiveRole(UserRole newActiveRole) {
    if (!roles.contains(newActiveRole)) {
      throw ArgumentError('User does not have role: $newActiveRole');
    }
    return PortalUser(
      id: id,
      email: email,
      name: name,
      roles: roles,
      activeRole: newActiveRole,
      status: status,
      sites: sites,
      mfaType: mfaType,
      emailOtpRequired: emailOtpRequired,
    );
  }
}

/// Authentication service using Firebase Auth and portal API
class AuthService extends ChangeNotifier {
  /// Create AuthService with optional dependencies for testing
  AuthService({FirebaseAuth? firebaseAuth, http.Client? httpClient})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _httpClient = httpClient ?? http.Client() {
    _init();
  }

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  PortalUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  /// MFA state - resolver for completing MFA challenge (TOTP)
  MultiFactorResolver? _mfaResolver;
  bool _mfaRequired = false;

  /// Email OTP state
  bool _emailOtpRequired = false;
  String? _maskedEmail;

  /// Base URL for portal API
  String get _apiBaseUrl {
    // Check for environment override
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Default to localhost for development
    if (kDebugMode) {
      return 'http://localhost:8080';
    }

    // Use the current host origin in production (same-origin API)
    return Uri.base.origin;
  }

  PortalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;

  /// Whether TOTP MFA verification is required to complete sign-in
  bool get mfaRequired => _mfaRequired;

  /// The MFA resolver for completing the TOTP challenge (null if not required)
  MultiFactorResolver? get mfaResolver => _mfaResolver;

  /// Whether email OTP verification is required to complete sign-in
  bool get emailOtpRequired => _emailOtpRequired;

  /// Masked email address for display (e.g., t***@example.com)
  String? get maskedEmail => _maskedEmail;

  /// Initialize auth state listener
  void _init() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User signed in - fetch portal user info
        await _fetchPortalUser();
      } else {
        // User signed out
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  /// Sign in with email and password
  ///
  /// Returns true if sign-in succeeded (including if MFA is required).
  /// Check [mfaRequired] for TOTP or [emailOtpRequired] for email OTP.
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    _mfaRequired = false;
    _mfaResolver = null;
    _emailOtpRequired = false;
    _maskedEmail = null;
    notifyListeners();

    try {
      // Sign in with Firebase Auth
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Fetch portal user info
      final success = await _fetchPortalUser();
      if (!success) {
        // User authenticated but not authorized for portal
        await _auth.signOut();
        return false;
      }

      // Check if email OTP is required for this user
      if (_currentUser?.emailOtpRequired == true) {
        _emailOtpRequired = true;
        _maskedEmail = _maskEmail(_currentUser!.email);
        _isLoading = false;
        notifyListeners();
        debugPrint('Email OTP required for user: ${_currentUser!.id}');
        return true;
      }

      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      // TOTP MFA required - store resolver for completing the challenge
      _mfaResolver = e.resolver;
      _mfaRequired = true;
      _isLoading = false;
      notifyListeners();
      debugPrint(
        'TOTP MFA required: ${e.resolver.hints.length} factors enrolled',
      );
      return true; // Return true to indicate credentials were valid
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      debugPrint('Firebase auth error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _error = 'Authentication failed. Please try again.';
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      if (!_mfaRequired && !_emailOtpRequired) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Mask email address for display (e.g., test@example.com -> t***@example.com)
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '***@***';
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return '***@$domain';
    return '${local[0]}***@$domain';
  }

  /// Complete MFA sign-in with TOTP code
  ///
  /// Call this after [signIn] returns with [mfaRequired] = true.
  /// Returns true if MFA verification succeeded.
  Future<bool> completeMfaSignIn(String totpCode) async {
    if (_mfaResolver == null) {
      _error = 'No MFA challenge pending';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get the first TOTP hint (we only support TOTP currently)
      final hints = _mfaResolver!.hints;
      MultiFactorInfo? totpHint;

      for (final hint in hints) {
        if (hint is TotpMultiFactorInfo) {
          totpHint = hint;
          break;
        }
      }

      if (totpHint == null) {
        _error = 'No TOTP factor found. Contact support.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Create assertion for sign-in
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        totpHint.uid,
        totpCode,
      );

      // Resolve the MFA challenge
      await _mfaResolver!.resolveSignIn(assertion);

      // Clear MFA state
      _mfaRequired = false;
      _mfaResolver = null;

      // Fetch portal user info
      final success = await _fetchPortalUser();
      if (!success) {
        await _auth.signOut();
        return false;
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      debugPrint('MFA verification error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _error = 'MFA verification failed. Please try again.';
      debugPrint('MFA error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel pending TOTP MFA challenge
  void cancelMfa() {
    _mfaRequired = false;
    _mfaResolver = null;
    _error = null;
    notifyListeners();
  }

  /// Send email OTP code to the user's email
  ///
  /// Call this after [signIn] returns with [emailOtpRequired] = true.
  /// Returns [EmailOtpResult] indicating success or failure.
  Future<EmailOtpResult> sendEmailOtp() async {
    final user = _auth.currentUser;
    if (user == null) {
      return EmailOtpResult.failure('Not authenticated');
    }

    try {
      final idToken = await user.getIdToken();

      final response = await _httpClient.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/auth/send-otp'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        _maskedEmail = data['masked_email'] as String?;
        notifyListeners();
        return EmailOtpResult.success(
          maskedEmail: _maskedEmail,
          expiresIn: data['expires_in'] as int?,
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        return EmailOtpResult.failure(
          data['error'] as String? ?? 'Too many requests. Please wait.',
        );
      } else {
        return EmailOtpResult.failure(
          data['error'] as String? ?? 'Failed to send verification code',
        );
      }
    } catch (e) {
      debugPrint('Error sending email OTP: $e');
      return EmailOtpResult.failure('Failed to send verification code');
    }
  }

  /// Verify email OTP code
  ///
  /// Call this after [sendEmailOtp] to verify the code entered by the user.
  /// Returns [EmailOtpResult] indicating success or failure.
  Future<EmailOtpResult> verifyEmailOtp(String code) async {
    final user = _auth.currentUser;
    if (user == null) {
      return EmailOtpResult.failure('Not authenticated');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final idToken = await user.getIdToken();

      final response = await _httpClient.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/auth/verify-otp'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Clear email OTP state
        _emailOtpRequired = false;
        _maskedEmail = null;
        _isLoading = false;
        notifyListeners();
        return EmailOtpResult.success();
      } else {
        _error = data['error'] as String? ?? 'Invalid verification code';
        _isLoading = false;
        notifyListeners();
        return EmailOtpResult.failure(_error!);
      }
    } catch (e) {
      debugPrint('Error verifying email OTP: $e');
      _error = 'Verification failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return EmailOtpResult.failure(_error!);
    }
  }

  /// Cancel pending email OTP verification
  void cancelEmailOtp() {
    _emailOtpRequired = false;
    _maskedEmail = null;
    _error = null;
    notifyListeners();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _emailOtpRequired = false;
    _maskedEmail = null;
    _mfaRequired = false;
    _mfaResolver = null;
    _error = null;
    notifyListeners();
  }

  /// Fetch portal user info from server
  /// [selectedRole] - Optionally specify which role to activate
  Future<bool> _fetchPortalUser([String? selectedRole]) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Get ID token for API authentication
      final idToken = await user.getIdToken();

      // Build URL with optional role parameter
      var url = '$_apiBaseUrl/api/v1/portal/me';
      if (selectedRole != null) {
        url += '?role=${Uri.encodeComponent(selectedRole)}';
      }

      // Call portal API to get user info
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = PortalUser.fromJson(data);
        notifyListeners();
        return true;
      } else if (response.statusCode == 403) {
        // User not authorized for portal access
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _error = data['error'] as String? ?? 'Not authorized for portal access';
        // Check for pending activation
        if (data['status'] == 'pending') {
          _error = 'pending_activation';
        }
        return false;
      } else {
        _error = 'Failed to fetch user information';
        return false;
      }
    } catch (e) {
      debugPrint('Error fetching portal user: $e');
      _error = 'Failed to connect to server';
      return false;
    }
  }

  /// Switch to a different role (for multi-role users)
  Future<bool> switchRole(UserRole newRole) async {
    if (_currentUser == null) return false;
    if (!_currentUser!.roles.contains(newRole)) return false;

    // Update active role by re-fetching with role parameter
    return await _fetchPortalUser(newRole.displayName);
  }

  /// Check if user needs to select a role (has multiple roles and none selected)
  bool get needsRoleSelection =>
      _currentUser != null && _currentUser!.hasMultipleRoles;

  /// Get fresh ID token for API calls
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Check if user has specific role (in their roles list)
  bool hasRole(UserRole role) {
    return _currentUser?.hasRole(role) ?? false;
  }

  /// Check if user's active role matches
  bool isActiveRole(UserRole role) {
    return _currentUser?.activeRole == role;
  }

  /// Check if user can access a specific site
  bool canAccessSite(String siteId) {
    return _currentUser?.canAccessSite(siteId) ?? false;
  }

  /// Map Firebase error codes to user-friendly messages
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
