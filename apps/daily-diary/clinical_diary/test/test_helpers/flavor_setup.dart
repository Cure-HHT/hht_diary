// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/flavors.dart';

/// Sets up the flavor for tests.
///
/// Call this in setUp() or setUpAll() for any tests that access
/// flavor-dependent configuration.
///
/// Note: apiBase is now derived from FlavorConfig based on the flavor,
/// so you only need to set the flavor. Use [testApiBase] parameter to
/// override with a custom test URL if needed.
///
/// Example:
/// ```dart
/// setUpAll(() {
///   setUpTestFlavor();
/// });
/// ```
void setUpTestFlavor([Flavor flavor = Flavor.dev, String? testApiBase]) {
  F.appFlavor = flavor;
  // Optional: override apiBase for tests that need a specific URL
  AppConfig.testApiBaseOverride = testApiBase;
}
