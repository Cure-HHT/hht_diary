/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

/// Interface for storing and retrieving authentication tokens.
///
/// Implementations may use secure storage, memory-only storage,
/// or platform-specific secure storage mechanisms.
abstract class TokenStorage {
  /// Stores the authentication token securely.
  Future<void> saveToken(String token);

  /// Retrieves the stored authentication token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getToken();

  /// Deletes the stored authentication token.
  Future<void> deleteToken();

  /// Checks if a token is currently stored.
  Future<bool> hasToken();
}
