import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Simple anonymous user identity using local storage.
/// Users get a stable device-local ID for contributions and flashcard tracking.
/// Can be upgraded to Firebase Auth later for cross-device sync.
class UserService {
  static const _userIdKey = 'hilagaynon_user_id';
  static const _displayNameKey = 'hilagaynon_display_name';
  static const _uuid = Uuid();

  String? _cachedUserId;
  String? _cachedDisplayName;

  /// Get or create a persistent anonymous user ID.
  Future<String> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;

    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString(_userIdKey);
    if (userId == null) {
      userId = _uuid.v4();
      await prefs.setString(_userIdKey, userId);
    }
    _cachedUserId = userId;
    return userId;
  }

  /// Get the user's display name (optional).
  Future<String?> getDisplayName() async {
    if (_cachedDisplayName != null) return _cachedDisplayName;

    final prefs = await SharedPreferences.getInstance();
    _cachedDisplayName = prefs.getString(_displayNameKey);
    return _cachedDisplayName;
  }

  /// Set the user's display name.
  Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, name.trim());
    _cachedDisplayName = name.trim();
  }
}
