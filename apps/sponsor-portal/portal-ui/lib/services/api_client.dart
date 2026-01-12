// IMPLEMENTS REQUIREMENTS:
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-d00035: User Management API
//
// HTTP client for portal API calls with authentication

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// HTTP client for making authenticated API calls to the portal server
class ApiClient {
  final AuthService _authService;
  final http.Client _httpClient;

  /// Create ApiClient with optional HTTP client for testing
  ApiClient(this._authService, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Base URL for portal API
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

  /// Make an authenticated GET request
  Future<ApiResponse> get(String path) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        return ApiResponse(statusCode: 401, error: 'Not authenticated');
      }

      final response = await _httpClient.get(
        Uri.parse('$_apiBaseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return _parseResponse(response);
    } catch (e) {
      debugPrint('API GET error: $e');
      return ApiResponse(statusCode: 500, error: 'Network error: $e');
    }
  }

  /// Make an authenticated POST request
  Future<ApiResponse> post(String path, Map<String, dynamic> body) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        return ApiResponse(statusCode: 401, error: 'Not authenticated');
      }

      final response = await _httpClient.post(
        Uri.parse('$_apiBaseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return _parseResponse(response);
    } catch (e) {
      debugPrint('API POST error: $e');
      return ApiResponse(statusCode: 500, error: 'Network error: $e');
    }
  }

  /// Make an authenticated PATCH request
  Future<ApiResponse> patch(String path, Map<String, dynamic> body) async {
    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        return ApiResponse(statusCode: 401, error: 'Not authenticated');
      }

      final response = await _httpClient.patch(
        Uri.parse('$_apiBaseUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return _parseResponse(response);
    } catch (e) {
      debugPrint('API PATCH error: $e');
      return ApiResponse(statusCode: 500, error: 'Network error: $e');
    }
  }

  /// Parse HTTP response into ApiResponse
  ApiResponse _parseResponse(http.Response response) {
    try {
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(statusCode: response.statusCode, data: data);
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          error: data is Map ? (data['error'] as String?) : 'Request failed',
          data: data,
        );
      }
    } catch (e) {
      return ApiResponse(
        statusCode: response.statusCode,
        error: 'Failed to parse response: $e',
      );
    }
  }
}

/// Response from API calls
class ApiResponse {
  final int statusCode;
  final dynamic data;
  final String? error;

  ApiResponse({required this.statusCode, this.data, this.error});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
