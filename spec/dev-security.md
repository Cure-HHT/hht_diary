# Security Implementation Guide

**Version**: 2.0
**Audience**: Software Developers
**Last Updated**: 2025-11-24
**Status**: Draft

> **Scope**: GCP security implementation, Identity Platform integration, IAM patterns
>
> **See**: prd-security.md for authentication and authorization requirements
> **See**: prd-security-RBAC.md for complete role definitions and permissions
> **See**: prd-security-RLS.md for database row-level security policies
> **See**: prd-security-data-classification.md for encryption and data privacy
> **See**: ops-security.md for security operations
> **See**: ops-security-authentication.md for Identity Platform setup

---

## Executive Summary

This document specifies how to **implement security** in the Clinical Trial Diary Platform using Google Cloud Platform services. The system implements defense-in-depth with multiple authorization layers across a multi-sponsor architecture.

**Authentication**: Google Identity Platform (Identity Platform)
**Authorization Layers**:
1. Role-Based Access Control (RBAC)
2. Row-Level Security (RLS) at database
3. Multi-sponsor GCP project isolation

---

## Multi-Sponsor Access Isolation

### Infrastructure-Level Separation

Each sponsor operates in a completely isolated GCP project, providing **infrastructure-level access isolation**:

```
Sponsor A Environment           Sponsor B Environment
┌─────────────────────────┐    ┌─────────────────────────┐
│ GCP Project A           │    │ GCP Project B           │
│ ├─ Cloud SQL            │    │ ├─ Cloud SQL            │
│ ├─ Identity Platform    │    │ ├─ Identity Platform    │
│ ├─ Cloud Run            │    │ ├─ Cloud Run            │
│ └─ Separate IAM         │    │ └─ Separate IAM         │
└─────────────────────────┘    └─────────────────────────┘
         ↑                              ↑
         │                              │
    Mobile App                     Mobile App
    (connects to A)                (connects to B)
```

**Access Isolation Guarantees**:
- No shared GCP projects
- No shared database instances
- No shared authentication systems
- Users authenticated in Sponsor A cannot access Sponsor B data
- Identity Platform tokens from Sponsor A invalid for Sponsor B
- Complete authentication/authorization independence

### Code Repository Access Control

**Public Core Repository** (`clinical-diary`):
- Contains no authentication credentials
- Contains no sponsor-specific access policies
- Abstract interfaces only (SponsorConfig, EdcSync, etc.)

**Private Sponsor Repositories** (`clinical-diary-{sponsor}`):
- Access restricted via GitHub private repos
- Contains sponsor-specific:
  - Firebase configuration
  - GCP project ID
  - Custom authentication configurations
  - Site assignments
  - Role mappings

---

## Authentication Layer

# REQ-d00003: Identity Platform Configuration Per Sponsor

**Level**: Dev | **Implements**: p00002, o00003 | **Status**: Draft

The application SHALL integrate with Google Identity Platform for user authentication, with each sponsor using their dedicated Identity Platform instance in their GCP project configured for their specific requirements.

Authentication integration SHALL include:
- Initialize Identity Platform client with sponsor-specific project configuration
- Configure JWT verification using Google's public keys
- Implement MFA enrollment and verification flows
- Handle authentication state changes (login, logout, session refresh)
- Store authentication tokens securely on device

**Rationale**: Implements MFA requirement (p00002) and project isolation (o00003) at the application code level. Each sponsor's GCP project has independent Identity Platform configuration, ensuring complete user isolation between sponsors.

**Acceptance Criteria**:
- App initializes Identity Platform from sponsor-specific config file
- MFA can be enabled/required based on user role
- Authentication tokens scoped to single sponsor project
- Session refresh handled automatically
- Logout clears all authentication state
- Auth errors handled gracefully with user feedback

*End* *Identity Platform Configuration Per Sponsor* | **Hash**: b9283580
---

### Identity Platform (Per Sponsor)

**Each sponsor** has dedicated Identity Platform instance providing:
- User registration and login
- Identity Platform ID token generation
- Session management
- Password policies
- Multi-factor authentication (2FA)

**Supported Authentication Methods**:
- Email + password
- Magic link (passwordless email)
- OAuth providers (Google, Apple, Microsoft)
- SAML/SSO (enterprise sponsors)

### Flutter Identity Platform Integration

**pubspec.yaml dependencies**:
```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
```

