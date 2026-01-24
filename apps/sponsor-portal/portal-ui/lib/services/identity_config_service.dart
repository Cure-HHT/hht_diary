// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Client-side service for fetching Identity Platform configuration
// Fetches config from server at runtime instead of compile-time dart-defines

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Identity Platform configuration for Firebase initialization
///
/// Contains all values needed to initialize Firebase Auth:
/// - apiKey: Firebase API key (public, domain-restricted)
/// - appId: Firebase App ID
/// - projectId: GCP Project ID
/// - authDomain: Firebase Auth domain
/// - messagingSenderId: For push notifications (optional)
class IdentityPlatformConfig {
  final String apiKey;
  final String appId;
  final String projectId;
  final String authDomain;
  final String messagingSenderId;

  const IdentityPlatformConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.authDomain,
    this.messagingSenderId = '',
  });

  /// Configuration for local development with Firebase emulator
  ///
  /// These placeholder values work with the emulator since it doesn't
  /// validate Firebase configuration.
  static const emulator = IdentityPlatformConfig(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    projectId: 'demo-sponsor-portal',
    authDomain: 'demo-sponsor-portal.firebaseapp.com',
    messagingSenderId: '000000000000',
  );

  /// Parse configuration from JSON response
  factory IdentityPlatformConfig.fromJson(Map<String, dynamic> json) {
    return IdentityPlatformConfig(
      apiKey: json['apiKey'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      authDomain: json['authDomain'] as String? ?? '',
      messagingSenderId: json['messagingSenderId'] as String? ?? '',
    );
  }

  /// Check if configuration is valid
  bool get isValid =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      projectId.isNotEmpty &&
      authDomain.isNotEmpty;

  @override
  String toString() =>
      'IdentityPlatformConfig(projectId: $projectId, authDomain: $authDomain)';
}

/// Exception thrown when Identity Platform configuration fetch fails
class IdentityConfigException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  IdentityConfigException(this.message, {this.statusCode, this.cause});

  @override
  String toString() {
    if (statusCode != null) {
      return 'IdentityConfigException: $message (status: $statusCode)';
    }
    return 'IdentityConfigException: $message';
  }
}

/// Service for fetching Identity Platform configuration from the server
///
/// The server reads configuration from Doppler-injected environment variables
/// and returns it via a public API endpoint. This allows the same Docker image
/// to work across all environments (dev, qa, uat, prod).
class IdentityConfigService {
  final http.Client _httpClient;

  /// Create service with optional HTTP client for testing
  IdentityConfigService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Get base URL for API calls
  String get _apiBaseUrl {
    // Check for environment override
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Default to localhost for development
    if (kDebugMode) {
      return 'http://localhost:8080';
    }

    // Use the current host origin in production (same-origin API)
    return Uri.base.origin;
  }

  /// Fetch Identity Platform configuration from server
  ///
  /// Makes a GET request to /api/v1/portal/config/identity and parses
  /// the JSON response into an [IdentityPlatformConfig].
  ///
  /// Throws [IdentityConfigException] if:
  /// - Server returns 503 (configuration not set up)
  /// - Server returns other error status
  /// - Network error occurs
  /// - Response cannot be parsed
  Future<IdentityPlatformConfig> fetchConfig() async {
    final url = '$_apiBaseUrl/api/v1/portal/config/identity';
    debugPrint('[IdentityConfigService] Fetching config from: $url');

    try {
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 503) {
        debugPrint(
          '[IdentityConfigService] Server returned 503 - not configured',
        );
        throw IdentityConfigException(
          'Identity Platform not configured on server',
          statusCode: 503,
        );
      }

      if (response.statusCode != 200) {
        debugPrint(
          '[IdentityConfigService] Server returned ${response.statusCode}',
        );
        throw IdentityConfigException(
          'Failed to fetch Identity Platform configuration',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = IdentityPlatformConfig.fromJson(json);

      if (!config.isValid) {
        debugPrint('[IdentityConfigService] Config invalid: $config');
        throw IdentityConfigException(
          'Invalid Identity Platform configuration received',
        );
      }

      debugPrint('[IdentityConfigService] Config loaded: $config');
      return config;
    } on IdentityConfigException {
      rethrow;
    } on FormatException catch (e) {
      debugPrint('[IdentityConfigService] JSON parse error: $e');
      throw IdentityConfigException(
        'Invalid response format from server',
        cause: e,
      );
    } catch (e) {
      debugPrint('[IdentityConfigService] Network error: $e');
      throw IdentityConfigException(
        'Network error while fetching configuration',
        cause: e,
      );
    }
  }
}
