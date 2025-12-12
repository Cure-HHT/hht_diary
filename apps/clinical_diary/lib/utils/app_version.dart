// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

/// The app version embedded at build time via --dart-define=APP_VERSION=x.x.x
///
/// This constant is set during the CI build process from pubspec.yaml.
/// Falls back to '0.0.0' during development if not defined.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.0.0',
);

/// The app flavor (dev, staging, prod)
const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'dev',
);
