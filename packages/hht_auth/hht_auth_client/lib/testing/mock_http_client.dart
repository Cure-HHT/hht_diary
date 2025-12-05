/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service interfaces
///
/// Mock HTTP client for testing.
///
/// Provides a controllable HTTP client that returns pre-configured responses.

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mock HTTP client for testing.
///
/// Allows configuring responses for specific endpoints without making
/// real network requests.
class MockHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses = {};
  final List<http.Request> _requests = [];
  
  http.Response? _defaultResponse;

  /// Configures a response for a specific path.
  void mockResponse(String path, http.Response response) {
    _responses[path] = response;
  }

  /// Configures a JSON response for a specific path.
  void mockJsonResponse(String path, Map<String, dynamic> json, {int statusCode = 200}) {
    _responses[path] = http.Response(
      jsonEncode(json),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Sets a default response for any unmatched path.
  void setDefaultResponse(http.Response response) {
    _defaultResponse = response;
  }

  /// Returns the list of requests that were made.
  List<http.Request> get requests => List.unmodifiable(_requests);

  /// Clears all configured responses and recorded requests.
  void clear() {
    _responses.clear();
    _requests.clear();
    _defaultResponse = null;
  }

  @override
  Future<http.StreamedResponse> send(http.Request request) async {
    _requests.add(request);
    
    final path = request.url.path;
    final response = _responses[path] ?? _defaultResponse;
    
    if (response == null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('Not Found')),
        404,
      );
    }
    
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }

  /// Gets the last request that was made.
  http.Request? get lastRequest => _requests.isNotEmpty ? _requests.last : null;

  /// Checks if a request was made to a specific path.
  bool hasRequestTo(String path) {
    return _requests.any((r) => r.url.path == path);
  }

  /// Gets all requests to a specific path.
  List<http.Request> requestsTo(String path) {
    return _requests.where((r) => r.url.path == path).toList();
  }
}