**Initialize Firebase** (lib/config/firebase_config.dart):

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConfig {
  static late FirebaseApp _app;
  static late FirebaseAuth _auth;

  /// Initialize Firebase with sponsor-specific configuration
  static Future<void> initialize({
    required String projectId,
    required String apiKey,
    required String appId,
    String? messagingSenderId,
  }) async {
    _app = await Firebase.initializeApp(
      options: FirebaseOptions(
        projectId: projectId,
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId ?? '',
      ),
    );
    _auth = FirebaseAuth.instanceFor(app: _app);
  }

  static FirebaseAuth get auth => _auth;

  /// Get current user's ID token for API calls
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Sign out and clear session
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

### JWT Token Structure

**Claims in Identity Platform ID Token** (custom claims set via Cloud Functions):

```json
{
  "sub": "user_firebase_uid",
  "email": "user@example.com",
  "role": "INVESTIGATOR",
  "sponsor_id": "sponsor_abc",
  "site_id": "site_001",
  "site_assignments": ["site_001", "site_002"],
  "mfa_verified": true,
  "iss": "https://securetoken.google.com/project-id",
  "aud": "project-id",
  "exp": 1700000000,
  "iat": 1699996400
}
```

**JWT Usage**:
- Generated on login
- Included in all API requests (Authorization header)
- Validated by Dart server middleware
- Custom claims set session variables for RLS
- Scoped to single sponsor (cannot cross sponsors)

---

### Token Verification in Dart Server

**Firebase Admin SDK verification** (lib/auth/token_verifier.dart):

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class FirebaseTokenVerifier {
  final String projectId;
  Map<String, dynamic>? _publicKeys;
  DateTime? _keysExpiry;

  FirebaseTokenVerifier({required this.projectId});

  /// Verify Identity Platform ID token
  Future<Map<String, dynamic>> verifyIdToken(String idToken) async {
    // Decode token without verification first
    final parts = idToken.split('.');
    if (parts.length != 3) {
      throw AuthException('Invalid token format');
    }

    final header = _decodeBase64(parts[0]);
    final payload = _decodeBase64(parts[1]);

    // Verify token claims
    _verifyTokenClaims(payload);

    // Verify signature with Google's public keys
    await _verifySignature(idToken, header['kid'] as String);

    return payload;
  }

  void _verifyTokenClaims(Map<String, dynamic> payload) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check expiration
    final exp = payload['exp'] as int?;
    if (exp == null || exp < now) {
      throw AuthException('Token expired');
    }

    // Check issued at
    final iat = payload['iat'] as int?;
    if (iat == null || iat > now) {
      throw AuthException('Token issued in future');
    }

    // Check audience
    final aud = payload['aud'] as String?;
    if (aud != projectId) {
      throw AuthException('Invalid audience');
    }

    // Check issuer
    final iss = payload['iss'] as String?;
    if (iss != 'https://securetoken.google.com/$projectId') {
      throw AuthException('Invalid issuer');
    }

    // Check subject exists
    final sub = payload['sub'] as String?;
    if (sub == null || sub.isEmpty) {
      throw AuthException('Missing subject');
    }
  }

  Future<void> _verifySignature(String token, String keyId) async {
    // Fetch and cache Google's public keys
    if (_publicKeys == null || _keysExpiry?.isBefore(DateTime.now()) == true) {
      await _fetchPublicKeys();
    }

    final publicKey = _publicKeys![keyId];
    if (publicKey == null) {
      throw AuthException('Unknown key ID');
    }

    // Verify RS256 signature
    // Implementation depends on crypto library (e.g., pointycastle)
    // For production, use firebase_admin package or verify with Google API
  }

  Future<void> _fetchPublicKeys() async {
    final response = await http.get(Uri.parse(
      'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
    ));

    if (response.statusCode != 200) {
      throw AuthException('Failed to fetch public keys');
    }

    _publicKeys = jsonDecode(response.body) as Map<String, dynamic>;

    // Parse cache-control header for expiry
    final cacheControl = response.headers['cache-control'];
    if (cacheControl != null) {
      final maxAge = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAge != null) {
        final seconds = int.parse(maxAge.group(1)!);
        _keysExpiry = DateTime.now().add(Duration(seconds: seconds));
      }
    }
  }

  Map<String, dynamic> _decodeBase64(String str) {
    var normalized = str.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final decoded = base64.decode(normalized);
    return jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
```

### Auth Middleware for Shelf Server

```dart
import 'package:shelf/shelf.dart';
import 'token_verifier.dart';
import '../database/rls_context.dart';

/// Middleware that verifies Identity Platform ID tokens and sets RLS context
Middleware firebaseAuthMiddleware(FirebaseTokenVerifier verifier) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Skip auth for health checks
      if (request.url.path == 'health' || request.url.path == 'ready') {
        return innerHandler(request);
      }

      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'error': 'Missing authorization header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final token = authHeader.substring(7);

      try {
        final claims = await verifier.verifyIdToken(token);

        // Create RLS context from token claims
        final rlsContext = RlsContext(
          userId: claims['sub'] as String,
          role: claims['role'] as String? ?? 'USER',
          siteId: claims['site_id'] as String?,
          sponsorId: claims['sponsor_id'] as String,
        );

        // Add to request context for downstream handlers
        final updatedRequest = request.change(
          context: {
            ...request.context,
            'claims': claims,
            'rlsContext': rlsContext,
            'userId': claims['sub'],
          },
        );

        return innerHandler(updatedRequest);
      } on AuthException catch (e) {
        return Response.forbidden(
          jsonEncode({'error': e.message}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Authentication failed'}),
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}
```

---

### Password Requirements

**Standard Users** (Patients):
- Minimum 8 characters
- Mix of letters and numbers recommended

**Privileged Users** (Investigators, Admins):
- Minimum 12 characters
- Uppercase, lowercase, number, special character required
- Cannot be common password (dictionary check)
- Expiry: 90 days (configurable per sponsor)

### Multi-Factor Authentication (2FA)

# REQ-d00008: MFA Enrollment and Verification Implementation

**Level**: Dev | **Implements**: o00006 | **Status**: Draft

The application SHALL implement multi-factor authentication enrollment and verification flows using Identity Platform's MFA capabilities, enforcing additional authentication factor for clinical staff, administrators, and sponsor personnel.

Implementation SHALL include:
- MFA enrollment UI displaying QR code for TOTP authenticator app registration
- TOTP verification code input and validation
- MFA status tracking in user profile
- Grace period handling (max 7 days) for initial MFA enrollment
- MFA verification required at each login for enrolled users
- Error handling for invalid codes with rate limiting
Implementation MAY include:
- Backup code generation and secure storage (for lost passwords)

**Rationale**: Implements MFA configuration (o00006) at the application code level. Identity Platform provides TOTP-based MFA capabilities that require application integration for enrollment and verification flows.

**Acceptance Criteria**:
- MFA enrollment flow displays QR code and verifies first code
- Staff accounts cannot bypass MFA after grace period expires
- MFA verification required at each login session
- Backup codes generated and securely stored
- Invalid code attempts rate limited (max 5 per minute)
- MFA events logged in authentication audit trail

*End* *MFA Enrollment and Verification Implementation* | **Hash**: e179439d
---

**MFA Implementation in Flutter**:

```dart
import 'package:firebase_auth/firebase_auth.dart';

class MfaService {
  final FirebaseAuth _auth;

  MfaService(this._auth);

  /// Enroll user in TOTP MFA
  Future<TotpEnrollment> startTotpEnrollment() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Not authenticated');

    // Start multi-factor enrollment
    final session = await user.multiFactor.getSession();

    // Generate TOTP secret for authenticator app
    final totpSecret = await TotpMultiFactorGenerator.generateSecret(session);

    return TotpEnrollment(
      secretKey: totpSecret.secretKey,
      qrCodeUrl: totpSecret.generateQrCodeUrl(
        user.email ?? 'user',
        'ClinicalDiary',
      ),
    );
  }

  /// Complete TOTP enrollment with verification code
  Future<void> completeTotpEnrollment(
    String verificationCode,
    TotpSecret totpSecret,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Not authenticated');

    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      totpSecret,
      verificationCode,
    );

    await user.multiFactor.enroll(
      assertion,
      displayName: 'Authenticator App',
    );
  }

  /// Verify MFA code during sign-in
  Future<UserCredential> verifyMfaCode(
    MultiFactorResolver resolver,
    String verificationCode,
  ) async {
    final hint = resolver.hints.first;

    if (hint is TotpMultiFactorInfo) {
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        hint.uid,
        verificationCode,
      );
      return resolver.resolveSignIn(assertion);
    }

    throw AuthException('Unsupported MFA type');
  }

  /// Check if MFA is required for user role
  bool isMfaRequired(String role) {
    const mfaRequiredRoles = [
      'INVESTIGATOR',
      'SPONSOR',
      'AUDITOR',
      'ADMINISTRATOR',
      'DEVELOPER_ADMIN',
    ];
    return mfaRequiredRoles.contains(role);
  }

  /// Check if user has MFA enabled
  Future<bool> hasMfaEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.isNotEmpty;
  }
}

