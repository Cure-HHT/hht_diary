// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00014: Authentication and Authorization

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

enum UserRole {
  admin,
  investigator,
  auditor,
}

class PortalUser {
  final String id;
  final String email;
  final UserRole role;
  final String? name;
  final List<String> assignedSites;

  PortalUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.assignedSites = const [],
  });

  factory PortalUser.fromMap(Map<String, dynamic> map) {
    return PortalUser(
      id: map['id'] as String,
      email: map['email'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.investigator,
      ),
      name: map['name'] as String?,
      assignedSites: (map['assigned_sites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;
  PortalUser? _currentUser;
  bool _isLoading = false;

  PortalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _loadUserProfile(data.session!.user.id);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('portal_users')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = PortalUser.fromMap(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  bool canAccessSite(String siteId) {
    if (_currentUser == null) return false;

    // Admins and Auditors can access all sites
    if (_currentUser!.role == UserRole.admin ||
        _currentUser!.role == UserRole.auditor) {
      return true;
    }

    // Investigators can only access assigned sites
    return _currentUser!.assignedSites.contains(siteId);
  }
}
