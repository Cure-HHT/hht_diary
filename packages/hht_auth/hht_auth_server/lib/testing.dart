/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - Testing utilities
///   REQ-d00079: Linking Code Pattern Matching - Test fakes
///   REQ-d00081: User Document Schema - Test fakes
///
/// Testing utilities and fakes for hht_auth_server.
///
/// Provides in-memory fake implementations of repositories for unit testing.
///
/// ## Usage
///
/// ```dart
/// import 'package:hht_auth_server/testing.dart';
///
/// void main() {
///   test('user registration', () async {
///     final userRepo = FakeUserRepository();
///     final patternRepo = FakeSponsorPatternRepository();
///
///     // Setup test data
///     await patternRepo.createPattern(testPattern);
///
///     // Test your service
///     // ...
///   });
/// }
/// ```
library hht_auth_server_testing;

export 'testing/fake_user_repository.dart';
export 'testing/fake_sponsor_pattern_repository.dart';
