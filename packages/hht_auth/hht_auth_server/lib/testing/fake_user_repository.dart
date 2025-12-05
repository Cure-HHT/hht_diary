/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00081: User Document Schema - Fake repository for testing
///
/// In-memory fake implementation of UserRepository for testing.

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_server/src/repositories/user_repository.dart';

/// Fake in-memory UserRepository for testing.
class FakeUserRepository implements UserRepository {
  final Map<String, WebUser> _usersById = {};
  final Map<String, WebUser> _usersByUsernameAndSponsor = {};

  @override
  Future<void> createUser(WebUser user) async {
    final key = '${user.username}:${user.sponsorId}';

    if (_usersByUsernameAndSponsor.containsKey(key)) {
      throw AuthException('Username already exists for this sponsor');
    }

    _usersById[user.id] = user;
    _usersByUsernameAndSponsor[key] = user;
  }

  @override
  Future<WebUser?> getUserById(String userId) async {
    return _usersById[userId];
  }

  @override
  Future<WebUser?> getUserByUsername(String username, String sponsorId) async {
    final key = '$username:$sponsorId';
    return _usersByUsernameAndSponsor[key];
  }

  @override
  Future<void> updateUser(WebUser user) async {
    if (!_usersById.containsKey(user.id)) {
      throw AuthException('User not found');
    }

    final key = '${user.username}:${user.sponsorId}';
    _usersById[user.id] = user;
    _usersByUsernameAndSponsor[key] = user;
  }

  @override
  Future<WebUser> incrementFailedAttempts(String userId) async {
    final user = _usersById[userId];
    if (user == null) {
      throw AuthException('User not found');
    }

    final updated = user.copyWith(
      failedAttempts: user.failedAttempts + 1,
    );

    await updateUser(updated);
    return updated;
  }

  @override
  Future<WebUser> resetFailedAttempts(String userId) async {
    final user = _usersById[userId];
    if (user == null) {
      throw AuthException('User not found');
    }

    final updated = user.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      lastLoginAt: DateTime.now(),
    );

    await updateUser(updated);
    return updated;
  }

  @override
  Future<WebUser> lockAccount(String userId, DateTime lockedUntil) async {
    final user = _usersById[userId];
    if (user == null) {
      throw AuthException('User not found');
    }

    final updated = user.copyWith(
      lockedUntil: lockedUntil,
    );

    await updateUser(updated);
    return updated;
  }

  /// Clears all stored users (for test cleanup).
  void clear() {
    _usersById.clear();
    _usersByUsernameAndSponsor.clear();
  }
}
