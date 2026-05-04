// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-p01044-C: Sponsors SHALL be able to configure the inactivity timeout
//   REQ-d00080-A: client-side session management with configurable inactivity timeout
//
// Portal authentication service using Firebase Auth (Identity Platform)
// Supports both TOTP (for Developer Admin) and Email OTP (for other users)

import 'dart:async';
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

/// System roles in the portal (stored in database)
///
/// These are the canonical system role names. Sponsors may have different
/// display names for these roles (e.g., Callisto uses "Study Coordinator"
/// for Investigator, "CRA" for Auditor). The mapping is stored in the
/// sponsor_role_mapping table and applied at the UI layer.
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

  /// System role name (sent to backend)
  String get systemName {
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

  /// Default display name (can be overridden by sponsor mapping)
  String get displayName => systemName;

  bool get isAdmin =>
      this == UserRole.administrator || this == UserRole.developerAdmin;

  /// Whether this role requires site assignment.
  ///
  /// Site-scoped system roles:
  /// - Investigator (e.g. Study Coordinator) — can only see assigned sites
  /// - Auditor (e.g. CRA) — assigned to specific sites per REQ-CAL-p00029.B
  bool get requiresSiteAssignment =>
      this == UserRole.investigator || this == UserRole.auditor;
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

// No-op storage clear used on non-web platforms and in unit tests.
// main.dart injects the real browser implementation on web.
Future<void> _noopStorage() async {}

/// Authentication service using Firebase Auth and portal API
class AuthService extends ChangeNotifier {
  /// Create AuthService with optional dependencies for testing.
  ///
  /// [inactivityTimeout] controls how long without activity before the user
  /// is automatically signed out. Defaults to 2 minutes (REQ-p01044-B). Pass a
  /// shorter duration in tests to avoid sleeping.
  AuthService({
    String sponsorId = '',
    FirebaseAuth? firebaseAuth,
    http.Client? httpClient,
    Duration inactivityTimeout = const Duration(minutes: 2),
    bool enableInactivityTimer = true,
    Future<void> Function()? clearStorage,
    bool isPageRefresh = false,
  }) : _sponsorId = sponsorId,
       _auth = firebaseAuth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _inactivityTimeout = inactivityTimeout,
       _enableInactivityTimer = enableInactivityTimer,
       _isPageRefresh = isPageRefresh,
       // REQ-d00083-A..E, REQ-p01044-J..M: default is a no-op; main.dart injects
       // the real browser implementation on web.
       _clearStorage = clearStorage ?? _noopStorage {
    _init();
  }

  final String _sponsorId;
  final bool _enableInactivityTimer;

  /// CUR-1118: true when this page load is a same-tab refresh (F5/Cmd+R).
  /// When false (fresh tab / post-close), stale Firebase sessions are cleared
  /// inside _init() after Firebase has finished restoring from IndexedDB.
  final bool _isPageRefresh;
  // REQ-d00083-A..E, REQ-p01044-J..M: injectable for testing, web impl by default
  final Future<void> Function() _clearStorage;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  // REQ-p01044-C: mutable so sponsor config can override after login
  Duration _inactivityTimeout;

  // REQ-p70010-C: sponsor-configurable disconnect reason format
  bool _disconnectReasonDropdown = true;

  PortalUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  /// True once the first authStateChanges event has been fully processed.
  ///
  /// CUR-1118: Firebase Auth restores its session from IndexedDB
  /// asynchronously after a page refresh. Dashboard pages must wait for this
  /// flag before deciding to redirect to /login, otherwise they see
  /// isAuthenticated=false transiently and kick the user out on every refresh.
  bool _isInitialized = false;

  /// The Firebase UID that this tab signed in with.
  /// Used to detect cross-tab session collisions (CUR-982).
  String? _sessionUid;

  /// Inactivity timer — fires [_inactivityTimeout] after the last activity.
  Timer? _inactivityTimer;

  /// Warning timer — fires [_warningLeadTime] before the inactivity timeout.
  Timer? _warningTimer;

  /// How long before timeout to show the warning dialog (30 seconds).
  static const Duration _warningLeadTime = Duration(seconds: 30);

  /// True when the session was ended due to inactivity (not an explicit sign-out).
  bool _timedOut = false;

  /// True when the inactivity warning dialog should be shown.
  // REQ-d00080-D, REQ-p01044-G: warn user before session timeout
  bool _isWarning = false;

  /// Whether the previous session ended because of inactivity.
  bool get isTimedOut => _timedOut;

  /// Whether the inactivity warning dialog is currently active.
  bool get isWarning => _isWarning;

  void setIsTimedOut(bool value) {
    _timedOut = value;
    notifyListeners();
  }

  /// Test-only helper — directly set the warning flag without a timer.
  @visibleForTesting
  void debugSetWarning(bool value) {
    _isWarning = value;
    notifyListeners();
  }

  // Exposes the current inactivity timeout for testing.
  @visibleForTesting
  Duration get currentInactivityTimeout => _inactivityTimeout;

  // REQ-p70010-C: whether this sponsor uses predefined dropdown (true) or free text (false).
  bool get disconnectReasonDropdown => _disconnectReasonDropdown;

  /// Update the inactivity timeout.
  ///
  /// REQ-p01044-C: allows sponsor config to override the default timeout.
  /// If a session timer is already running, it is restarted with the new duration.
  void updateInactivityTimeout(Duration newTimeout) {
    _inactivityTimeout = newTimeout;
    // Only reset if a timer is actively running (i.e. session is live)
    if (_inactivityTimer != null && _enableInactivityTimer) {
      resetInactivityTimer();
    }
  }

  /// Sponsor role name mappings (systemRole → sponsorName)
  Map<String, String> _sponsorRoleNames = {};

  /// Sponsor role description mappings (systemRole → description)
  Map<String, String> _sponsorRoleDescriptions = {};

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
      return 'http://localhost:8084';
    }

    // Use the current host origin in production (same-origin API)
    return Uri.base.origin;
  }

  PortalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String get sponsorId => _sponsorId;

  /// Get sponsor display name for a system role, falling back to the system name
  String sponsorRoleName(String systemRole) =>
      _sponsorRoleNames[systemRole] ?? systemRole;

  /// Get sponsor description for a system role, or null if not set
  String? sponsorRoleDescription(String systemRole) =>
      _sponsorRoleDescriptions[systemRole];

  /// Whether TOTP MFA verification is required to complete sign-in
  bool get mfaRequired => _mfaRequired;

  /// The MFA resolver for completing the TOTP challenge (null if not required)
  MultiFactorResolver? get mfaResolver => _mfaResolver;

  /// Whether email OTP verification is required to complete sign-in
  bool get emailOtpRequired => _emailOtpRequired;

  /// Masked email address for display (e.g., t***@example.com)
  String? get maskedEmail => _maskedEmail;

  // REQ-d00080-C: reset inactivity timer on any tracked user interaction
  // REQ-d00080-E, REQ-p01044-I: resetting also dismisses the warning dialog
  void resetInactivityTimer() {
    if (!_enableInactivityTimer) return;
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();

    // Dismiss any active warning
    if (_isWarning) {
      _isWarning = false;
      notifyListeners();
    }

    // Schedule warning before the main timeout.
    // If timeout <= _warningLeadTime, warn at the halfway point instead.
    final warningDelay = _inactivityTimeout > _warningLeadTime
        ? _inactivityTimeout - _warningLeadTime
        : _inactivityTimeout ~/ 2;

    _warningTimer = Timer(warningDelay, _onInactivityWarning);
    _inactivityTimer = Timer(_inactivityTimeout, _onInactivityTimeout);
  }

  /// Called when the warning timer fires — show the countdown dialog.
  // REQ-d00080-D, REQ-p01044-G/H: warn user with dialog showing countdown
  void _onInactivityWarning() {
    _warningTimer = null;
    _isWarning = true;
    notifyListeners();
  }

  /// Called when the inactivity timer fires.
  // REQ-d00080-F: terminate session when inactivity timeout expires without user extension
  void _onInactivityTimeout() async {
    _inactivityTimer = null;
    _warningTimer?.cancel();
    _warningTimer = null;
    _isWarning = false;
    _timedOut = true;

    try {
      await signOut(fromInactivity: true);
    } catch (e) {
      debugPrint('Error signing out after inactivity timeout: $e');
    }
  }

  /// Initialize auth state listener
  void _init() {
    _auth.authStateChanges().listen((User? user) async {
      // CUR-1118: If this is a fresh tab (not a page refresh) and Firebase
      // restored a stale session from IndexedDB, sign out now.
      // We do this HERE (not in main.dart) because Firebase needs time to
      // restore the session from IndexedDB before we can sign out of it.
      // The !_isInitialized guard ensures this only fires on the FIRST
      // authStateChanges event (initial restoration), not on subsequent
      // events from explicit signIn() calls.
      // The _clearStorage != _noopStorage guard ensures this only runs in
      // the browser (where main.dart injects BrowserStorageService), not in
      // unit tests which use the default no-op.
      if (user != null &&
          !_isPageRefresh &&
          !_isInitialized &&
          _sessionUid == null &&
          _clearStorage != _noopStorage) {
        await signOut();
        return;
      }

      if (user != null && _sessionUid != null && user.uid != _sessionUid) {
        // CUR-982: A different user signed in from another tab, overwriting
        // this tab's Firebase auth state via shared localStorage. Sign out
        // to prevent role-escalation display mismatch (FDA 21 CFR Part 11).
        debugPrint(
          '[AUTH] Cross-tab session collision detected: '
          'expected $_sessionUid, got ${user.uid}. Signing out.',
        );
        await signOut();
      } else if (user != null) {
        // Same user signed in or session restored — fetch portal user info.
        // CUR-1118: Track the UID so cross-tab collision detection (CUR-982)
        // works after a page refresh, not only after an explicit signIn().
        _sessionUid ??= user.uid;
        await _fetchPortalUser();
        // Ensure _isInitialized is set even if _fetchPortalUser() fails
        // (e.g. 403 or network error), so dashboard pages stop showing
        // a spinner and redirect to login instead of spinning forever.
        if (!_isInitialized) {
          _isInitialized = true;
          notifyListeners();
        }
      } else {
        // User signed out externally (e.g. token expiry, Firebase forced logout).
        // Cancel both timers and clear the warning flag so UserActivityListener
        // does not attempt to dismiss a dialog that may no longer exist.
        _inactivityTimer?.cancel();
        _inactivityTimer = null;
        _warningTimer?.cancel();
        _warningTimer = null;
        _isWarning = false;
        _currentUser = null;
        _isInitialized = true;
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

      // CUR-982: Track this tab's Firebase UID to detect cross-tab collisions
      _sessionUid = _auth.currentUser?.uid;

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

      // Full login complete (no MFA required) — start inactivity timer.
      _timedOut = false;
      resetInactivityTimer();
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

      // TOTP MFA login complete — start inactivity timer.
      _timedOut = false;
      resetInactivityTimer();
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

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer?.cancel();
    _warningTimer = null;
    super.dispose();
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

        // Refresh portal user data after OTP verification
        // This ensures currentUser has up-to-date roles and status
        await _fetchPortalUser();

        // Email OTP login complete — start inactivity timer.
        _timedOut = false;
        resetInactivityTimer();

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
  Future<void> signOut({bool fromInactivity = false}) async {
    // Cancel both timers before signing out so they don't fire after.
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer?.cancel();
    _warningTimer = null;
    _isWarning = false;
    if (fromInactivity) {
      _timedOut = true;
    } else {
      _timedOut = false;
    }

    // REQ-d00083-A..E, REQ-p01044-J..M: clear all client-side storage so no
    // patient data remains recoverable after logout or session timeout.
    await _clearStorage();

    await _auth.signOut();
    _currentUser = null;
    _sponsorRoleNames = {};
    _sponsorRoleDescriptions = {};
    _sponsorTimeoutFetched = false;
    _sessionUid = null;
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
        // Fetch sponsor role mappings if not loaded yet
        if (_sponsorRoleNames.isEmpty) {
          await _fetchSponsorRoleMappings(idToken!);
        }
        _isInitialized = true;
        notifyListeners();
        // REQ-p01044-C: apply sponsor-configurable inactivity timeout
        await _fetchSponsorTimeout();
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

  /// Whether the sponsor timeout has already been fetched this session.
  bool _sponsorTimeoutFetched = false;

  /// Fetch the sponsor-configurable inactivity timeout and apply it.
  ///
  /// REQ-p01044-C: sponsors can configure inactivity timeout (1–30 minutes).
  /// Silently falls back to the current timeout on any error.
  /// Only fetches once per session.
  Future<void> _fetchSponsorTimeout() async {
    if (_sponsorTimeoutFetched) return;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl/api/v1/sponsor/config?sponsorId=$_sponsorId'),
      );

      if (response.statusCode == 200) {
        _sponsorTimeoutFetched = true;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final flags = data['flags'] as Map<String, dynamic>?;
        final minutes = flags?['inactivityTimeoutMinutes'] as int?;
        debugPrint('Fetched sponsor inactivity timeout: $minutes minutes');
        if (minutes != null) {
          // Clamp to the valid 1–30 minute range (REQ-p01044-C)
          final clamped = minutes.clamp(1, 30);
          updateInactivityTimeout(Duration(minutes: clamped));
          debugPrint('[AuthService] Sponsor timeout applied: $clamped min');
        }
        // REQ-p70010-C: disconnect reason format flag
        _disconnectReasonDropdown =
            flags?['disconnectReasonDropdown'] as bool? ?? true;
      }
    } catch (e) {
      debugPrint(
        '[AuthService] Failed to fetch sponsor timeout, using default: $e',
      );
    }
  }

  /// Fetch sponsor role name mappings from the API
  Future<void> _fetchSponsorRoleMappings(String idToken) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl/api/v1/sponsor/roles?sponsorId=$_sponsorId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mappingsList = (data['mappings'] as List?) ?? [];
        final nameMap = <String, String>{};
        final descMap = <String, String>{};
        for (final m in mappingsList) {
          final mapping = m as Map<String, dynamic>;
          final systemRole = mapping['systemRole'] as String;
          nameMap[systemRole] = mapping['sponsorName'] as String;
          final desc = mapping['description'] as String?;
          if (desc != null && desc.isNotEmpty) {
            descMap[systemRole] = desc;
          }
        }
        _sponsorRoleNames = nameMap;
        _sponsorRoleDescriptions = descMap;
      }
    } catch (e) {
      debugPrint('Error fetching sponsor role mappings: $e');
      // Non-fatal: fall back to system names
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

  // ========== Password Reset Methods ==========

  /// Request password reset email
  ///
  /// Calls backend API to generate a Firebase password reset link
  /// and send it via email. Always returns success to prevent email
  /// enumeration attacks.
  ///
  /// Returns true if the request was processed (regardless of whether
  /// the email exists in the system).
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiBaseUrl/api/v1/portal/auth/password-reset/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      _isLoading = false;

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _error =
            data['error'] as String? ??
            'Too many requests. Please try again later.';
        notifyListeners();
        return false;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _error =
            data['error'] as String? ?? 'Failed to send password reset email';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Password reset request error: $e');
      _error = 'Failed to connect to server. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify a password reset code is valid
  ///
  /// Calls Firebase Auth to verify the reset code and returns the
  /// associated email address if valid, or null if invalid/expired.
  Future<String?> verifyPasswordResetCode(String code) async {
    try {
      final email = await _auth.verifyPasswordResetCode(code);
      return email;
    } on FirebaseAuthException catch (e) {
      debugPrint('Verify password reset code error: ${e.code} - ${e.message}');
      _error = _mapPasswordResetError(e.code);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Verify password reset code error: $e');
      _error = 'Failed to verify reset code';
      notifyListeners();
      return null;
    }
  }

  /// Complete password reset with new password
  ///
  /// Uses Firebase Auth to confirm the password reset with the provided
  /// code and new password.
  ///
  /// Returns true if password was successfully reset.
  Future<bool> confirmPasswordReset(String code, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Confirm password reset error: ${e.code} - ${e.message}');
      _error = _mapPasswordResetError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Confirm password reset error: $e');
      _error = 'Failed to reset password. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Map password reset error codes to user-friendly messages
  String _mapPasswordResetError(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'This password reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This password reset link is invalid or has already been used.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this reset link.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      default:
        return 'An error occurred. Please try again.';
    }
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
