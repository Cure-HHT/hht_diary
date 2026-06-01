import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/env_profile.dart';

/// Sets up the environment profile for tests.
///
/// Call this in setUp() or setUpAll() for any tests that access
/// environment-dependent configuration.
///
/// The [env] parameter selects the [AppEnv] to activate (defaults to dev).
/// Use [testApiBase] to override [AppConfig.apiBase] with a custom test URL.
///
/// Example:
/// ```dart
/// setUpAll(() {
///   setUpTestFlavor();
/// });
/// ```
void setUpTestFlavor([AppEnv env = AppEnv.dev, String? testApiBase]) {
  EnvProfile.current = EnvProfile.forEnv(env);
  // Optional: override apiBase for tests that need a specific URL
  AppConfig.testApiBaseOverride = testApiBase;
}
