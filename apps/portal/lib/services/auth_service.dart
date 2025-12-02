// // IMPLEMENTS REQUIREMENTS:
// //   REQ-p00024: Portal User Roles and Permissions
// //   REQ-p00014: Authentication and Authorization
//
// import 'package:flutter/foundation.dart';
// import 'database_service.dart';
// import '../config/database_config.dart';
//
// enum UserRole {
//   admin,
//   investigator,
//   auditor,
// }
//
// class PortalUser {
//   final String id;
//   final String email;
//   final UserRole role;
//   final String? name;
//   final List<String> assignedSites;
//
//   PortalUser({
//     required this.id,
//     required this.email,
//     required this.role,
//     this.name,
//     this.assignedSites = const [],
//   });
//
//   factory PortalUser.fromMap(Map<String, dynamic> map) {
//     return PortalUser(
//       id: map['id'] as String,
//       email: map['email'] as String,
//       role: UserRole.values.firstWhere(
//         (r) => r.name == map['role'],
//         orElse: () => UserRole.investigator,
//       ),
//       name: map['name'] as String?,
//       assignedSites: (map['assigned_sites'] as List<dynamic>?)
//               ?.map((e) => e.toString())
//               .toList() ??
//           [],
//     );
//   }
// }
//
// class AuthService extends ChangeNotifier {
//   final DatabaseService _db = DatabaseConfig.getDatabaseService();
//   PortalUser? _currentUser;
//   bool _isLoading = false;
//
//   PortalUser? get currentUser => _currentUser;
//   bool get isLoading => _isLoading;
//   bool get isAuthenticated => _currentUser != null;
//
//   Future<bool> signIn(String email, String password) async {
//     _isLoading = true;
//     notifyListeners();
//
//     try {
//       final userData = await _db.signInWithEmail(email, password);
//       if (userData != null) {
//         _currentUser = PortalUser.fromMap(userData);
//         notifyListeners();
//         return true;
//       }
//       return false;
//     } catch (e) {
//       debugPrint('Sign in error: $e');
//       return false;
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   Future<void> signOut() async {
//     await _db.signOut();
//     _currentUser = null;
//     notifyListeners();
//   }
//
//   bool hasRole(UserRole role) {
//     return _currentUser?.role == role;
//   }
//
//   bool canAccessSite(String siteId) {
//     if (_currentUser == null) return false;
//
//     // Admins and Auditors can access all sites
//     if (_currentUser!.role == UserRole.admin ||
//         _currentUser!.role == UserRole.auditor) {
//       return true;
//     }
//
//     // Investigators can only access assigned sites
//     return _currentUser!.assignedSites.contains(siteId);
//   }
// }
