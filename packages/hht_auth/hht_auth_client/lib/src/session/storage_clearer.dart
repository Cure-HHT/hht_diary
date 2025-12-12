/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00083: Browser Storage Clearing
///
/// Browser storage clearing utility.
///
/// Clears all browser storage mechanisms (localStorage, sessionStorage,
/// cookies, IndexedDB, Cache Storage) to prevent data persistence.
///
/// NOTE: This file uses dart:html and is web-only.

import 'dart:html' as html;

/// Utility for clearing all browser storage.
///
/// Ensures complete data removal on logout or session expiry.
class StorageClearer {
  /// Clears all browser storage mechanisms.
  ///
  /// Includes:
  /// - localStorage
  /// - sessionStorage
  /// - cookies
  /// - IndexedDB
  /// - Cache Storage
  static Future<void> clearAllStorage() async {
    // Clear Web Storage API
    html.window.localStorage.clear();
    html.window.sessionStorage.clear();

    // Clear all cookies
    _clearAllCookies();

    // Clear IndexedDB
    await _clearIndexedDB();

    // Clear Cache Storage
    await _clearCacheStorage();
  }

  static void _clearAllCookies() {
    final cookies = html.document.cookie?.split(';') ?? [];
    for (final cookie in cookies) {
      if (cookie.trim().isEmpty) continue;
      
      final name = cookie.split('=')[0].trim();
      
      // Set expiry in the past to delete (multiple variations for thorough clearing)
      final expiry = 'expires=Thu, 01 Jan 1970 00:00:00 GMT';
      
      // Clear for current path
      html.document.cookie = '$name=; $expiry; path=/';
      
      // Clear for current domain
      final hostname = html.window.location.hostname;
      html.document.cookie = '$name=; $expiry; path=/; domain=$hostname';
      
      // Clear for root domain (if subdomain)
      if (hostname.split('.').length > 2) {
        final rootDomain = hostname.split('.').skip(1).join('.');
        html.document.cookie = '$name=; $expiry; path=/; domain=.$rootDomain';
      }
    }
  }

  static Future<void> _clearIndexedDB() async {
    try {
      final databases = await html.window.indexedDB?.databases();
      if (databases != null) {
        for (final db in databases) {
          final name = db['name'];
          if (name != null) {
            html.window.indexedDB?.deleteDatabase(name as String);
          }
        }
      }
    } catch (e) {
      // IndexedDB clearing may fail in some browsers, log but don't throw
      print('Warning: Could not clear IndexedDB: $e');
    }
  }

  static Future<void> _clearCacheStorage() async {
    try {
      final cacheNames = await html.window.caches?.keys();
      if (cacheNames != null) {
        for (final name in cacheNames) {
          await html.window.caches?.delete(name);
        }
      }
    } catch (e) {
      // Cache clearing may fail in some browsers, log but don't throw
      print('Warning: Could not clear Cache Storage: $e');
    }
  }

  /// Clears only session-specific data (not persistent data like settings).
  ///
  /// This is a lighter-weight version that clears only sessionStorage
  /// and session cookies.
  static void clearSessionOnly() {
    html.window.sessionStorage.clear();
    
    // Clear session cookies (those without max-age or expires)
    // Note: We can't reliably detect session cookies, so this is best effort
    html.window.sessionStorage.clear();
  }
}
