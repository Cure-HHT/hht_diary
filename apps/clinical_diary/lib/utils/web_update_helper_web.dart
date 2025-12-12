// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Always true on web platform
bool get isWebPlatform => true;

/// Clear browser cache and reload the page
///
/// This function:
/// 1. Unregisters all service workers
/// 2. Clears all CacheStorage caches
/// 3. Forces a hard reload of the page
Future<void> clearCacheAndReload() async {
  try {
    // Step 1: Unregister all service workers
    await _unregisterServiceWorkers();

    // Step 2: Clear all caches
    await _clearAllCaches();

    // Step 3: Force hard reload
    // The 'true' parameter (forceGet) tells the browser to bypass the cache
    _forceReload();
  } catch (e) {
    // If cache clearing fails, still try to reload
    _forceReload();
  }
}

/// Unregister all service workers
Future<void> _unregisterServiceWorkers() async {
  try {
    final serviceWorker = web.window.navigator.serviceWorker;
    final registrations = await serviceWorker.getRegistrations().toDart;
    for (final registration in registrations.toDart) {
      await registration.unregister().toDart;
    }
  } catch (e) {
    // Service worker API may not be available in all contexts
    web.console.warn('Failed to unregister service workers: $e'.toJS);
  }
}

/// Clear all CacheStorage caches
Future<void> _clearAllCaches() async {
  try {
    final caches = web.window.caches;
    final cacheNames = await caches.keys().toDart;
    for (final cacheName in cacheNames.toDart) {
      // Convert JSString to String for caches.delete()
      await caches.delete(cacheName.toDart).toDart;
    }
  } catch (e) {
    // CacheStorage may not be available in all contexts
    web.console.warn('Failed to clear caches: $e'.toJS);
  }
}

/// Force a hard reload of the page
void _forceReload() {
  // Using location.reload() to refresh the page
  // This will load fresh assets from the server due to our
  // Cache-Control headers on index.html
  web.window.location.reload();
}
