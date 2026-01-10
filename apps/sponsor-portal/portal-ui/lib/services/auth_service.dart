// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00031: Identity Platform Integration
//   REQ-d00032: Role-Based Access Control Implementation
//
// Portal authentication service using Firebase Auth (Identity Platform)

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
class PortalUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String status;
  final List<Map<String, dynamic>> sites;

  PortalUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    this.sites = const [],
  });

  factory PortalUser.fromJson(Map<String, dynamic> json) {
    return PortalUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String),
      status: json['status'] as String,
      sites: (json['sites'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          [],
    );
  }

  bool canAccessSite(String siteId) {
    // Admins, Sponsors, Auditors, and Analysts can access all sites
    if (role != UserRole.investigator) {
      return true;
    }
    // Investigators can only access assigned sites
    return sites.any((s) => s['site_id'] == siteId);
  }
}

/// Authentication service using Firebase Auth and portal API
class AuthService extends ChangeNotifier {
  /// Create AuthService with optional dependencies for testing
  AuthService({
    FirebaseAuth? firebaseAuth,
    http.Client? httpClient,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client() {
    _init();
  }

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  PortalUser? _currentUser;
  bool _isLoading = false;
  String? _error;

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

    // Production URL (set via environment)
    return 'https://portal-api.example.com';
  }

  PortalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;

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
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Sign in with Firebase Auth
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch portal user info
      final success = await _fetchPortalUser();
      if (!success) {
        // User authenticated but not authorized for portal
        await _auth.signOut();
        return false;
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      debugPrint('Firebase auth error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _error = 'Authentication failed. Please try again.';
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Fetch portal user info from server
  Future<bool> _fetchPortalUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Get ID token for API authentication
      final idToken = await user.getIdToken();

      // Call portal API to get user info
      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl/api/v1/portal/me'),
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

  /// Get fresh ID token for API calls
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Check if user has specific role
  bool hasRole(UserRole role) {
    return _currentUser?.role == role;
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
