/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service
///
/// Client-side authentication service implementation.
///
/// Communicates with the HHT Diary Auth service running on Cloud Run
/// to handle user registration, login, and token management.

import 'dart:convert';
import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_client/src/http/auth_http_client.dart';

/// Client-side authentication service for Flutter Web.
///
/// Implements the AuthService interface by making HTTP requests to
/// the backend authentication service.
class WebAuthService implements AuthService {
  final AuthHttpClient _httpClient;

  WebAuthService(this._httpClient);

  @override
  Future<LinkingCodeValidation> validateLinkingCode(String linkingCode) async {
    try {
      final response = await _httpClient.post(
        '/auth/validate-linking-code',
        body: jsonEncode({'linkingCode': linkingCode}),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return LinkingCodeValid(
          sponsorId: json['sponsorId'] as String,
          sponsorName: json['sponsorName'] as String,
          portalUrl: json['portalUrl'] as String,
        );
      } else {
        return LinkingCodeInvalid(
          message: json['message'] as String? ?? 'Invalid linking code',
        );
      }
    } catch (e) {
      return LinkingCodeInvalid(message: 'Network error: $e');
    }
  }

  @override
  Future<AuthResult> register(RegistrationRequest request) async {
    try {
      final response = await _httpClient.post(
        '/auth/register',
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthSuccess(
          token: json['token'] as String,
          user: WebUser.fromJson(json['user'] as Map<String, dynamic>),
        );
      } else {
        return AuthFailure(
          message: json['message'] as String? ?? 'Registration failed',
        );
      }
    } catch (e) {
      return AuthFailure(message: 'Network error: $e');
    }
  }

  @override
  Future<AuthResult> login(LoginRequest request) async {
    try {
      final response = await _httpClient.post(
        '/auth/login',
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthSuccess(
          token: json['token'] as String,
          user: WebUser.fromJson(json['user'] as Map<String, dynamic>),
        );
      } else {
        return AuthFailure(
          message: json['message'] as String? ?? 'Login failed',
        );
      }
    } catch (e) {
      return AuthFailure(message: 'Network error: $e');
    }
  }

  @override
  Future<AuthResult> refreshToken(String currentToken) async {
    try {
      final response = await _httpClient.post(
        '/auth/refresh',
        body: jsonEncode({'token': currentToken}),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthSuccess(
          token: json['token'] as String,
          user: WebUser.fromJson(json['user'] as Map<String, dynamic>),
        );
      } else {
        return AuthFailure(
          message: json['message'] as String? ?? 'Token refresh failed',
        );
      }
    } catch (e) {
      return AuthFailure(message: 'Network error: $e');
    }
  }

  @override
  Future<AuthResult> changePassword({
    required String username,
    required String currentPassword,
    required String newPasswordHash,
    required String newSalt,
  }) async {
    try {
      final response = await _httpClient.post(
        '/auth/change-password',
        body: jsonEncode({
          'username': username,
          'currentPassword': currentPassword,
          'newPasswordHash': newPasswordHash,
          'newSalt': newSalt,
        }),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthSuccess(
          token: json['token'] as String,
          user: WebUser.fromJson(json['user'] as Map<String, dynamic>),
        );
      } else {
        return AuthFailure(
          message: json['message'] as String? ?? 'Password change failed',
        );
      }
    } catch (e) {
      return AuthFailure(message: 'Network error: $e');
    }
  }

  @override
  Future<SponsorConfig> getSponsorConfig(String sponsorId) async {
    try {
      final response = await _httpClient.get('/auth/sponsor-config/$sponsorId');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SponsorConfig.fromJson(json);
      } else {
        throw AuthException('Failed to load sponsor config: ${response.statusCode}');
      }
    } catch (e) {
      throw AuthException('Failed to load sponsor config: $e');
    }
  }
}
