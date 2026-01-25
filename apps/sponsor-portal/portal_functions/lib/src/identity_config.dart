// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-o00056: Container infrastructure for Cloud Run
//
// Identity Platform configuration endpoint
// Returns Firebase/Identity Platform config for client initialization
// Config values are read from Doppler-injected environment variables

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Identity Platform configuration read from environment variables
///
/// These values are public (not secrets) - security is enforced via:
/// - Domain restrictions in GCP Console
/// - Server-side token verification
/// - API key restrictions
class IdentityConfig {
  /// Firebase/Identity Platform API key
  ///
  /// Environment: PORTAL_IDENTITY_API_KEY
  static String get apiKey =>
      Platform.environment['PORTAL_IDENTITY_API_KEY'] ?? '';

  /// Firebase App ID
  ///
  /// Environment: PORTAL_IDENTITY_APP_ID
  static String get appId =>
      Platform.environment['PORTAL_IDENTITY_APP_ID'] ?? '';

  /// GCP Project ID
  ///
  /// Environment: PORTAL_IDENTITY_PROJECT_ID
  static String get projectId =>
      Platform.environment['PORTAL_IDENTITY_PROJECT_ID'] ?? '';

  /// Firebase Auth Domain (typically {project-id}.firebaseapp.com)
  ///
  /// Environment: PORTAL_IDENTITY_AUTH_DOMAIN
  static String get authDomain =>
      Platform.environment['PORTAL_IDENTITY_AUTH_DOMAIN'] ?? '';

  /// Firebase Messaging Sender ID (optional, for push notifications)
  ///
  /// Environment: PORTAL_IDENTITY_MESSAGING_SENDER_ID
  static String get messagingSenderId =>
      Platform.environment['PORTAL_IDENTITY_MESSAGING_SENDER_ID'] ?? '';

  /// Check if Identity Platform is configured
  ///
  /// Returns true if all required environment variables are set.
  /// messagingSenderId is optional.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      projectId.isNotEmpty &&
      authDomain.isNotEmpty;

  /// Convert configuration to JSON for API response
  static Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'appId': appId,
    'projectId': projectId,
    'authDomain': authDomain,
    'messagingSenderId': messagingSenderId,
  };
}

/// Get Identity Platform configuration for client initialization
/// GET /api/v1/portal/config/identity
///
/// This endpoint returns the Firebase/Identity Platform configuration
/// that the Flutter web app needs to initialize Firebase.
///
/// This endpoint is public (no auth required) because:
/// - These values are designed to be public (like Firebase config in web apps)
/// - Security is enforced via domain restrictions and API key restrictions
/// - The client needs this config BEFORE it can authenticate
///
/// Returns:
///   200: {
///     "apiKey": "AIza...",
///     "appId": "1:123456789:web:abcdef",
///     "projectId": "my-project",
///     "authDomain": "my-project.firebaseapp.com",
///     "messagingSenderId": "123456789"
///   }
///
///   503: {"error": "Identity Platform not configured"}
///        (when environment variables are missing)
Future<Response> identityConfigHandler(Request request) async {
  print('[IDENTITY_CONFIG] identityConfigHandler called');

  if (!IdentityConfig.isConfigured) {
    print('[IDENTITY_CONFIG] Configuration missing - returning 503');
    print('[IDENTITY_CONFIG] apiKey set: ${IdentityConfig.apiKey.isNotEmpty}');
    print('[IDENTITY_CONFIG] appId set: ${IdentityConfig.appId.isNotEmpty}');
    print(
      '[IDENTITY_CONFIG] projectId set: ${IdentityConfig.projectId.isNotEmpty}',
    );
    print(
      '[IDENTITY_CONFIG] authDomain set: ${IdentityConfig.authDomain.isNotEmpty}',
    );

    return Response(
      503,
      body: jsonEncode({
        'error': 'Identity Platform not configured',
        'message':
            'Server is missing required Identity Platform configuration. '
            'Please contact your administrator.',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  print(
    '[IDENTITY_CONFIG] Returning configuration for project: ${IdentityConfig.projectId}',
  );

  return Response.ok(
    jsonEncode(IdentityConfig.toJson()),
    headers: {'Content-Type': 'application/json'},
  );
}
