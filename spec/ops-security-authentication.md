# Authentication Operations Guide

**Version**: 2.0
**Audience**: Operations (Security Engineers, DevOps)
**Last Updated**: 2025-11-24
**Status**: Active

> **See**: prd-security.md for security requirements
> **See**: prd-security-RBAC.md for role-based access control
> **See**: ops-security.md for security operations
> **See**: dev-security.md for implementation details

---

## Executive Summary

Authentication configuration and operations guide for the Clinical Trial Diary Platform using Google Identity Platform (Firebase Auth). Each sponsor has an isolated Identity Platform tenant within their GCP project.

**Technology Stack**:
- **Provider**: Google Identity Platform (Firebase Auth)
- **Authentication Methods**: Email/password, Google OAuth, Apple Sign In, Magic Link
- **Token Format**: Firebase ID tokens (JWT)
- **MFA**: TOTP and SMS via Identity Platform
- **Custom Claims**: Set via Cloud Functions

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Authentication Flow                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │ Mobile App / │         │ Identity     │                     │
│  │ Portal       │────────▶│ Platform     │                     │
│  │              │         │ (per sponsor)│                     │
│  └──────────────┘         └──────┬───────┘                     │
│                                  │                              │
│                                  │ JWT (ID Token)               │
│                                  │ + Custom Claims              │
│                                  ▼                              │
│                           ┌──────────────┐                     │
│                           │ Cloud Run    │                     │
│                           │ API Server   │                     │
│                           └──────┬───────┘                     │
│                                  │                              │
│                                  │ Verify Token                 │
│                                  │ Set Session Variables        │
│                                  ▼                              │
│                           ┌──────────────┐                     │
│                           │ Cloud SQL    │                     │
│                           │ (RLS Active) │                     │
│                           └──────────────┘                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Requirements

# REQ-o00006: MFA Configuration for Staff Accounts

**Level**: Ops | **Implements**: p00002 | **Status**: Active

Multi-factor authentication SHALL be configured and enforced for all clinical staff, administrator, and sponsor personnel accounts, ensuring password-based authentication is augmented with additional verification.

MFA configuration SHALL include:
- MFA enrollment required before first system access
- TOTP (Time-based One-Time Password) support for authenticator apps
- SMS backup codes as fallback option
- MFA enforcement at authentication system level (Identity Platform)
- Grace period for MFA enrollment (max 7 days)
- MFA reset procedures for lost devices

**Rationale**: Implements MFA requirement (p00002) at the operational configuration level. Identity Platform provides MFA capabilities that must be enabled and enforced per sponsor project.

**Acceptance Criteria**:
- MFA enabled in Identity Platform settings per sponsor
- Staff accounts cannot access system without completing MFA enrollment
- MFA verification required at each login
- MFA bypass not possible through configuration
- MFA events logged in audit trail

*End* *MFA Configuration for Staff Accounts* | **Hash**: 16f074eb
---

## Identity Platform Setup

### Enable Identity Platform

```bash
# Enable Identity Platform API
gcloud services enable identitytoolkit.googleapis.com

# Enable Identity Platform in GCP Console
# https://console.cloud.google.com/customer-identity
```

### Configure Authentication Providers

**Via GCP Console** (Identity Platform → Providers):

1. **Email/Password**
   - Enable email/password sign-in
   - Enable email link sign-in (magic link)
   - Configure password policy

2. **Google OAuth**
   - Create OAuth client credentials
   - Configure authorized domains
   - Enable Google sign-in

3. **Apple Sign In**
   - Register app with Apple Developer
   - Configure Services ID
   - Upload AuthKey file

4. **Microsoft OAuth** (optional)
   - Register app in Azure AD
   - Configure redirect URIs

### Via Terraform

```hcl
resource "google_identity_platform_config" "auth" {
  project = var.project_id

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }
  }

  mfa {
    enabled_providers = ["PHONE_SMS"]
    state            = "ENABLED"
  }
}

resource "google_identity_platform_default_supported_idp_config" "google" {
  project      = var.project_id
  idp_id       = "google.com"
  enabled      = true
  client_id    = var.google_oauth_client_id
  client_secret = var.google_oauth_client_secret
}

resource "google_identity_platform_default_supported_idp_config" "apple" {
  project      = var.project_id
  idp_id       = "apple.com"
  enabled      = true
  client_id    = var.apple_services_id
  client_secret = var.apple_key_id
}
```