class TotpEnrollment {
  final String secretKey;
  final String qrCodeUrl;

  TotpEnrollment({required this.secretKey, required this.qrCodeUrl});
}
```

---

### Session Management

**Session Properties**:
- Identity Platform ID token based (stateless)
- Token expiry: 1 hour (auto-refreshed)
- Refresh token: Long-lived (managed by Identity Platform SDK)
- Explicit logout clears all tokens

**Session Security**:
- Secure storage on mobile (flutter_secure_storage)
- Token refresh handled by Identity Platform SDK
- Session invalidation on password change
- Concurrent session limits via Cloud Functions

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureSessionManager {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'firebase_id_token';
  static const _refreshKey = 'firebase_refresh_token';

  /// Store tokens securely
  static Future<void> storeTokens(User user) async {
    final idToken = await user.getIdToken();
    await _storage.write(key: _tokenKey, value: idToken);
    // Note: refresh token is managed by Identity Platform SDK internally
  }

  /// Clear all stored tokens
  static Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await FirebaseAuth.instance.signOut();
  }

  /// Get current ID token (refreshes if needed)
  static Future<String?> getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // This automatically refreshes if token is expired
    return user.getIdToken();
  }
}
```

---

## Authorization Layer 1: Role-Based Access Control (RBAC)

