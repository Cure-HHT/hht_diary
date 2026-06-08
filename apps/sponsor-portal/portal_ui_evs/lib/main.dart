import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'src/app.dart';
import 'src/web_platform.dart';

/// Build version, stamped at image-build time via
/// `--dart-define=APP_VERSION=<semver>+<build_id>`. Referencing it here keeps
/// the dart2js-inlined value (carrying the `__BUILD_ID__` sentinel) in the
/// compiled bundle so the portal-final image build can stamp the real build id.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

void main() {
  // CUR-1307: force-enable the web semantics tree so Playwright can drive the
  // CanvasKit-rendered app via flt-semantics-identifier (mirrors the diary +
  // reaction/example harnesses). No-op off web.
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  // Evict any lingering legacy service worker on boot so it can't keep
  // intercepting fetches and serving a stale precache (the root cause of the
  // "must hard-reset to pick up a deploy" symptom). No-op off web / when none.
  // Implements: DIARY-DEV-portal-legacy-sw-eviction/A
  unawaited(const WebPlatform().unregisterServiceWorkers());
  debugPrint('portal_ui_evs APP_VERSION=$appVersion');
  runApp(const PortalEvsApp());
}
