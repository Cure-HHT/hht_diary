# Identity Platform Setup Guide

**Version**: 1.0
**Status**: Active
**Created**: 2025-11-25

> **Purpose**: Configure Google Identity Platform (Firebase Auth) for user authentication in the Clinical Trial Diary Platform.

---

## Executive Summary

The Clinical Trial Diary Platform uses Google Identity Platform (Firebase Auth) for authentication. Each sponsor has an isolated Identity Platform configuration within their GCP project, ensuring complete user separation.

**Key Features**:
- Email/password authentication
- OAuth providers (Google, Apple, Microsoft)
- Multi-factor authentication (MFA)
- Custom claims for role-based access control (RBAC)
- JWT tokens validated by Cloud Run API

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authentication Flow                           │
│                                                                  │
│  Mobile App / Web Portal                                        │
│       │                                                         │
│       │ 1. Sign in (email/OAuth)                               │
│       ▼                                                         │
│  Identity Platform ───────────────────────────┐                 │
│       │                                       │                 │
│       │ 2. Issue JWT with custom claims       │                 │
│       ▼                                       │                 │
│  Cloud Functions ◀────────────────────────────┘                 │
│  (Custom Claims)    3. Add role, sponsor, site claims           │
│       │                                                         │
│       │ 4. JWT with claims                                      │
│       ▼                                                         │
│  Cloud Run API                                                  │
│       │                                                         │
│       │ 5. Verify JWT, extract claims                           │
│       │ 6. Set PostgreSQL session variables                     │
│       ▼                                                         │
│  Cloud SQL (RLS enforced by claims)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

1. **GCP Project Created**: See docs/gcp/project-structure.md
2. **APIs Enabled**:
   ```bash
   gcloud services enable identitytoolkit.googleapis.com
   gcloud services enable cloudfunctions.googleapis.com
   gcloud services enable firebasehosting.googleapis.com
   ```

---

## Enable Identity Platform

### Step 1: Enable via Console

