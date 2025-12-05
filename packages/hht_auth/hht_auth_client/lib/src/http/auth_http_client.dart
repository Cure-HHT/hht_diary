/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///   REQ-d00080: Web Session Management Implementation
///
/// HTTP client with automatic authentication header injection.
///
/// Wraps the standard HTTP client to automatically inject JWT tokens
/// from storage into request headers.

import 'package:http/http.dart' as http;
import 'package:hht_auth_core/hht_auth_core.dart';

/// HTTP client that automatically injects authentication headers.
///
/// This client wraps a standard HTTP client and automatically adds
/// Authorization headers with JWT tokens from storage.
class AuthHttpClient {
  /// Base URL for API requests.
  final String baseUrl;

  /// Token storage for retrieving authentication tokens.
  final TokenStorage tokenStorage;

  /// Underlying HTTP client.
  final http.Client _httpClient;

  /// Creates an HTTP client with auth header injection.
  AuthHttpClient({
    required this.baseUrl,
    required this.tokenStorage,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Builds a URI from a path and optional query parameters.
  Uri buildUri(String path, {Map<String, String>? queryParams}) {
    // Ensure path starts with /
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$normalizedPath';
    
    final uri = Uri.parse(fullUrl);
    
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    
    return uri;
  }

  /// Builds headers with automatic token injection.
  Future<Map<String, String>> buildHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Add token if available
    final token = await tokenStorage.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Merge additional headers (can override defaults)
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Sends a GET request with automatic auth headers.
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = buildUri(path, queryParams: queryParams);
    final requestHeaders = await buildHeaders(additionalHeaders: headers);
    return _httpClient.get(uri, headers: requestHeaders);
  }

  /// Sends a POST request with automatic auth headers.
  Future<http.Response> post(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = buildUri(path, queryParams: queryParams);
    final requestHeaders = await buildHeaders(additionalHeaders: headers);
    return _httpClient.post(uri, headers: requestHeaders, body: body);
  }

  /// Sends a PUT request with automatic auth headers.
  Future<http.Response> put(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = buildUri(path, queryParams: queryParams);
    final requestHeaders = await buildHeaders(additionalHeaders: headers);
    return _httpClient.put(uri, headers: requestHeaders, body: body);
  }

  /// Sends a DELETE request with automatic auth headers.
  Future<http.Response> delete(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = buildUri(path, queryParams: queryParams);
    final requestHeaders = await buildHeaders(additionalHeaders: headers);
    return _httpClient.delete(uri, headers: requestHeaders);
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}
