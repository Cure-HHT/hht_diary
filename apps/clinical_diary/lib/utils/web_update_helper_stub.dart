// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

// Stub implementation for non-web platforms
//
// This file is used when the app is running on native platforms.
// The actual web implementation is in web_update_helper_web.dart.

/// No-op on non-web platforms
Future<void> clearCacheAndReload() async {
  // On non-web platforms, this is a no-op
  // Native app updates are handled differently (stores, etc.)
}

/// Always false on non-web platforms
bool get isWebPlatform => false;