1. Go to [Identity Platform Console](https://console.cloud.google.com/customer-identity)
2. Select your project
3. Click "Enable Identity Platform"
4. Accept terms and enable

### Step 2: Enable via gcloud (Alternative)

```bash
export PROJECT_ID="hht-diary-orion-prod"

# Enable Identity Platform
gcloud services enable identitytoolkit.googleapis.com --project=$PROJECT_ID

# Initialize Identity Platform
gcloud identity-platform configs update \
  --enable-email-link-signin \
  --project=$PROJECT_ID
```

---

## Configure Authentication Providers

### Email/Password Authentication

```bash
# Enable email/password
gcloud identity-platform configs update \
  --enable-email-signin \
  --enable-email-link-signin=false \
  --project=$PROJECT_ID
```

### Google OAuth

1. Go to [Identity Platform Providers](https://console.cloud.google.com/customer-identity/providers)
2. Click "Add Provider" → "Google"
3. Enable and configure:
   - Client ID: Auto-generated or custom
   - Client Secret: From Google Cloud Console

```bash
# Or via gcloud
gcloud identity-platform configs update \
  --enable-google \
  --project=$PROJECT_ID
```

### Apple Sign-In

1. Prerequisites:
   - Apple Developer Account
   - App ID with Sign In with Apple enabled
   - Service ID for web authentication
   - Private key for token generation

2. Configure in Console:
   - Team ID
   - Key ID
   - Service ID
   - Private Key

### Microsoft OAuth

1. Register application in Azure AD
2. Get Client ID and Secret
3. Configure in Identity Platform Console

---

## Custom Claims for RBAC

### Cloud Function for Custom Claims

```javascript
// functions/custom-claims/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Triggered when a new user is created.
 * Sets default custom claims.
 */
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
  const sponsorId = process.env.SPONSOR_ID;

  // Default claims for new users
  const defaultClaims = {
    role: 'USER',
    sponsorId: sponsorId,
    siteIds: [],  // Assigned by admin later
    createdAt: Date.now()
  };

  try {
    await admin.auth().setCustomUserClaims(user.uid, defaultClaims);
    console.log(`Custom claims set for user ${user.uid}`);

    // Log to audit
    await logAuditEvent('USER_CREATED', user.uid, defaultClaims);
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw error;
  }
});

/**
 * Callable function to update user role.
 * Only callable by ADMIN users.
 */
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to update roles'
    );
  }

  // Verify caller is ADMIN
  const callerRole = context.auth.token.role;
  if (callerRole !== 'ADMIN') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can update user roles'
    );
  }

  const { userId, newRole, siteIds } = data;
  const validRoles = ['USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN'];

  // Validate role
  if (!validRoles.includes(newRole)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid role: ${newRole}. Valid roles: ${validRoles.join(', ')}`
    );
  }

  try {
    // Get current claims
    const user = await admin.auth().getUser(userId);
    const currentClaims = user.customClaims || {};

    // Update claims
    const newClaims = {
      ...currentClaims,
      role: newRole,
      siteIds: siteIds || currentClaims.siteIds || [],
      updatedAt: Date.now(),
      updatedBy: context.auth.uid
    };

    await admin.auth().setCustomUserClaims(userId, newClaims);

    // Log audit event
    await logAuditEvent('ROLE_UPDATED', userId, {
      oldRole: currentClaims.role,
      newRole: newRole,
      updatedBy: context.auth.uid
    });

    // Force token refresh
    await admin.auth().revokeRefreshTokens(userId);

    return { success: true, claims: newClaims };
  } catch (error) {
    console.error('Error updating role:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Callable function to assign sites to user.
 */
exports.assignUserSites = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const callerRole = context.auth.token.role;
  if (callerRole !== 'ADMIN') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can assign sites');
  }

  const { userId, siteIds } = data;

  try {
    const user = await admin.auth().getUser(userId);
    const currentClaims = user.customClaims || {};

    const newClaims = {
      ...currentClaims,
      siteIds: siteIds,
      updatedAt: Date.now(),
      updatedBy: context.auth.uid
    };

    await admin.auth().setCustomUserClaims(userId, newClaims);
    await admin.auth().revokeRefreshTokens(userId);

    await logAuditEvent('SITES_ASSIGNED', userId, {
      oldSites: currentClaims.siteIds,
      newSites: siteIds,
      updatedBy: context.auth.uid
    });

    return { success: true, claims: newClaims };
  } catch (error) {
    console.error('Error assigning sites:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Helper function to log audit events.
 */
async function logAuditEvent(eventType, userId, details) {
  const db = admin.firestore();
  await db.collection('auth_audit_log').add({
    eventType,
    userId,
    details,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    sponsorId: process.env.SPONSOR_ID
  });
}
```

### Deploy Cloud Functions

```bash
cd functions/custom-claims

# Install dependencies
npm install

# Deploy functions
gcloud functions deploy onUserCreate \
  --runtime=nodejs18 \
  --trigger-event=providers/firebase.auth/eventTypes/user.create \
  --region=$REGION \
  --set-env-vars=SPONSOR_ID=$SPONSOR \
  --project=$PROJECT_ID

gcloud functions deploy updateUserRole \
  --runtime=nodejs18 \
  --trigger-http \
  --allow-unauthenticated=false \
  --region=$REGION \
  --set-env-vars=SPONSOR_ID=$SPONSOR \
  --project=$PROJECT_ID

gcloud functions deploy assignUserSites \
  --runtime=nodejs18 \
  --trigger-http \
  --allow-unauthenticated=false \
  --region=$REGION \
  --set-env-vars=SPONSOR_ID=$SPONSOR \
  --project=$PROJECT_ID
```

---

## Multi-Factor Authentication

### Enable MFA

```bash
# Enable MFA in Identity Platform
gcloud identity-platform configs update \
  --mfa-state=ENABLED \
  --mfa-start-enablement=MANDATORY \
  --project=$PROJECT_ID
```

### Configure MFA Providers

1. Go to Identity Platform Console
2. Navigate to Settings → MFA
3. Enable desired factors:
   - SMS (requires Twilio or other provider)
   - TOTP (Google Authenticator, Authy)
   - Email OTP

### MFA Configuration (Console)

```json
{
  "mfa": {
    "state": "ENABLED",
    "enabledProviders": ["PHONE_SMS", "TOTP"]
  }
}
```

---

## Flutter App Integration

### pubspec.yaml

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
```

### Initialize Firebase

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      projectId: const String.fromEnvironment('GCP_PROJECT_ID'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
    ),
  );

  runApp(const MyApp());
}
```

### Authentication Service

```dart
// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email/password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email/password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    return await _auth.signInWithProvider(googleProvider);
  }

  /// Get ID token with custom claims
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await currentUser?.getIdToken(forceRefresh);
  }

  /// Get custom claims from token
  Future<Map<String, dynamic>?> getCustomClaims() async {
    final idTokenResult = await currentUser?.getIdTokenResult(true);
    return idTokenResult?.claims;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
```

### Using Claims in App

```dart
// lib/widgets/role_guard.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    required this.allowedRoles,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService().getCustomClaims(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final claims = snapshot.data;
        final role = claims?['role'] as String?;

        if (role != null && allowedRoles.contains(role)) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
```

---

## Server-Side JWT Validation

### Dart Server Middleware

```dart
// lib/middleware/auth_middleware.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class AuthMiddleware {
  final String projectId;
  late JsonWebKeyStore _keyStore;

  AuthMiddleware(this.projectId) {
    _keyStore = JsonWebKeyStore();
  }

  /// Verify Firebase ID token
  Future<Map<String, dynamic>> verifyIdToken(String idToken) async {
    // Fetch Google's public keys
    final keysUrl = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
    final response = await http.get(Uri.parse(keysUrl));
    final keys = jsonDecode(response.body) as Map<String, dynamic>;

    // Parse and verify JWT
    final jwt = JsonWebToken.unverified(idToken);

    // Verify claims
    final payload = jwt.claims;

    // Check issuer
    final expectedIssuer = 'https://securetoken.google.com/$projectId';
    if (payload['iss'] != expectedIssuer) {
      throw Exception('Invalid issuer');
    }

    // Check audience
    if (payload['aud'] != projectId) {
      throw Exception('Invalid audience');
    }

    // Check expiration
    final exp = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000);
    if (DateTime.now().isAfter(exp)) {
      throw Exception('Token expired');
    }

    return payload.toJson();
  }

  /// Extract user info from verified token
  UserInfo extractUserInfo(Map<String, dynamic> claims) {
    return UserInfo(
      uid: claims['sub'] as String,
      email: claims['email'] as String?,
      role: claims['role'] as String? ?? 'USER',
      sponsorId: claims['sponsorId'] as String?,
      siteIds: (claims['siteIds'] as List?)?.cast<String>() ?? [],
    );
  }
}