---

## Password Policy

### Configure Password Requirements

**Via GCP Console** (Identity Platform → Settings → Password policy):

| Setting | Value | Rationale |
|---------|-------|-----------|
| Minimum length | 12 characters | FDA compliance |
| Require uppercase | Yes | Complexity |
| Require lowercase | Yes | Complexity |
| Require number | Yes | Complexity |
| Require special character | Yes | Complexity |
| Password expiry | 90 days | Best practice |

### Programmatic Configuration

```bash
# Use Firebase Admin SDK in Cloud Function
admin.auth().updateUserByEmail(email, {
  password: newPassword,
});
```

---

## Multi-Factor Authentication (MFA)

### Enable MFA

```bash
# Via GCP Console: Identity Platform → Settings → MFA
# Enable Phone (SMS) and TOTP authenticator
```

### MFA Enrollment Flow

**User Flow**:
1. User signs in with email/password
2. System checks if MFA is enrolled
3. If not enrolled and role requires MFA → redirect to enrollment
4. User scans QR code with authenticator app (or adds phone)
5. User verifies with OTP
6. MFA enrollment recorded

### Staff Account MFA Enforcement

**Enforce via Cloud Function**:

```javascript
// functions/enforceMfa/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Block sign-in if MFA not enrolled for staff roles
exports.enforceMfa = functions.auth.user().beforeSignIn(async (user) => {
  const claims = user.customClaims || {};
  const staffRoles = ['INVESTIGATOR', 'ANALYST', 'ADMIN'];

  if (staffRoles.includes(claims.role)) {
    // Check if MFA is enrolled
    const userRecord = await admin.auth().getUser(user.uid);
    const mfaInfo = userRecord.multiFactor?.enrolledFactors || [];

    if (mfaInfo.length === 0) {
      throw new functions.auth.HttpsError(
        'failed-precondition',
        'MFA enrollment required for staff accounts. Please complete MFA setup.'
      );
    }
  }

  return {};
});
```

### MFA Reset Procedures

**When user loses MFA device**:

1. User contacts administrator
2. Administrator verifies identity (out-of-band: phone call, video)
3. Administrator removes MFA enrollment:
   ```bash
   # Via Firebase Admin SDK
   admin.auth().getUser(uid).then((user) => {
     return admin.auth().updateUser(uid, {
       multiFactor: {
         enrolledFactors: []
       }
     });
   });
   ```
4. User re-enrolls MFA on next login
5. Action logged in admin audit trail

---

## Custom Claims (RBAC)

### Set Custom Claims via Cloud Function

```javascript
// functions/customClaims/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Add custom claims when user is created
exports.addCustomClaims = functions.auth.user().onCreate(async (user) => {
  try {
    // Default role for new users
    const defaultRole = 'USER';
    const sponsorId = process.env.SPONSOR_ID;

    await admin.auth().setCustomUserClaims(user.uid, {
      role: defaultRole,
      sponsorId: sponsorId,
    });

    // Also create user profile in database
    // (via API call or direct database insert)

    console.log(`Custom claims set for user ${user.uid}: role=${defaultRole}`);
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw error;
  }
});

// Update role (admin only)
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  if (!context.auth?.token?.role || context.auth.token.role !== 'ADMIN') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can update user roles'
    );
  }

  const { userId, newRole } = data;
  const validRoles = ['USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN'];

  if (!validRoles.includes(newRole)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role');
  }

  // Get current claims
  const userRecord = await admin.auth().getUser(userId);
  const currentClaims = userRecord.customClaims || {};

  // Update role
  await admin.auth().setCustomUserClaims(userId, {
    ...currentClaims,
    role: newRole,
  });

  // Log role change (call API or database)
  console.log(`Role updated: ${userId} -> ${newRole} by ${context.auth.uid}`);

  return { success: true, newRole };
});

// Assign site to investigator/analyst
exports.assignUserToSite = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  if (!context.auth?.token?.role || context.auth.token.role !== 'ADMIN') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can assign sites'
    );
  }

  const { userId, siteIds } = data;

  // Get current claims
  const userRecord = await admin.auth().getUser(userId);
  const currentClaims = userRecord.customClaims || {};

  if (!['INVESTIGATOR', 'ANALYST'].includes(currentClaims.role)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Only investigators and analysts can be assigned to sites'
    );
  }

  // Update site assignments in claims
  await admin.auth().setCustomUserClaims(userId, {
    ...currentClaims,
    siteAssignments: siteIds,
  });

  return { success: true, siteIds };
});
```

