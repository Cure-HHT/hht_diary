// lib/config/env_profile.dart
// Implements: DIARY-DEV-runtime-environment-resolution/C

/// Deployment environment. `local` targets a developer's local stack (Firebase
/// emulator); the other four are the promoted deploy environments. Mirrors the
/// mobile `AppEnv` (clinical_diary) so environment-derived behaviour stays
/// consistent across the platform.
enum AppEnv { local, dev, qa, uat, prod }

/// The single source of truth for environment-derived presentation, resolved
/// at runtime from the environment name the server reports over its same-origin
/// runtime config (see [fromServerName]) rather than a compile-time flavor
/// constant. The web bundle itself carries no environment identity.
class EnvProfile {
  const EnvProfile({
    required this.env,
    required this.title,
    required this.showBanner,
    required this.showDevTools,
  });

  final AppEnv env;
  final String title;
  final bool showBanner;
  final bool showDevTools;

  String get name => env.name;

  static const _registry = <AppEnv, EnvProfile>{
    AppEnv.local: EnvProfile(
      env: AppEnv.local,
      title: 'Portal LOCAL',
      showBanner: true,
      showDevTools: true,
    ),
    AppEnv.dev: EnvProfile(
      env: AppEnv.dev,
      title: 'Portal DEV',
      showBanner: true,
      showDevTools: true,
    ),
    AppEnv.qa: EnvProfile(
      env: AppEnv.qa,
      title: 'Portal QA',
      showBanner: true,
      showDevTools: true,
    ),
    // uat/prod hide the banner and dev tools (the prod capability gate;
    // uat mirrors prod's presentation for representative UAT).
    AppEnv.uat: EnvProfile(
      env: AppEnv.uat,
      title: 'Portal UAT',
      showBanner: false,
      showDevTools: false,
    ),
    AppEnv.prod: EnvProfile(
      env: AppEnv.prod,
      title: 'Clinical Trial Portal',
      showBanner: false,
      showDevTools: false,
    ),
  };

  static EnvProfile forEnv(AppEnv env) => _registry[env]!;

  /// The active profile, set once during bootstrap. Defaults to dev so any
  /// access before resolution (e.g. in widget tests) is safe.
  static EnvProfile current = _registry[AppEnv.dev]!;

  /// Resolve the active environment from the name the server reports over its
  /// same-origin runtime config. An absent or unrecognised name resolves to
  /// dev — a deployed bundle is identical across environments and carries no
  /// environment identity of its own.
  // Implements: DIARY-DEV-runtime-environment-resolution/A+B
  static EnvProfile fromServerName(String? name) {
    final normalized = name?.toLowerCase().trim();
    final env = AppEnv.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => AppEnv.dev,
    );
    return forEnv(env);
  }
}
