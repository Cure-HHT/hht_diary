/// Web-platform seam for the few browser-only operations the stale-client
/// feature needs: service-worker eviction, a full-document reload, and a
/// once-per-session auto-reload guard backed by `sessionStorage`.
///
/// The real implementation ([web_platform_web.dart]) uses `package:web` +
/// `dart:js_interop`; the [web_platform_stub.dart] no-op keeps `app.dart`
/// loadable on the Dart VM so widget tests run without a browser. Tests inject
/// a fake implementing [WebPlatform] to assert the reload/guard behaviour.
library;

export 'web_platform_stub.dart'
    if (dart.library.js_interop) 'web_platform_web.dart';