### Deploy Cloud Functions

```bash
cd functions
npm install

# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:addCustomClaims
```

### JWT Token Structure

**Example decoded token**:

```json
{
  "iss": "https://securetoken.google.com/clinical-diary-orion-prod",
  "aud": "clinical-diary-orion-prod",
  "auth_time": 1706097600,
  "user_id": "abc123xyz",
  "sub": "abc123xyz",
  "iat": 1706097600,
  "exp": 1706101200,
  "email": "user@example.com",
  "email_verified": true,
  "firebase": {
    "identities": {
      "email": ["user@example.com"]
    },
    "sign_in_provider": "password"
  },
  "role": "INVESTIGATOR",
  "sponsorId": "orion",
  "siteAssignments": ["site_001", "site_002"]
}
```

---

## Session Management

### Session Configuration

**Token Expiration**:
- ID tokens expire after 1 hour (Firebase default)
- Refresh tokens remain valid until revoked
- Custom session cookies: configurable duration (5 minutes to 2 weeks)

### Session Timeout Settings

```javascript
// Create session cookie with custom duration
const expiresIn = 60 * 60 * 1000; // 1 hour
const sessionCookie = await admin.auth().createSessionCookie(idToken, { expiresIn });
```

### Force Sign Out (Revoke Refresh Tokens)

```javascript
// Revoke all refresh tokens for a user
await admin.auth().revokeRefreshTokens(uid);

// User will need to re-authenticate
```

### Session Tracking in Database

```sql
-- User sessions table
CREATE TABLE user_sessions (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  last_activity_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true,
  client_info JSONB,
  ip_address INET
);

-- Cleanup expired sessions
DELETE FROM user_sessions
WHERE expires_at < now() OR is_active = false;
```

---

## Authentication Audit Logging

### What to Log

| Event | Data Logged |
|-------|-------------|
| LOGIN_SUCCESS | user_id, email, auth_method, ip, user_agent |
| LOGIN_FAILED | email (attempted), failure_reason, ip |
| LOGOUT | user_id, session_id |
| PASSWORD_CHANGE | user_id, changed_by |
| MFA_ENROLLED | user_id, mfa_type |
| MFA_REMOVED | user_id, removed_by |
| ROLE_CHANGE | user_id, old_role, new_role, changed_by |
| ACCOUNT_LOCKED | user_id, reason |
| ACCOUNT_UNLOCKED | user_id, unlocked_by |

### Audit Log Table

```sql
CREATE TABLE auth_audit_log (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT now(),
  event_type TEXT NOT NULL,
  user_id TEXT,
  email TEXT,
  success BOOLEAN,
  failure_reason TEXT,
  auth_method TEXT,
  session_id TEXT,
  client_ip INET,
  user_agent TEXT,
  device_info JSONB,
  geo_location JSONB,
  metadata JSONB
);

-- Index for compliance queries
CREATE INDEX idx_auth_audit_user ON auth_audit_log(user_id, timestamp);
CREATE INDEX idx_auth_audit_event ON auth_audit_log(event_type, timestamp);
```

### Log Authentication Events

**Server-side logging** (Dart):

```dart
Future<void> logAuthEvent({
  required String eventType,
  String? userId,
  String? email,
  required bool success,
  String? failureReason,
  String? authMethod,
  String? clientIp,
  String? userAgent,
}) async {
  await db.execute('''
    INSERT INTO auth_audit_log (
      event_type, user_id, email, success, failure_reason,
      auth_method, client_ip, user_agent
    ) VALUES (
      @eventType, @userId, @email, @success, @failureReason,
      @authMethod, @clientIp::inet, @userAgent
    )
  ''', parameters: {
    'eventType': eventType,
    'userId': userId,
    'email': email,
    'success': success,
    'failureReason': failureReason,
    'authMethod': authMethod,
    'clientIp': clientIp,
    'userAgent': userAgent,
  });
}
```

