import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models/exceptions.dart';
import 'models/site.dart';
import 'models/subject.dart';
import 'odm_parser.dart';

/// Client for Medidata RAVE Web Services API.
///
/// Provides methods to interact with the RAVE EDC system for site
/// synchronization and connectivity verification.
///
/// Example:
/// ```dart
/// final client = RaveClient(
///   baseUrl: '$RAVE_UAT_URL',
///   username: 'api-user',
///   password: 'api-password',
/// );
///
/// // Verify connectivity
/// final version = await client.getVersion();
///
/// // Get sites
/// final sites = await client.getSites(studyOid: 'TER-1754-C01(APPDEV)');
/// ```
class RaveClient {
  /// Base URL for the RAVE instance (e.g., '$RAVE_UAT_URL').
  final String baseUrl;

  /// Username for HTTP Basic Authentication.
  final String username;

  /// Password for HTTP Basic Authentication.
  /// Note: PIN is NOT appended for Basic Auth.
  final String password;

  /// HTTP client for making requests. Injectable for testing.
  final http.Client _httpClient;

  /// Creates a new RAVE client.
  ///
  /// [baseUrl] - The RAVE instance URL (without trailing slash).
  /// [username] - API username for Basic Auth.
  /// [password] - API password (PIN not appended).
  /// [httpClient] - Optional HTTP client for testing.
  RaveClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Creates authorization header value for HTTP Basic Auth.
  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  /// Checks RAVE server connectivity by calling the version endpoint.
  ///
  /// This endpoint does NOT require authentication and can be used as a
  /// basic connectivity sanity check.
  ///
  /// Returns the version string from the server.
  /// Throws [RaveNetworkException] on network errors.
  /// Throws [RaveApiException] on non-200 responses.
  Future<String> getVersion() async {
    final uri = Uri.parse('$baseUrl/RaveWebServices/version');

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) {
        return response.body.trim();
      }

      throw RaveApiException(
        'Version endpoint returned status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw RaveNetworkException('Failed to connect to RAVE server', cause: e);
    } on http.ClientException catch (e) {
      throw RaveNetworkException('HTTP client error', cause: e);
    }
  }

  /// Lists studies accessible to the authenticated user.
  ///
  /// This endpoint requires authentication and can be used to verify
  /// that credentials are valid.
  ///
  /// Returns the raw XML response containing study list.
  /// Throws [RaveAuthenticationException] on 401 responses.
  /// Throws [RaveNetworkException] on network errors.
  Future<String> getStudies() async {
    final uri = Uri.parse('$baseUrl/RaveWebServices/studies');

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Authorization': _authHeader},
      );

      if (response.statusCode == 200) {
        return response.body;
      }

      if (response.statusCode == 401) {
        throw const RaveAuthenticationException();
      }

      throw RaveApiException(
        'Studies endpoint returned status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw RaveNetworkException('Failed to connect to RAVE server', cause: e);
    } on http.ClientException catch (e) {
      throw RaveNetworkException('HTTP client error', cause: e);
    }
  }

  /// Retrieves all sites for a study from the Sites.odm dataset.
  ///
  /// [studyOid] - The study OID (e.g., 'TER-1754-C01(APPDEV)').
  ///             If null, returns sites across all accessible studies.
  ///
  /// Returns a list of [RaveSite] objects.
  /// Returns an empty list if no sites are found or user has no access.
  ///
  /// Throws [RaveAuthenticationException] on 401 responses.
  /// Throws [RaveIncompleteResponseException] if ODM response is truncated.
  /// Throws [RaveParseException] if ODM XML is malformed.
  /// Throws [RaveNetworkException] on network errors.
  Future<List<RaveSite>> getSites({String? studyOid}) async {
    var path = '$baseUrl/RaveWebServices/datasets/Sites.odm';
    if (studyOid != null) {
      path += '?studyoid=${Uri.encodeComponent(studyOid)}';
    }
    final uri = Uri.parse(path);

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Authorization': _authHeader},
      );

      if (response.statusCode == 401) {
        throw const RaveAuthenticationException();
      }

      if (response.statusCode != 200) {
        throw RaveApiException(
          'Sites endpoint returned status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final xml = response.body;

      // Check for empty response (no permission or no data)
      if (OdmParser.isEmpty(xml)) {
        return [];
      }

      return OdmParser.parseSites(xml);
    } on SocketException catch (e) {
      throw RaveNetworkException('Failed to connect to RAVE server', cause: e);
    } on http.ClientException catch (e) {
      throw RaveNetworkException('HTTP client error', cause: e);
    } on RaveException {
      rethrow;
    }
  }

  /// Retrieves all subjects (patients) for a study.
  ///
  /// [studyOid] - The study OID (required for subjects endpoint).
  ///
  /// Returns a list of [RaveSubject] objects.
  /// Returns an empty list if no subjects are found or user has no access.
  ///
  /// Throws [RaveAuthenticationException] on 401 responses.
  /// Throws [RaveIncompleteResponseException] if ODM response is truncated.
  /// Throws [RaveParseException] if ODM XML is malformed.
  /// Throws [RaveNetworkException] on network errors.
  Future<List<RaveSubject>> getSubjects({required String studyOid}) async {
    final uri = Uri.parse(
      '$baseUrl/RaveWebServices/studies/${Uri.encodeComponent(studyOid)}/subjects',
    );

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Authorization': _authHeader},
      );

      if (response.statusCode == 401) {
        throw const RaveAuthenticationException();
      }

      if (response.statusCode != 200) {
        throw RaveApiException(
          'Subjects endpoint returned status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final xml = response.body;

      // Check for empty response (no permission or no data)
      if (OdmParser.isSubjectsEmpty(xml)) {
        return [];
      }

      return OdmParser.parseSubjects(xml);
    } on SocketException catch (e) {
      throw RaveNetworkException('Failed to connect to RAVE server', cause: e);
    } on http.ClientException catch (e) {
      throw RaveNetworkException('HTTP client error', cause: e);
    } on RaveException {
      rethrow;
    }
  }

  /// Closes the underlying HTTP client.
  ///
  /// Call this when done using the client to free resources.
  void close() {
    _httpClient.close();
  }
}
