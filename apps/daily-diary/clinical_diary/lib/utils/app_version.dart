/// The app version embedded at build time via --dart-define=APP_VERSION=x.x.x
///
/// This constant is set during the CI build process from pubspec.yaml.
/// Falls back to '0.0.0' during development if not defined.
// Implements: DIARY-BASE-portal-stale-client-reload
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.0.0',
);

// NOTE: The runtime environment (local/dev/qa/uat/prod) has a SINGLE source of
// truth — the bundled pointer `assets/config/env.json`, resolved via
// `EnvProfile.load()` (DIARY-DEV-runtime-environment-resolution). There is no
// `APP_FLAVOR` dart-define: it was removed in CUR-1389 to keep the binary
// environment-independent. Read `AppConfig.environment` / `EnvProfile.current`
// for the active environment.
