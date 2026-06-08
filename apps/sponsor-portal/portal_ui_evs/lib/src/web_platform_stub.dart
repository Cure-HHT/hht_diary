/// Non-web stub of [WebPlatform]: every operation is a no-op so that
/// `app.dart` (which imports the [web_platform.dart] seam) loads on the Dart
/// VM for widget tests. The real browser behaviour lives in
/// [web_platform_web.dart].
class WebPlatform {
  const WebPlatform();

  /// No service workers off web.
  Future<void> unregisterServiceWorkers() async {}

  /// No document to reload off web.
  void reloadPage() {}

  /// No session storage off web; the guard never trips.
  bool get autoReloadAlreadyTried => false;

  void markAutoReloadTried() {}

  void clearAutoReloadGuard() {}
}
