// Conditional import to handle web-specific functionality
// ignore: uri_does_not_exist
import 'package:clinical_diary/utils/web_update_helper_stub.dart'
    if (dart.library.js_interop) 'package:clinical_diary/utils/web_update_helper_web.dart'
    as impl;

/// Clear browser cache and reload the page
///
/// On web, this will:
/// 1. Unregister all service workers
/// 2. Clear all CacheStorage caches
/// 3. Force a hard reload of the page
///
/// On other platforms, this is a no-op.
// Implements: DIARY-BASE-portal-stale-client-reload
Future<void> clearCacheAndReload() => impl.clearCacheAndReload();

/// Check if running on web platform
bool get isWebPlatform => impl.isWebPlatform;