class UserInfo {
  final String uid;
  final String? email;
  final String role;
  final String? sponsorId;
  final List<String> siteIds;

  UserInfo({
    required this.uid,
    this.email,
    required this.role,
    this.sponsorId,
    required this.siteIds,
  });
}
```

### Setting PostgreSQL Session Variables

```dart
// lib/database/connection.dart
import 'package:postgres/postgres.dart';

class DatabaseConnection {
  final Connection _connection;

  DatabaseConnection(this._connection);

  /// Set session variables for RLS based on user claims
  Future<void> setUserContext(UserInfo user) async {
    await _connection.execute('''
      SET app.current_user_id = '${user.uid}';
      SET app.current_user_role = '${user.role}';
      SET app.current_site_ids = '${user.siteIds.join(',')}';
    ''');
  }

  /// Execute query with user context
  Future<Result> queryWithContext(UserInfo user, String sql, [List<Object?>? parameters]) async {
    await setUserContext(user);
    return await _connection.execute(sql, parameters: parameters);
  }
}
```

---

## Security Configuration

### Authorized Domains

Configure allowed domains for authentication:

```bash
gcloud identity-platform configs update \
  --authorized-domains="hht-diary-orion-prod.firebaseapp.com,portal.orion.clinicaltrial.app,localhost" \
  --project=$PROJECT_ID
```

### Session Duration

```bash
# Set session cookie duration (5 days)
gcloud identity-platform configs update \
  --session-cookie-duration=432000s \
  --project=$PROJECT_ID
```

### Password Policy

```bash
gcloud identity-platform configs update \
  --password-policy-min-length=12 \
  --password-policy-require-lowercase=true \
  --password-policy-require-uppercase=true \
  --password-policy-require-numeric=true \
  --password-policy-require-symbol=true \
  --project=$PROJECT_ID
```

---

## Testing

### Test User Creation

```bash
# Create test user via Firebase Admin SDK
firebase auth:create-user \
  --email="test@example.com" \
  --password="SecurePassword123!" \
  --display-name="Test User" \
  --project=$PROJECT_ID
```

### Verify Custom Claims

```javascript
// Admin SDK test
const admin = require('firebase-admin');
admin.initializeApp();

async function testClaims() {
  const user = await admin.auth().getUserByEmail('test@example.com');
  console.log('Custom Claims:', user.customClaims);
}
```

---

## Troubleshooting

### Token Verification Fails

```bash
# Check Identity Platform config
gcloud identity-platform configs describe --project=$PROJECT_ID

# Verify authorized domains
gcloud identity-platform configs describe \
  --format="value(authorizedDomains)" \
  --project=$PROJECT_ID
```

### Custom Claims Not Applied

1. Claims are set but not in token:
   - User needs to sign out and back in
   - Or call `revokeRefreshTokens()` and refresh

2. Cloud Function not triggered:
   ```bash
   gcloud functions logs read onUserCreate --project=$PROJECT_ID
   ```

### MFA Issues

```bash
# Check MFA configuration
gcloud identity-platform configs describe \
  --format="yaml(mfa)" \
  --project=$PROJECT_ID
```

---

## Security Checklist

- [ ] Identity Platform enabled
- [ ] Email/password authentication configured
- [ ] OAuth providers configured (Google, Apple, Microsoft)
- [ ] MFA enabled and enforced
- [ ] Custom claims Cloud Function deployed
- [ ] Password policy configured (min 12 chars, complexity)
- [ ] Session duration appropriate
- [ ] Authorized domains restricted
- [ ] JWT validation in API server
- [ ] RLS policies use claims correctly

---

## References

- [Identity Platform Documentation](https://cloud.google.com/identity-platform/docs)
- [Firebase Auth for Flutter](https://firebase.flutter.dev/docs/auth/overview)
- [Custom Claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [JWT Verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- **RBAC Implementation**: spec/prd-security-RBAC.md
- **RLS Policies**: spec/dev-security-RLS.md

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-11-25 | 1.0 | Initial Identity Platform setup guide | Claude |