---

## Account Lockout

### Lockout Policy

**Configuration**:
- Lock after 5 failed attempts in 15 minutes
- Lockout duration: 30 minutes (automatic unlock)
- Admin can manually unlock

### Implementation via Cloud Function

```javascript
// functions/accountLockout/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_WINDOW_MINUTES = 15;
const LOCKOUT_DURATION_MINUTES = 30;

exports.checkAccountLockout = functions.auth.user().beforeSignIn(async (user) => {
  const db = admin.firestore();
  const lockoutDoc = await db.collection('account_lockouts').doc(user.email).get();

  if (lockoutDoc.exists) {
    const data = lockoutDoc.data();
    const lockedUntil = data.lockedUntil?.toDate();

    if (lockedUntil && lockedUntil > new Date()) {
      const minutesRemaining = Math.ceil((lockedUntil - new Date()) / 60000);
      throw new functions.auth.HttpsError(
        'resource-exhausted',
        `Account locked. Try again in ${minutesRemaining} minutes.`
      );
    }
  }

  return {};
});

// Track failed attempts (call this from your authentication handler)
exports.trackFailedLogin = functions.https.onCall(async (data, context) => {
  const { email } = data;
  const db = admin.firestore();
  const docRef = db.collection('account_lockouts').doc(email);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    const now = new Date();
    const windowStart = new Date(now - LOCKOUT_WINDOW_MINUTES * 60000);

    let failedAttempts = [];
    if (doc.exists) {
      failedAttempts = doc.data().failedAttempts || [];
      // Filter to only recent attempts
      failedAttempts = failedAttempts.filter(ts =>
        new Date(ts) > windowStart
      );
    }

    failedAttempts.push(now.toISOString());

    const updates = { failedAttempts };

    if (failedAttempts.length >= MAX_FAILED_ATTEMPTS) {
      updates.lockedUntil = new Date(now.getTime() + LOCKOUT_DURATION_MINUTES * 60000);
      console.log(`Account locked: ${email}`);
    }

    transaction.set(docRef, updates, { merge: true });
  });

  return { success: true };
});
```

---

## OAuth Provider Configuration

### Google OAuth

```bash
# 1. Create OAuth credentials in GCP Console
# APIs & Services → Credentials → Create OAuth Client ID

# 2. Configure authorized redirect URIs
# https://clinical-diary-orion-prod.firebaseapp.com/__/auth/handler

# 3. Add client ID to Identity Platform
# Identity Platform → Providers → Google → Configure
```

### Apple Sign In

```bash
# 1. Register app with Apple Developer
# Identifiers → App IDs → Configure Sign in with Apple

# 2. Create Services ID
# Identifiers → Services IDs → Create

# 3. Create and download Auth Key
# Keys → Create Key → Enable Sign in with Apple

# 4. Configure in Identity Platform
# Identity Platform → Providers → Apple → Configure
```

### Microsoft OAuth (Azure AD)

```bash
# 1. Register app in Azure Portal
# Azure AD → App registrations → New registration

# 2. Add redirect URI
# https://clinical-diary-orion-prod.firebaseapp.com/__/auth/handler

# 3. Create client secret
# Certificates & secrets → New client secret

# 4. Configure in Identity Platform
# Identity Platform → Providers → Microsoft → Configure
```

---

## Token Verification (Server-side)

### Dart Server Implementation

```dart
import 'package:firebase_admin/firebase_admin.dart';

class AuthMiddleware {
  final FirebaseApp _firebaseApp;

  AuthMiddleware(this._firebaseApp);

  Future<DecodedToken?> verifyToken(String idToken) async {
    try {
      final decodedToken = await _firebaseApp.auth().verifyIdToken(idToken);
      return decodedToken;
    } catch (e) {
      print('Token verification failed: $e');
      return null;
    }
  }

  Middleware authenticate() {
    return (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['authorization'];

        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized('Missing or invalid authorization header');
        }

        final token = authHeader.substring(7);
        final decodedToken = await verifyToken(token);

        if (decodedToken == null) {
          return Response.unauthorized('Invalid token');
        }

        // Add user info to request context
        final updatedRequest = request.change(context: {
          'userId': decodedToken.uid,
          'email': decodedToken.email,
          'role': decodedToken.claims['role'] ?? 'USER',
          'siteAssignments': decodedToken.claims['siteAssignments'] ?? [],
        });

        return innerHandler(updatedRequest);
      };
    };
  }
}
```

