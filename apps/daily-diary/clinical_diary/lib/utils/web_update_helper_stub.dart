// Stub implementation for non-web platforms
//
// This file is used when the app is running on native platforms.
// The actual web implementation is in web_update_helper_web.dart.

/// No-op on non-web platforms
// Implements: DIARY-BASE-portal-stale-client-reload
Future<void> clearCacheAndReload() async {
  // On non-web platforms, this is a no-op
  // Native app updates are handled differently (stores, etc.)
}

/// Always false on non-web platforms
bool get isWebPlatform => false;