# REQ-d00009: Role-Based Permission Enforcement Implementation

**Level**: Dev | **Implements**: o00007 | **Status**: Draft

The application SHALL implement role-based permission enforcement by reading user roles from Identity Platform ID token claims and restricting UI features and API calls based on role permissions, ensuring consistent access control across mobile and web applications.

Implementation SHALL include:
- Role extraction from JWT claims after authentication
- Permission check functions evaluating role against required permission
- UI component visibility control based on user role (hiding unauthorized features)
- API request authorization headers including role information
- Active role/site context selection for multi-role users
- Permission-denied error handling with user-friendly messages
- Role-based navigation routing (different home screens per role)

**Rationale**: Implements role-based permission configuration (o00007) at the application code level. While database RLS enforces data access control, application-level RBAC prevents unauthorized API calls and improves user experience by hiding inaccessible features.

**Acceptance Criteria**:
- User role correctly extracted from JWT claims
- UI features hidden for unauthorized roles
- API calls include role authorization headers
- Permission denied errors handled gracefully
- Multi-role users can switch active role context
- Role changes reflected immediately in UI
- Unauthorized navigation routes redirect to role-appropriate screen

*End* *Role-Based Permission Enforcement Implementation* | **Hash**: 3dafc77d
---

### Role Hierarchy

The system defines **7 roles** with specific permissions:

1. **Patient (USER)** - Study participants
2. **Investigator** - Clinical site staff
3. **Sponsor** - Trial sponsor organization
4. **Auditor** - Compliance monitoring
5. **Analyst** - Data analysis (read-only)
6. **Administrator** - System configuration
7. **Developer Admin** - Infrastructure operations

**See**: prd-security-RBAC.md for complete role definitions, permissions matrix, and user stories

### Permission Service Implementation

