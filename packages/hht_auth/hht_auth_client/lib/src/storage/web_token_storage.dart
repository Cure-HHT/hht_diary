/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00080: Web Session Management Implementation
///
/// In-memory token storage for Flutter Web.
///
/// This implementation stores authentication tokens in memory only,
/// ensuring tokens are not persisted to browser storage for security.
/// Tokens are lost when the browser tab is closed or refreshed.

import 'package:hht_auth_core/hht_auth_core.dart';

/// In-memory token storage implementation for Flutter Web.
///
/// Stores authentication tokens in memory only (no localStorage/sessionStorage).
/// This ensures tokens do not persist beyond the browser session.
class WebTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async {
    return _token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<bool> hasToken() async {
    return _token != null;
  }
}