### Set Session Variables for RLS

```dart
Future<void> setSessionVariables(Connection conn, Request request) async {
  final userId = request.context['userId'];
  final role = request.context['role'];
  final siteAssignments = request.context['siteAssignments'];

  await conn.execute('''
    SET app.current_user_id = '${userId}';
    SET app.current_user_role = '${role}';
    SET app.current_site_ids = '${siteAssignments.join(',')}';
  ''');
}
```

---

## Security Monitoring

### Failed Login Monitoring

```sql
-- Failed logins in last 24 hours
SELECT email, COUNT(*) as attempts, MAX(timestamp) as last_attempt
FROM auth_audit_log
WHERE event_type = 'LOGIN_FAILED'
  AND timestamp > now() - interval '24 hours'
GROUP BY email
HAVING COUNT(*) >= 3
ORDER BY attempts DESC;

-- Suspicious geographic activity
SELECT user_id, email,
       COUNT(DISTINCT geo_location->>'country') as country_count,
       array_agg(DISTINCT geo_location->>'country') as countries
FROM auth_audit_log
WHERE event_type = 'LOGIN_SUCCESS'
  AND timestamp > now() - interval '24 hours'
GROUP BY user_id, email
HAVING COUNT(DISTINCT geo_location->>'country') > 1;
```

### Alert Configuration

**Cloud Monitoring Alerts**:

```bash
# Alert on high failed login rate
gcloud monitoring alert-policies create \
  --display-name="High Failed Login Rate" \
  --condition-filter='metric.type="logging.googleapis.com/log_entry_count" AND resource.type="cloud_run_revision" AND jsonPayload.event_type="LOGIN_FAILED"' \
  --condition-threshold-value=10 \
  --condition-threshold-duration=900s \
  --notification-channels=${CHANNEL_ID}
```

---

## Compliance Reports

### Authentication Audit Report

```sql
-- HIPAA/FDA compliant authentication report
SELECT
  timestamp,
  event_type,
  user_id,
  email,
  CASE WHEN success THEN 'Success' ELSE 'Failed' END as outcome,
  auth_method,
  client_ip::text,
  failure_reason
FROM auth_audit_log
WHERE timestamp BETWEEN @start_date AND @end_date
ORDER BY timestamp;
```

### MFA Compliance Report

```sql
-- Users with MFA enrolled
SELECT
  up.user_id,
  up.email,
  up.role,
  up.mfa_enrolled,
  up.mfa_enrolled_at
FROM user_profiles up
WHERE up.role IN ('INVESTIGATOR', 'ANALYST', 'ADMIN')
ORDER BY up.mfa_enrolled, up.role;
```

---

## Troubleshooting

### Token Verification Fails

**Symptoms**: `Token verification failed: invalid signature`

**Solutions**:
1. Verify Firebase project ID matches
2. Check token hasn't expired (1 hour default)
3. Ensure server time is synchronized
4. Verify correct public keys are being fetched

### MFA Not Working

**Symptoms**: MFA prompt not appearing

**Solutions**:
1. Verify MFA is enabled in Identity Platform settings
2. Check user has enrolled at least one MFA factor
3. Verify Firebase SDK version supports MFA

### Custom Claims Not Propagating

**Symptoms**: Role not appearing in token

**Solutions**:
1. User must sign out and sign in again
2. Or call `getIdToken(true)` to force token refresh
3. Check Cloud Function logs for errors
4. Verify Cloud Function has correct IAM permissions

---

## References

- [Identity Platform Documentation](https://cloud.google.com/identity-platform/docs)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Custom Claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [MFA with Identity Platform](https://cloud.google.com/identity-platform/docs/web/mfa)

---

## Change History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-01-24 | Initial guide (Supabase Auth) | Development Team |
| 2.0 | 2025-11-24 | Migration to Identity Platform | Claude |
