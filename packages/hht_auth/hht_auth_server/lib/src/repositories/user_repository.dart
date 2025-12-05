/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00081: User Document Schema - Repository interface for user data access
///
/// Abstract repository interface for user data access.

import 'package:hht_auth_core/hht_auth_core.dart';

/// Repository interface for WebUser persistence operations.
abstract class UserRepository {
  /// Creates a new user in the database.
  ///
  /// Throws [AuthException] if username already exists for the sponsor.
  Future<void> createUser(WebUser user);

  /// Retrieves a user by username and sponsor ID.
  ///
  /// Returns null if user not found.
  Future<WebUser?> getUserByUsername(String username, String sponsorId);

  /// Retrieves a user by user ID.
  ///
  /// Returns null if user not found.
  Future<WebUser?> getUserById(String userId);

  /// Updates an existing user.
  ///
  /// Throws [AuthException] if user not found.
  Future<void> updateUser(WebUser user);

  /// Increments the failed login attempts counter.
  ///
  /// Returns the updated user.
  Future<WebUser> incrementFailedAttempts(String userId);

  /// Resets the failed login attempts counter and clears lock.
  ///
  /// Returns the updated user.
  Future<WebUser> resetFailedAttempts(String userId);

  /// Locks a user account until the specified time.
  ///
  /// Returns the updated user.
  Future<WebUser> lockAccount(String userId, DateTime lockedUntil);
}
