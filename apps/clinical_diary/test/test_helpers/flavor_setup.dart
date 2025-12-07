// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';

/// Sets up the flavor and test API base for tests.
///
/// Call this in setUp() or setUpAll() for any tests that access
/// AppConfig.apiBase or other flavor-dependent configuration.
///
/// Example:
/// ```dart
/// setUpAll(() {
///   setUpTestFlavor();
/// });
/// ```
void setUpTestFlavor([Flavor flavor = Flavor.dev]) {
  F.appFlavor = flavor;
  // Set test API base to avoid MissingConfigException
  // (apiBase is a compile-time const, so tests need this override)
  AppConfig.testApiBaseOverride = 'https://test.example.com/api';
}
