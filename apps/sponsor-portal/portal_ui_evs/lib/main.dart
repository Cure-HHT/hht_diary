import 'package:flutter/material.dart';

import 'src/app.dart';

/// Build version, stamped at image-build time via
/// `--dart-define=APP_VERSION=<semver>+<build_id>`. Referencing it here keeps
/// the dart2js-inlined value (carrying the `__BUILD_ID__` sentinel) in the
/// compiled bundle so the portal-final image build can stamp the real build id.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

void main() {
  debugPrint('portal_ui_evs APP_VERSION=$appVersion');
  runApp(const PortalEvsApp());
}
