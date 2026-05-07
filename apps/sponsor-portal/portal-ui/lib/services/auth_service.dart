// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-p01044-C: Sponsors SHALL be able to configure the inactivity timeout
//   REQ-d00080-A: client-side session management with configurable inactivity timeout
//   REQ-d00167: Identity Platform binding set only at activation; uid_not_bound 401 is the auth-miss envelope
//
// Portal authentication service using Firebase Auth (Identity Platform)
// Supports both TOTP (for Developer Admin) and Email OTP (for other users)

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../flavors.dart';
import 'firebase_emulator_helper.dart';

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

/// Outcome of [AuthService._fetchPortalUser].
///
/// CUR-1157: split the fetch outcomes so the initial-restore path can tell
/// "user is not authorized for the portal" (403 — redirect to login) apart
/// from "we couldn't reach the API" (5xx / network — retry, do not log the
/// user out of a still-valid Firebase session).
enum _PortalFetchResult {
  /// HTTP 200 — `_currentUser` populated.
  success,

  /// HTTP 403 — Firebase user is not authorized for portal access.
  unauthorized,

  /// HTTP 5xx, network error, or any other non-deterministic failure.
  transientFailure,
}

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
    Future<void> Function()? forceClearFirebaseAuthDb,
    bool isPageRefresh = false,
    // Implements: REQ-d00167-B — flavor controls the uid_not_bound error banner
    Flavor? flavor,
  }) : _sponsorId = sponsorId,
       _auth = firebaseAuth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _inactivityTimeout = inactivityTimeout,
       _enableInactivityTimer = enableInactivityTimer,
       _isPageRefresh = isPageRefresh,
       // REQ-d00083-A..E, REQ-p01044-J..M: default is a no-op; main.dart injects
       // the real browser implementation on web.
       _clearStorage = clearStorage ?? _noopStorage,
       // CUR-1280 auto-recovery: injected by main.dart on web. Default
       // no-op for unit tests / non-web platforms — the recovery path
       // is local-flavor only anyway.
       _forceClearFirebaseAuthDb = forceClearFirebaseAuthDb ?? _noopStorage,
       _flavor = flavor ?? F.appFlavor ?? Flavor.prod {
    _init();
  }

  final String _sponsorId;
  final bool _enableInactivityTimer;
  // Implements: REQ-d00167-B — controls uid_not_bound error message copy
  final Flavor _flavor;

  /// CUR-1118: true when this page load is a same-tab refresh (F5/Cmd+R).
  /// When false (fresh tab / post-close), stale Firebase sessions are cleared
  /// inside _init() after Firebase has finished restoring from IndexedDB.
  final bool _isPageRefresh;
  // REQ-d00083-A..E, REQ-p01044-J..M: injectable for testing, web impl by default
  final Future<void> Function() _clearStorage;
  // CUR-1280: injected by main.dart from BrowserStorageService.
  // Default no-op for unit tests and non-web platforms.
  final Future<void> Function() _forceClearFirebaseAuthDb;
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

  /// CUR-1280: how long to wait for Firebase to confirm the restored
  /// token is still valid before falling back to signOut.
  /// Firebase's own RPC timeout is ~10s; 5s gives a margin while not
  /// stalling the listener chain on offline networks.
  static const Duration _restoredTokenRefreshTimeout = Duration(seconds: 5);

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

  /// CUR-1280: serialized authStateChanges subscription.
  ///
  /// `late final` so we can `await _firebaseSub.cancel()` in [dispose] before
  /// any other state is torn down — preventing a chained handler from firing
  /// against a half-disposed instance.
  late final StreamSubscription<User?> _firebaseSub;

  /// CUR-1280: chained tail of in-flight handler invocations. Each
  /// `authStateChanges` event appends `_handleAuthEvent(user)` to this Future
  /// SYNCHRONOUSLY (before any await), guaranteeing handler N completes
  /// before handler N+1 begins, even though `Stream.listen`'s default
  /// behavior on a broadcast stream does not pause for async callbacks.
  Future<void>? _pendingHandler;

  /// CUR-1280: re-entry guard. Hot reload re-runs the constructor against the
  /// same FirebaseAuth instance, attaching a second listener and producing
  /// duplicate handler invocations per event. The flag scopes to the
  /// AuthService instance — a fresh AuthService still re-listens, which is
  /// the correct behavior under tests and real navigation.
  bool _didInit = false;

  /// CUR-1280: dispose flag. Cancelling the StreamSubscription does not
  /// prevent already-queued chain links from running — `_pendingHandler`'s
  /// `.then(...)` microtask is independent of the subscription. So a chain
  /// link that was scheduled before dispose may run after dispose and try
  /// to `notifyListeners()` on a torn-down ChangeNotifier. Bail in that
  /// case at the top of `_handleAuthEvent`.
  bool _disposed = false;

  /// Initialize auth state listener.
  ///
  /// IMPLEMENTS REQUIREMENTS:
  ///   REQ-d00080-A: client-side session management — the listener is the
  ///                 surface where Firebase restores collide with explicit
  ///                 signIn / signOut and must serialize.
  ///   REQ-p01044-A: configured-period inactivity termination — concurrent
  ///                 handler runs corrupt the inactivity-timer state.
  ///   REQ-p00010:   FDA 21 CFR Part 11 — interleaved writes to
  ///                 _currentUser / _sessionUid leave audit-visible
  ///                 intermediate states.
  ///   REQ-CAL-p00046: Session Management.
  void _init() {
    if (_didInit) return;
    _didInit = true;
    _firebaseSub = _auth.authStateChanges().listen((User? user) async {
      // Synchronously chain — assignment happens BEFORE any await, so the
      // next listener invocation observes the new tail. Without this, two
      // events firing back-to-back would interleave their async bodies.
      //
      // CUR-1280 (Copilot review): swallow errors at the chain tail so a
      // throwing _handleAuthEvent (e.g. signOut() or storage clearer
      // failure) does not poison every subsequent event with a permanently
      // failed Future. _handleAuthEvent already logs its own failures; the
      // catchError here is purely a chain-continuity guard.
      _pendingHandler = (_pendingHandler ?? Future.value())
          .then((_) => _handleAuthEvent(user))
          .catchError((Object e, StackTrace st) {
            debugPrint(
              '[AuthService] handler error swallowed for chain '
              'continuity: $e\n$st',
            );
          });
      await _pendingHandler;
    });
  }

  /// CUR-1280: serialized handler body. See [_init] for the chain mechanics.
  ///
  /// IMPLEMENTS REQUIREMENTS:
  ///   REQ-d00080-A, REQ-p01044-A, REQ-p00010, REQ-CAL-p00046
  Future<void> _handleAuthEvent(User? user) async {
    // CUR-1280: a chain link queued before dispose can still fire after.
    // Bail before mutating any state or calling notifyListeners().
    if (_disposed) return;

    // CUR-1280 (issue 11): a fresh sign-in session begins when we see the
    // first event for a non-null user with no _sessionUid yet. Reset the
    // initial-fetch retry counter so a previous failed-out session does
    // not lock out the new one.
    if (user != null && _sessionUid == null) {
      _initialFetchRetryCount = 0;
    }

    // CUR-1118: If this is a fresh tab (not a page refresh) and Firebase
    // restored a session from IndexedDB, that session may be stale.
    // We do this HERE (not in main.dart) because Firebase needs time to
    // restore the session from IndexedDB before we can decide.
    // The !_isInitialized guard ensures this only fires on the FIRST
    // authStateChanges event (initial restoration), not on subsequent
    // events from explicit signIn() calls.
    // The _clearStorage != _noopStorage guard ensures this only runs in
    // the browser (where main.dart injects BrowserStorageService), not in
    // unit tests which use the default no-op.
    //
    // CUR-1280 (issue 6, subsumes issue 9): the previous implementation
    // signed out UNCONDITIONALLY. Combined with the IndexedDB blocked-delete
    // bug (now fixed in Task 1.4), that produced the "every fresh tab kicks
    // me out" UX. The correct gate is "is the restored token actually
    // valid?" — forceRefresh roundtrips to Firebase (or the emulator) and
    // is the authoritative test. A successful refresh => the session is
    // still the user's and must be preserved (REQ-d00080-L, REQ-p01044-O).
    // A throw / timeout => the cached session can't be revived, fall back
    // to the original CUR-1118 teardown.
    //
    // This subsumes plan-issue 9 ("forceRefresh on first call after
    // restore") by performing the refresh exactly when its result is
    // needed.
    //
    // The 5s timeout prevents the serialized-listener chain (Task 2.4)
    // from stalling indefinitely when the network is offline; if Firebase
    // can't be reached in 5s, default to signOut (better to log out than
    // leave the user in limbo).
    //
    // IMPLEMENTS REQUIREMENTS:
    //   REQ-d00080-A: client-side session management — gate restored
    //                 sessions on token validity, not on tab freshness.
    //   REQ-d00080-L: switching tabs MUST NOT trigger logout — opening
    //                 a second tab while the first is logged in adopts
    //                 the same valid session in the new tab.
    //   REQ-p01044-D: terminate session on tab/window close — NOT on
    //                 fresh-tab open of an already-authenticated session.
    //   REQ-p01044-O: synchronize session timeout across multiple tabs
    //                 for the same user.
    if (user != null &&
        !_isPageRefresh &&
        !_isInitialized &&
        _sessionUid == null &&
        _clearStorage != _noopStorage) {
      try {
        // CUR-1280: re-bind before forceRefresh — without it the
        // refresh hits production with the placeholder api-key and
        // throws, causing every fresh-tab open to signOut even valid
        // sessions. flutterfire #9528.
        await ensureAuthEmulatorBound();
        await user.getIdToken(true).timeout(_restoredTokenRefreshTimeout);
        // Token still valid — fall through. The branches below
        // (cross-tab collision, skip-predicate, restore-from-refresh)
        // handle adopting the session correctly.
      } catch (e) {
        debugPrint(
          '[AUTH] Fresh-tab token refresh failed; auto-recovering '
          '(forceClearFirebaseAuthDb + signOut): $e',
        );
        // CUR-1280 auto-recovery: the cached refresh token can't be
        // exchanged for a new ID token. On local-flavor this is the
        // signature of a stack restart (emulator wiped its user
        // database, our cached token references a UID that no longer
        // exists). Wipe firebaseLocalStorageDb so the next page load
        // starts fresh — otherwise the user is stuck in a loop where
        // every reload restores the same stale token. No-op outside
        // local-flavor.
        await _forceClearFirebaseAuthDb();
        await signOut();
        return;
      }
    }

    if (user != null && _sessionUid != null && user.uid != _sessionUid) {
      // CUR-982: A different user signed in from another tab, overwriting
      // this tab's Firebase auth state via shared localStorage. Sign out
      // to prevent role-escalation display mismatch (FDA 21 CFR Part 11).
      // CUR-1280: under serialization, the read-modify-write on
      // _sessionUid is now race-free.
      debugPrint(
        '[AUTH] Cross-tab session collision detected: '
        'expected $_sessionUid, got ${user.uid}. Signing out.',
      );
      await signOut();
    } else if (user != null && _sessionUid == user.uid) {
      // CUR-1280 (issue 10): skip-predicate — Amendment 1.
      //
      // The caller that set _sessionUid (signIn / completeMfaSignIn) is
      // responsible for fetching /portal/me. Skip here to avoid the
      // duplicate GET that the previous unserialized listener produced.
      // Predicate is `_sessionUid == user.uid` (NOT `_currentUser != null`)
      // because `_currentUser` is only set after the caller's awaited
      // fetch resolves — racing on it dropped legitimate listener
      // fetches when the network was slow.
      //
      // Only flip _isInitialized once the caller's fetch has populated
      // _currentUser. Flipping it earlier with _currentUser still null
      // makes dashboards observe (isInitialized=true && isAuthenticated=false)
      // and redirect to /login — undoing the in-flight signIn(). This is
      // exactly the symptom CUR-1157 added the retry-loop guard to
      // prevent.
      if (!_isInitialized && _currentUser != null) {
        _isInitialized = true;
        notifyListeners();
      }
    } else if (user != null) {
      // Same user signed in or session restored from a path that did not
      // set _sessionUid first (e.g. browser refresh restoring a Firebase
      // session). CUR-1118: Track the UID so cross-tab collision
      // detection (CUR-982) works after a page refresh, not only after
      // an explicit signIn().
      _sessionUid = user.uid;
      final result = await _fetchPortalUser();
      // CUR-1157: do NOT unconditionally flip _isInitialized after a
      // transient API failure on the initial restore — doing so leaves
      // dashboards in (isAuthenticated=false, isInitialized=true) and
      // they redirect to /login, which the user perceives as "refresh
      // logged me out" even though the Firebase session is valid.
      if (result == _PortalFetchResult.transientFailure && !_isInitialized) {
        _scheduleInitialFetchRetry();
        return;
      }
      // CUR-1280 auto-recovery: a 403 from /portal/me on the
      // restore-from-refresh path means the server rejected the
      // restored Firebase session — typically "Email already linked
      // to another account" because portal_users.firebase_uid points
      // at a UID from a previous emulator instance that no longer
      // exists. The previous behavior just flipped _isInitialized
      // and let the dashboard redirect to /login, but the stale row
      // in firebaseLocalStorageDb survived and Firebase auto-restored
      // it again on the next page load — same 403, same /login loop.
      // Clear the DB and signOut so the next load starts fresh.
      // No-op outside local-flavor.
      if (result == _PortalFetchResult.unauthorized) {
        debugPrint(
          '[AUTH] Restored session was rejected by /portal/me '
          '(403); auto-recovering on local-flavor.',
        );
        await _forceClearFirebaseAuthDb();
        await signOut();
        return;
      }
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
      // CUR-1280: re-bind emulator on local-flavor (workaround for
      // flutterfire #9528). No-op in deployed flavors.
      await ensureAuthEmulatorBound();
      // Sign in with Firebase Auth
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // CUR-982: Track this tab's Firebase UID to detect cross-tab collisions
      _sessionUid = _auth.currentUser?.uid;

      // Fetch portal user info
      final result = await _fetchPortalUser();
      if (result != _PortalFetchResult.success) {
        // User authenticated but not authorized (or API unreachable) — fail
        // the login so the user can retry rather than landing on a half-
        // initialized dashboard.
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

      // CUR-1280: re-bind emulator on local-flavor.
      await ensureAuthEmulatorBound();
      // Resolve the MFA challenge
      await _mfaResolver!.resolveSignIn(assertion);

      // Clear MFA state
      _mfaRequired = false;
      _mfaResolver = null;

      // Fetch portal user info
      final result = await _fetchPortalUser();
      if (result != _PortalFetchResult.success) {
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
    // CUR-1280: mark disposed FIRST so any chain link already queued
    // after this microtask boundary bails out at the top of
    // `_handleAuthEvent` instead of mutating state / calling
    // notifyListeners on a disposed ChangeNotifier.
    _disposed = true;
    // Cancel the Firebase subscription so no NEW events are ever
    // chained. `late final` may not be assigned if the constructor
    // failed before _init() ran — tolerate that.
    try {
      _firebaseSub.cancel();
    } catch (_) {
      // _firebaseSub never assigned.
    }
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer?.cancel();
    _warningTimer = null;
    _initialFetchRetryTimer?.cancel();
    _initialFetchRetryTimer = null;
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
      // CUR-1280: re-bind emulator before getIdToken (flutterfire #9528).
      await ensureAuthEmulatorBound();
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
      // CUR-1280: re-bind emulator before getIdToken (flutterfire #9528).
      await ensureAuthEmulatorBound();
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
    // CUR-1157: drop any pending initial-fetch retry — the user is leaving
    // anyway, and we don't want a delayed retry to flip _isInitialized while
    // signOut is still tearing down.
    _initialFetchRetryTimer?.cancel();
    _initialFetchRetryTimer = null;
    _initialFetchRetryCount = 0;
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

  /// Fetch portal user info from server.
  ///
  /// [selectedRole] - Optionally specify which role to activate.
  ///
  /// Returns a [_PortalFetchResult] so callers can distinguish a real
  /// authorization rejection (403) from a transient connectivity / 5xx
  /// failure (CUR-1157).
  Future<_PortalFetchResult> _fetchPortalUser([String? selectedRole]) async {
    // CUR-1280: bail out before any state write / notifyListeners() if the
    // service has already been torn down. Callers (signIn, completeMfaSignIn,
    // switchRole, the retry timer) may invoke us from outside the
    // _handleAuthEvent serialized chain, so the top-of-_handleAuthEvent
    // _disposed guard does not cover this path.
    if (_disposed) return _PortalFetchResult.transientFailure;
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _PortalFetchResult.transientFailure;
      }

      // CUR-1280: re-bind emulator on local-flavor before getIdToken,
      // which is a Firebase Auth network call. Refresh path enters
      // _fetchPortalUser without going through signIn first, so the
      // signIn-side bind isn't enough — every getIdToken call needs
      // its own re-bind. flutterfire #9528.
      await ensureAuthEmulatorBound();
      if (_disposed) return _PortalFetchResult.transientFailure;
      // Get ID token for API authentication
      final idToken = await user.getIdToken();
      if (_disposed) return _PortalFetchResult.transientFailure;

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
      if (_disposed) return _PortalFetchResult.transientFailure;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = PortalUser.fromJson(data);
        // Fetch sponsor role mappings if not loaded yet
        if (_sponsorRoleNames.isEmpty) {
          await _fetchSponsorRoleMappings(idToken!);
          if (_disposed) return _PortalFetchResult.transientFailure;
        }
        _isInitialized = true;
        notifyListeners();
        // REQ-p01044-C: apply sponsor-configurable inactivity timeout
        await _fetchSponsorTimeout();
        if (_disposed) return _PortalFetchResult.transientFailure;
        return _PortalFetchResult.success;
      } else if (response.statusCode == 401) {
        // Implements: REQ-d00167-B — uid_not_bound 401 envelope: Firebase UID
        // is not bound to any portal_users row. On Flavor.local this means
        // the emulator was restarted; surface the rebind hint. Other flavors
        // get a generic administrator-contact message.
        //
        // Reverse proxies / gateways may return non-JSON 401 bodies (HTML
        // error pages). Guard the decode so a malformed body doesn't fall
        // through to the generic exception path.
        Map<String, dynamic> body = const {};
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) body = decoded;
        } catch (_) {
          // Non-JSON body — treat as generic 401, no uid_not_bound code.
        }
        final errCode = body['code'] as String?;
        if (errCode == 'uid_not_bound') {
          _error = (_flavor == Flavor.local)
              ? 'Your portal account isn\'t bound to this Identity Platform '
                    'user. If you just restarted the emulator, run '
                    '`./local-stack rebind` and reload.'
              : 'Account not found — contact your administrator.';
        } else {
          _error = body['error'] as String? ?? 'Authentication failed.';
        }
        notifyListeners();
        return _PortalFetchResult.unauthorized;
      } else if (response.statusCode == 403) {
        // User not authorized for portal access
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _error = data['error'] as String? ?? 'Not authorized for portal access';
        // Check for pending activation
        if (data['status'] == 'pending') {
          _error = 'pending_activation';
        }
        return _PortalFetchResult.unauthorized;
      } else {
        _error = 'Failed to fetch user information';
        return _PortalFetchResult.transientFailure;
      }
    } catch (e) {
      debugPrint('Error fetching portal user: $e');
      _error = 'Failed to connect to server';
      return _PortalFetchResult.transientFailure;
    }
  }

  /// CUR-1157: how many times to retry the initial `/portal/me` fetch
  /// before giving up and letting dashboards redirect to /login.
  static const int _initialFetchMaxRetries = 3;

  /// CUR-1157: backoff between initial-fetch retries.
  static const Duration _initialFetchRetryDelay = Duration(seconds: 2);

  Timer? _initialFetchRetryTimer;
  int _initialFetchRetryCount = 0;

  /// CUR-1157: Schedule another `_fetchPortalUser` attempt after a transient
  /// failure during the initial session restore. While retries are pending,
  /// `_isInitialized` stays false so dashboards keep showing the spinner
  /// instead of bouncing the user to /login despite a valid Firebase session.
  void _scheduleInitialFetchRetry() {
    _initialFetchRetryTimer?.cancel();
    _initialFetchRetryTimer = Timer(_initialFetchRetryDelay, () async {
      // CUR-1280: dispose() cancels the timer, but a callback already
      // queued on the event loop may still run. Bail before reading or
      // mutating any state.
      if (_disposed) return;
      _initialFetchRetryTimer = null;
      // If the user signed out, the auth state changed, or we already
      // succeeded via another path, drop the retry.
      if (_isInitialized || _auth.currentUser == null) return;

      _initialFetchRetryCount++;
      final result = await _fetchPortalUser();
      if (result == _PortalFetchResult.success) return;

      if (result == _PortalFetchResult.transientFailure &&
          _initialFetchRetryCount < _initialFetchMaxRetries) {
        _scheduleInitialFetchRetry();
        return;
      }

      // Out of retries (or 403). Let the dashboard route based on the
      // current state — currentUser is still null, so it will redirect to
      // /login, which is the correct fallback after we've genuinely failed
      // to load portal info.
      _isInitialized = true;
      notifyListeners();
    });
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
      // CUR-1280: updateInactivityTimeout below transitively notifies
      // listeners via resetInactivityTimer; do not touch state if disposed.
      if (_disposed) return;

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
    final result = await _fetchPortalUser(newRole.displayName);
    return result == _PortalFetchResult.success;
  }

  /// Check if user needs to select a role (has multiple roles and none selected)
  bool get needsRoleSelection =>
      _currentUser != null && _currentUser!.hasMultipleRoles;

  /// Get fresh ID token for API calls.
  ///
  /// Used by [ApiClient] for every dashboard backend call, which means
  /// EVERY portal API request flows through this method. The
  /// [ensureAuthEmulatorBound] call is critical here on local-flavor:
  /// without it, the first API call after a page load can hit
  /// production Firebase, get api-key-not-valid, and the dashboard
  /// silently fails. flutterfire #9528.
  Future<String?> getIdToken() async {
    try {
      // CUR-1280: re-bind emulator on local-flavor.
      await ensureAuthEmulatorBound();
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
      // CUR-1280: re-bind emulator on local-flavor.
      await ensureAuthEmulatorBound();
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
      // CUR-1280: re-bind emulator on local-flavor.
      await ensureAuthEmulatorBound();
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