```dart
enum Permission {
  readOwnData,
  writeOwnData,
  readSiteData,
  writeSiteData,
  readAllData,
  writeAllData,
  manageUsers,
  manageRoles,
  viewAuditLogs,
  manageSites,
  exportData,
}

class PermissionService {
  static const Map<String, Set<Permission>> rolePermissions = {
    'USER': {
      Permission.readOwnData,
      Permission.writeOwnData,
    },
    'INVESTIGATOR': {
      Permission.readOwnData,
      Permission.readSiteData,
      Permission.viewAuditLogs,
    },
    'ANALYST': {
      Permission.readSiteData,
      Permission.exportData,
    },
    'SPONSOR': {
      Permission.readAllData,
      Permission.viewAuditLogs,
      Permission.manageUsers,
    },
    'AUDITOR': {
      Permission.readAllData,
      Permission.viewAuditLogs,
    },
    'ADMINISTRATOR': {
      Permission.readAllData,
      Permission.writeAllData,
      Permission.manageUsers,
      Permission.manageRoles,
      Permission.viewAuditLogs,
      Permission.manageSites,
    },
    'DEVELOPER_ADMIN': {
      Permission.readAllData,
      Permission.writeAllData,
      Permission.manageUsers,
      Permission.manageRoles,
      Permission.viewAuditLogs,
      Permission.manageSites,
      Permission.exportData,
    },
  };

  final String currentRole;

  PermissionService(this.currentRole);

  bool hasPermission(Permission permission) {
    return rolePermissions[currentRole]?.contains(permission) ?? false;
  }

  bool canAccessSite(String siteId, List<String> assignedSites) {
    if (hasPermission(Permission.readAllData)) return true;
    return assignedSites.contains(siteId);
  }
}
```

### UI Permission Guards in Flutter

```dart
import 'package:flutter/material.dart';

class PermissionGuard extends StatelessWidget {
  final Permission required;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.required,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService = context.watch<PermissionService>();

    if (permissionService.hasPermission(required)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Usage example
class DiaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Always visible
        DiaryEntryList(),

        // Only visible to users who can write
        PermissionGuard(
          required: Permission.writeOwnData,
          child: AddEntryButton(),
        ),

        // Only visible to investigators
        PermissionGuard(
          required: Permission.readSiteData,
          child: SiteDataSection(),
        ),
      ],
    );
  }
}
```

---

## Authorization Layer 2: Row-Level Security (RLS)

### Database-Enforced Access Control

**PostgreSQL RLS** policies enforce access control **at the database level**, ensuring application code cannot bypass restrictions.

**Key Features**:
- Automatic query filtering based on session variables
- Cannot be disabled by application
- Policies evaluated on every database operation
- Independent of application logic

### Setting RLS Context from JWT Claims

The Dart server extracts claims from the verified Identity Platform token and sets PostgreSQL session variables:

```dart
class RlsContext {
  final String userId;
  final String role;
  final String? siteId;
  final String sponsorId;

  RlsContext({
    required this.userId,
    required this.role,
    this.siteId,
    required this.sponsorId,
  });

  /// Set RLS context for database session
  Future<void> apply(Connection connection) async {
    await connection.execute(
      Sql.named('''
        SELECT set_config('app.user_id', @userId, true),
               set_config('app.role', @role, true),
               set_config('app.site_id', @siteId, true),
               set_config('app.sponsor_id', @sponsorId, true)
      '''),
      parameters: {
        'userId': userId,
        'role': role,
        'siteId': siteId ?? '',
        'sponsorId': sponsorId,
      },
    );
  }

  /// Create from verified Identity Platform token claims
  factory RlsContext.fromClaims(Map<String, dynamic> claims) {
    return RlsContext(
      userId: claims['sub'] as String,
      role: claims['role'] as String? ?? 'USER',
      siteId: claims['site_id'] as String?,
      sponsorId: claims['sponsor_id'] as String,
    );
  }
}
```

### RLS Policy Examples

**User Data Isolation**:
```sql
CREATE POLICY user_select_own ON record_state
  FOR SELECT
  USING (patient_id = current_setting('app.user_id', true));

CREATE POLICY user_insert_own ON record_audit
  FOR INSERT
  WITH CHECK (patient_id = current_setting('app.user_id', true));
```

**Site-Scoped Access**:
```sql
CREATE POLICY investigator_select_site ON record_state
  FOR SELECT
  USING (
    current_setting('app.role', true) = 'INVESTIGATOR'
    AND site_id = current_setting('app.site_id', true)
  );
```

**See**: prd-security-RLS.md for complete RLS policy specifications

---

## GCP IAM Integration

### Service Account Configuration

Each Cloud Run service uses a dedicated service account with minimal permissions:

```dart
// Environment configuration for Cloud Run
class GcpConfig {
  /// Project ID from metadata server or environment
  static Future<String> getProjectId() async {
    // Try environment first
    final envProject = Platform.environment['GCP_PROJECT_ID'];
    if (envProject != null) return envProject;

    // Fall back to metadata server (in Cloud Run)
    final response = await http.get(
      Uri.parse('http://metadata.google.internal/computeMetadata/v1/project/project-id'),
      headers: {'Metadata-Flavor': 'Google'},
    );
    return response.body;
  }

  /// Service account email from metadata server
  static Future<String> getServiceAccountEmail() async {
    final response = await http.get(
      Uri.parse('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'),
      headers: {'Metadata-Flavor': 'Google'},
    );
    return response.body;
  }
}
```

