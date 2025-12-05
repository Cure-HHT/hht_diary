/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces

import 'package:hht_auth_core/src/models/auth_result.dart';
import 'package:hht_auth_core/src/models/linking_code_validation.dart';
import 'package:hht_auth_core/src/models/login_request.dart';
import 'package:hht_auth_core/src/models/registration_request.dart';
import 'package:hht_auth_core/src/models/sponsor_config.dart';

/// Core authentication service interface.
///
/// Defines operations for user registration, login, token refresh,
/// and sponsor configuration retrieval.
abstract class AuthService {
  /// Validates a linking code and returns sponsor information.
  ///
  /// Returns [LinkingCodeValid] if the code matches a known sponsor pattern,
  /// or [LinkingCodeInvalid] if not recognized or decommissioned.
  Future<LinkingCodeValidation> validateLinkingCode(String linkingCode);

  /// Registers a new user account.
  ///
  /// Returns [AuthSuccess] with a JWT token if registration succeeds,
  /// or [AuthFailure] if the username exists, linking code is invalid,
  /// or other errors occur.
  Future<AuthResult> register(RegistrationRequest request);

  /// Authenticates a user and returns a JWT token.
  ///
  /// Returns [AuthSuccess] with a JWT token if credentials are valid,
  /// or [AuthFailure] if credentials are invalid, account is locked,
  /// or other errors occur.
  Future<AuthResult> login(LoginRequest request);

  /// Refreshes an existing JWT token.
  ///
  /// Returns [AuthSuccess] with a new token if the current token is valid,
  /// or [AuthFailure] if the token is expired or invalid.
  Future<AuthResult> refreshToken(String currentToken);

  /// Changes the user's password.
  ///
  /// Returns [AuthSuccess] if the password is changed successfully,
  /// or [AuthFailure] if the current password is incorrect or validation fails.
  Future<AuthResult> changePassword({
    required String username,
    required String currentPassword,
    required String newPasswordHash,
    required String newSalt,
  });

  /// Retrieves sponsor-specific configuration.
  ///
  /// Returns configuration including branding, Firestore connection details,
  /// and session timeout settings for the specified sponsor.
  Future<SponsorConfig> getSponsorConfig(String sponsorId);
}
