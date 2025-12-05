/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00079: Linking Code Pattern Matching interfaces
///   REQ-d00081: User Document Schema
///
/// Test data fixtures for authentication testing.

import 'package:hht_auth_core/src/models/auth_token.dart';
import 'package:hht_auth_core/src/models/linking_code_validation.dart';
import 'package:hht_auth_core/src/models/login_request.dart';
import 'package:hht_auth_core/src/models/registration_request.dart';
import 'package:hht_auth_core/src/models/sponsor_config.dart';
import 'package:hht_auth_core/src/models/sponsor_pattern.dart';
import 'package:hht_auth_core/src/models/web_user.dart';

/// Test fixtures for authentication models.
class TestFixtures {
  TestFixtures._();

  static final DateTime baseDateTime = DateTime.utc(2025, 12, 4, 10, 0, 0);

  // Auth Token Fixtures
  static AuthToken createAuthToken({
    String sub = 'user-test-123',
    String username = 'testuser',
    String sponsorId = 'sponsor-test',
    String sponsorUrl = 'https://test-sponsor.example.com',
    String appUuid = 'app-uuid-test',
    DateTime? iat,
    DateTime? exp,
  }) {
    return AuthToken(
      sub: sub,
      username: username,
      sponsorId: sponsorId,
      sponsorUrl: sponsorUrl,
      appUuid: appUuid,
      iat: iat ?? baseDateTime,
      exp: exp ?? baseDateTime.add(const Duration(minutes: 15)),
    );
  }

  // Web User Fixtures
  static WebUser createWebUser({
    String id = 'user-test-123',
    String username = 'testuser',
    String passwordHash = 'hash-test',
    String sponsorId = 'sponsor-test',
    String linkingCode = 'TEST-12345',
    String appUuid = 'app-uuid-test',
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int failedAttempts = 0,
    DateTime? lockedUntil,
  }) {
    return WebUser(
      id: id,
      username: username,
      passwordHash: passwordHash,
      sponsorId: sponsorId,
      linkingCode: linkingCode,
      appUuid: appUuid,
      createdAt: createdAt ?? baseDateTime,
      lastLoginAt: lastLoginAt,
      failedAttempts: failedAttempts,
      lockedUntil: lockedUntil,
    );
  }

  // Sponsor Pattern Fixtures
  static SponsorPattern createSponsorPattern({
    String patternPrefix = 'TEST-',
    String sponsorId = 'sponsor-test',
    String sponsorName = 'Test Sponsor',
    String portalUrl = 'https://test-sponsor.example.com',
    String firestoreProject = 'project-test',
    bool active = true,
    DateTime? createdAt,
    DateTime? decommissionedAt,
  }) {
    return SponsorPattern(
      patternPrefix: patternPrefix,
      sponsorId: sponsorId,
      sponsorName: sponsorName,
      portalUrl: portalUrl,
      firestoreProject: firestoreProject,
      active: active,
      createdAt: createdAt ?? baseDateTime,
      decommissionedAt: decommissionedAt,
    );
  }

  // Sponsor Config Fixtures
  static SponsorConfig createSponsorConfig({
    String sponsorId = 'sponsor-test',
    String sponsorName = 'Test Sponsor',
    String portalUrl = 'https://test-sponsor.example.com',
    String firestoreProjectId = 'project-test',
    String firestoreApiKey = 'api-key-test',
    int sessionTimeoutMinutes = 2,
    SponsorBranding? branding,
  }) {
    return SponsorConfig(
      sponsorId: sponsorId,
      sponsorName: sponsorName,
      portalUrl: portalUrl,
      firestoreProjectId: firestoreProjectId,
      firestoreApiKey: firestoreApiKey,
      sessionTimeoutMinutes: sessionTimeoutMinutes,
      branding: branding ?? createSponsorBranding(),
    );
  }

  static SponsorBranding createSponsorBranding({
    String logoUrl = 'https://example.com/logo.png',
    String primaryColor = '#FF5733',
    String secondaryColor = '#3366FF',
    String welcomeMessage = 'Welcome to Test Sponsor',
  }) {
    return SponsorBranding(
      logoUrl: logoUrl,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      welcomeMessage: welcomeMessage,
    );
  }

  // Request Fixtures
  static RegistrationRequest createRegistrationRequest({
    String username = 'testuser',
    String passwordHash = 'hash-test',
    String salt = 'salt-test',
    String linkingCode = 'TEST-12345',
    String appUuid = 'app-uuid-test',
  }) {
    return RegistrationRequest(
      username: username,
      passwordHash: passwordHash,
      salt: salt,
      linkingCode: linkingCode,
      appUuid: appUuid,
    );
  }

  static LoginRequest createLoginRequest({
    String username = 'testuser',
    String password = 'password123',
    String appUuid = 'app-uuid-test',
  }) {
    return LoginRequest(
      username: username,
      password: password,
      appUuid: appUuid,
    );
  }

  // Linking Code Validation Fixtures
  static LinkingCodeValid createLinkingCodeValid({
    String sponsorId = 'sponsor-test',
    String sponsorName = 'Test Sponsor',
    String portalUrl = 'https://test-sponsor.example.com',
  }) {
    return LinkingCodeValid(
      sponsorId: sponsorId,
      sponsorName: sponsorName,
      portalUrl: portalUrl,
    );
  }

  static const LinkingCodeInvalid linkingCodeInvalid =
      LinkingCodeInvalid('Invalid linking code');
}