### Workload Identity for GKE/Cloud Run

Cloud Run automatically provides identity through the service account attached to the service. No key files needed:

```dart
import 'package:googleapis_auth/auth_io.dart';

class GcpAuth {
  /// Get authenticated client using Application Default Credentials
  static Future<AutoRefreshingAuthClient> getAuthenticatedClient(
    List<String> scopes,
  ) async {
    // Uses service account attached to Cloud Run or local ADC
    return clientViaApplicationDefaultCredentials(scopes: scopes);
  }

  /// Access Secret Manager
  static Future<String> getSecret(String secretId) async {
    final client = await getAuthenticatedClient([
      'https://www.googleapis.com/auth/cloud-platform',
    ]);

    final projectId = await GcpConfig.getProjectId();
    final url = 'https://secretmanager.googleapis.com/v1/'
        'projects/$projectId/secrets/$secretId/versions/latest:access';

    final response = await client.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to access secret: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final payload = data['payload']['data'] as String;
    return utf8.decode(base64.decode(payload));
  }
}
```

---

## Encryption Implementation

# REQ-d00010: Data Encryption Implementation

**Level**: Dev | **Implements**: p00017 | **Status**: Draft

The application SHALL implement data encryption at rest and in transit using platform-provided encryption capabilities, ensuring all clinical trial data is protected from unauthorized access during storage and transmission.

Implementation SHALL include:
- TLS/SSL configuration for all HTTP connections (HTTPS enforced)
- Secure local storage encryption for SQLite database on mobile devices
- Platform keychain/keystore usage for authentication token storage
- TLS certificate validation preventing man-in-the-middle attacks
- Encrypted backup files for local data
- No plaintext storage of sensitive configuration values

**Rationale**: Implements data encryption requirement (p00017) at the application code level. Cloud SQL provides database-level encryption at rest, while application must ensure encrypted transit (TLS) and secure local storage on mobile devices.

**Acceptance Criteria**:
- All API requests use HTTPS (TLS 1.2 or higher)
- SQLite database encrypted on device using platform encryption
- Authentication tokens stored in secure keychain (iOS Keychain, Android Keystore)
- TLS certificate validation enabled and tested
- Local backups encrypted with device encryption key
- No sensitive data logged in plaintext

*End* *Data Encryption Implementation* | **Hash**: d2d03aa8
---

### Transport Security

```dart
import 'package:http/http.dart' as http;
import 'dart:io';

class SecureHttpClient {
  static http.Client create() {
    // Create client with certificate validation
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        // In production, always return false to reject bad certs
        // Only allow exceptions in development
        assert(() {
          print('Certificate error for $host: ${cert.issuer}');
          return true;
        }());
        return false;
      };

    return IOClient(httpClient);
  }

  /// Make authenticated request with ID token
  static Future<http.Response> authenticatedGet(
    String url, {
    required String idToken,
  }) async {
    final client = create();

    return client.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );
  }
}
```

### Secure Local Storage

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Store sensitive value
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read sensitive value
  static Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  /// Delete sensitive value
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

class EncryptedDatabase {
  static Database? _database;

  /// Initialize encrypted SQLite database
  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    // Get or generate encryption key
    var key = await SecureStorage.read('db_encryption_key');
    if (key == null) {
      key = _generateEncryptionKey();
      await SecureStorage.write('db_encryption_key', key);
    }

