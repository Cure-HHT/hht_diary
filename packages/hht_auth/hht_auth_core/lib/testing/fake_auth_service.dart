/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///
/// Fake implementation for testing purposes.

import 'package:hht_auth_core/src/interfaces/auth_service.dart';
import 'package:hht_auth_core/src/models/auth_result.dart';
import 'package:hht_auth_core/src/models/linking_code_validation.dart';
import 'package:hht_auth_core/src/models/login_request.dart';
import 'package:hht_auth_core/src/models/registration_request.dart';
import 'package:hht_auth_core/src/models/sponsor_config.dart';

/// Fake authentication service for testing.
///
/// Allows configuring responses and inspecting method calls.
class FakeAuthService implements AuthService {
  LinkingCodeValidation? _validateLinkingCodeResponse;
  AuthResult? _registerResponse;
  AuthResult? _loginResponse;
  AuthResult? _refreshTokenResponse;
  AuthResult? _changePasswordResponse;
  SponsorConfig? _sponsorConfigResponse;

  final List<String> validateLinkingCodeCalls = [];
  final List<RegistrationRequest> registerCalls = [];
  final List<LoginRequest> loginCalls = [];
  final List<String> refreshTokenCalls = [];
  final List<Map<String, dynamic>> changePasswordCalls = [];
  final List<String> getSponsorConfigCalls = [];

  /// Sets the response for [validateLinkingCode].
  void setValidateLinkingCodeResponse(LinkingCodeValidation response) {
    _validateLinkingCodeResponse = response;
  }

  /// Sets the response for [register].
  void setRegisterResponse(AuthResult response) {
    _registerResponse = response;
  }

  /// Sets the response for [login].
  void setLoginResponse(AuthResult response) {
    _loginResponse = response;
  }

  /// Sets the response for [refreshToken].
  void setRefreshTokenResponse(AuthResult response) {
    _refreshTokenResponse = response;
  }

  /// Sets the response for [changePassword].
  void setChangePasswordResponse(AuthResult response) {
    _changePasswordResponse = response;
  }

  /// Sets the response for [getSponsorConfig].
  void setSponsorConfigResponse(SponsorConfig response) {
    _sponsorConfigResponse = response;
  }

  /// Resets all recorded calls and responses.
  void reset() {
    _validateLinkingCodeResponse = null;
    _registerResponse = null;
    _loginResponse = null;
    _refreshTokenResponse = null;
    _changePasswordResponse = null;
    _sponsorConfigResponse = null;

    validateLinkingCodeCalls.clear();
    registerCalls.clear();
    loginCalls.clear();
    refreshTokenCalls.clear();
    changePasswordCalls.clear();
    getSponsorConfigCalls.clear();
  }

  @override
  Future<LinkingCodeValidation> validateLinkingCode(String linkingCode) async {
    validateLinkingCodeCalls.add(linkingCode);
    return _validateLinkingCodeResponse ??
        const LinkingCodeInvalid('No response configured');
  }

  @override
  Future<AuthResult> register(RegistrationRequest request) async {
    registerCalls.add(request);
    return _registerResponse ??
        const AuthFailure(
          message: 'No response configured',
          reason: AuthFailureReason.unknown,
        );
  }

  @override
  Future<AuthResult> login(LoginRequest request) async {
    loginCalls.add(request);
    return _loginResponse ??
        const AuthFailure(
          message: 'No response configured',
          reason: AuthFailureReason.unknown,
        );
  }

  @override
  Future<AuthResult> refreshToken(String currentToken) async {
    refreshTokenCalls.add(currentToken);
    return _refreshTokenResponse ??
        const AuthFailure(
          message: 'No response configured',
          reason: AuthFailureReason.unknown,
        );
  }

  @override
  Future<AuthResult> changePassword({
    required String username,
    required String currentPassword,
    required String newPasswordHash,
    required String newSalt,
  }) async {
    changePasswordCalls.add({
      'username': username,
      'currentPassword': currentPassword,
      'newPasswordHash': newPasswordHash,
      'newSalt': newSalt,
    });
    return _changePasswordResponse ??
        const AuthFailure(
          message: 'No response configured',
          reason: AuthFailureReason.unknown,
        );
  }

  @override
  Future<SponsorConfig> getSponsorConfig(String sponsorId) async {
    getSponsorConfigCalls.add(sponsorId);
    if (_sponsorConfigResponse == null) {
      throw Exception('No response configured for getSponsorConfig');
    }
    return _sponsorConfigResponse!;
  }
}