    _database = await openDatabase(
      'clinical_diary.db',
      password: key,
      version: 1,
      onCreate: (db, version) async {
        // Create tables
        await db.execute('''
          CREATE TABLE diary_entries (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );

    return _database!;
  }

  static String _generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
}
```

---

## Security Testing

### Authentication Tests

```dart
import 'package:test/test.dart';

void main() {
  group('Identity Platform Token Verification', () {
    late FirebaseTokenVerifier verifier;

    setUp(() {
      verifier = FirebaseTokenVerifier(projectId: 'test-project');
    });

    test('rejects expired token', () async {
      final expiredToken = createTestToken(
        exp: DateTime.now().subtract(Duration(hours: 1)),
      );

      expect(
        () => verifier.verifyIdToken(expiredToken),
        throwsA(isA<AuthException>()),
      );
    });

    test('rejects wrong audience', () async {
      final wrongAudToken = createTestToken(aud: 'wrong-project');

      expect(
        () => verifier.verifyIdToken(wrongAudToken),
        throwsA(isA<AuthException>()),
      );
    });

    test('accepts valid token', () async {
      final validToken = createTestToken(
        sub: 'user123',
        role: 'USER',
        sponsorId: 'sponsor-abc',
      );

      final claims = await verifier.verifyIdToken(validToken);

      expect(claims['sub'], equals('user123'));
      expect(claims['role'], equals('USER'));
    });
  });

  group('Permission Service', () {
    test('USER has read/write own data', () {
      final service = PermissionService('USER');

      expect(service.hasPermission(Permission.readOwnData), isTrue);
      expect(service.hasPermission(Permission.writeOwnData), isTrue);
      expect(service.hasPermission(Permission.readSiteData), isFalse);
    });

    test('INVESTIGATOR has site-scoped access', () {
      final service = PermissionService('INVESTIGATOR');

      expect(service.hasPermission(Permission.readSiteData), isTrue);
      expect(service.hasPermission(Permission.writeAllData), isFalse);
    });

    test('ADMINISTRATOR has full access', () {
      final service = PermissionService('ADMINISTRATOR');

      expect(service.hasPermission(Permission.readAllData), isTrue);
      expect(service.hasPermission(Permission.writeAllData), isTrue);
      expect(service.hasPermission(Permission.manageUsers), isTrue);
    });
  });
}
```

### RLS Policy Tests

```sql
-- Test user isolation
DO $$
DECLARE
  test_uuid UUID := gen_random_uuid();
BEGIN
  -- Set context as user1
  PERFORM set_config('app.user_id', 'user1', true);
  PERFORM set_config('app.role', 'USER', true);

  -- Insert as user1
  INSERT INTO record_audit (event_uuid, patient_id, site_id, operation, data, created_by, role, client_timestamp, change_reason)
  VALUES (test_uuid, 'user1', 'site1', 'CREATE', '{"test": true}'::jsonb, 'user1', 'USER', now(), 'Test');

  -- Verify user1 can read
  IF NOT EXISTS (SELECT 1 FROM record_state WHERE patient_id = 'user1') THEN
    RAISE EXCEPTION 'User cannot read own data';
  END IF;

  -- Switch to user2
  PERFORM set_config('app.user_id', 'user2', true);

  -- Verify user2 cannot see user1's data
  IF EXISTS (SELECT 1 FROM record_state WHERE patient_id = 'user1') THEN
    RAISE EXCEPTION 'User can see other user data - RLS failure!';
  END IF;

  RAISE NOTICE 'RLS test passed';
END $$;
```

---

## Developer Responsibilities

### Secure Implementation Checklist

**Required**:
- ✅ Always use Identity Platform / Identity Platform for authentication
- ✅ Never bypass RLS policies
- ✅ Validate Identity Platform ID token on every API request
- ✅ Use parameterized queries (no SQL injection)
- ✅ Never log authentication tokens
- ✅ Use TLS for all connections
- ✅ Store tokens in secure storage only

**Forbidden**:
- ❌ Storing passwords in plain text
- ❌ Custom authentication schemes
- ❌ Client-side only authorization checks
- ❌ Disabling RLS for convenience
- ❌ Storing service account keys in code
- ❌ Logging sensitive data (tokens, PHI)

---

## References

- **Role Definitions**: prd-security-RBAC.md
- **RLS Policies**: prd-security-RLS.md
- **Data Privacy**: prd-security-data-classification.md
- **Security Operations**: ops-security.md
- **Authentication Setup**: ops-security-authentication.md
- **Identity Platform Docs**: https://cloud.google.com/identity-platform/docs
- **Identity Platform Flutter**: https://firebase.google.com/docs/auth/flutter/start

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 2.0 | 2025-11-24 | Migration to GCP Identity Platform | Development Team |
| 1.0 | 2025-01-24 | Initial security implementation guide | Development Team |

---

**Document Classification**: Internal Use - Security Implementation
**Review Frequency**: Quarterly or after security incidents
**Owner**: Security Team / Technical Lead
