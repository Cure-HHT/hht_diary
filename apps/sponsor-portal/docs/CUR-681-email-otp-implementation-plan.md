# CUR-681 Phase 2: Conditional 2FA with Email OTP

## Overview

Modify the existing TOTP-based 2FA to be conditional based on user role, and add email-based OTP for non-admin users. Also automate activation code emails.

**Changes from Phase 1:**
- TOTP (authenticator app) → Developer Admins only (with feature flag)
- Email OTP → All other users on every login
- Activation code → Emailed automatically to First Admin

## Email Service: Google Workspace Gmail API (HIPAA Compliant)

**Why Google Workspace?**
- Anspar admin will sign BAA in Google Admin Console
- Already in GCP ecosystem (single cloud provider)
- HIPAA compliant when BAA signed
- Uses Gmail API with service account + domain-wide delegation

**Sources:**
- [Google Workspace HIPAA Compliance](https://support.google.com/a/answer/3407054?hl=en)
- [Gmail API Sending Email](https://developers.google.com/workspace/gmail/api/guides/sending)
- [Service Account Domain-Wide Delegation](https://cknotes.com/how-to-setup-a-google-service-account-to-send-email-via-gmail/)

---

## User Flows

### Developer Admin Login (TOTP - unchanged)
1. Enter email/password → Identity Platform
2. `FirebaseAuthMultiFactorException` caught
3. Enter TOTP code from authenticator app
4. Proceed to dashboard

### Other Users Login (Email OTP - NEW)
1. Enter email/password → Identity Platform (no MFA challenge)
2. Backend detects non-admin role, returns `email_otp_required: true`
3. Frontend requests OTP: `POST /api/v1/portal/auth/send-otp`
4. User receives 6-digit code via email (expires in 10 min)
5. User enters code, backend verifies
6. Proceed to dashboard

### First Admin Activation (with email)
1. Dev Admin generates activation code via UI
2. **System emails code to First Admin** (NEW)
3. First Admin clicks link, enters code, creates password
4. Skip TOTP setup (will use email OTP at login)
5. Account activated

---

## Implementation Phases

### Phase 1: Database Schema (Greenfield)

**File:** `database/schema.sql`

Add three new tables:

```sql
-- EMAIL OTP CODES TABLE
CREATE TABLE email_otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES portal_users(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL,  -- SHA-256 hash, never plaintext
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    used_at TIMESTAMPTZ,
    ip_address INET,
    attempts INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT max_attempts CHECK (attempts <= 5)
);

-- EMAIL RATE LIMITS TABLE
CREATE TABLE email_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    email_type TEXT NOT NULL CHECK (email_type IN ('otp', 'activation')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address INET
);

-- EMAIL AUDIT LOG (FDA compliance - immutable)
CREATE TABLE email_audit_log (
    id BIGSERIAL PRIMARY KEY,
    recipient_email TEXT NOT NULL,
    email_type TEXT NOT NULL CHECK (email_type IN ('otp', 'activation', 'notification')),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_by UUID REFERENCES portal_users(id),
    status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'bounced')),
    gmail_message_id TEXT,  -- Gmail API message ID for tracking
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);
```

Modify `portal_users`:
```sql
ADD COLUMN mfa_type TEXT CHECK (mfa_type IN ('totp', 'email_otp', 'none')) DEFAULT 'email_otp';
```

### Phase 2: Backend - Email Service

**New File:** `portal_functions/lib/src/email_service.dart`

Gmail API integration using `googleapis` package:
- `sendOtpCode(email, code)` - Send 6-digit OTP
- `sendActivationCode(email, name, code)` - Send activation email
- `checkRateLimit(email, type)` - Max 3 OTP per 15 min

**Dependencies (pubspec.yaml):**
```yaml
googleapis: ^15.0.0
googleapis_auth: ^2.0.0
```

**Environment Variables (via Doppler):**
```
GOOGLE_SERVICE_ACCOUNT_JSON=<base64-encoded service account key>
EMAIL_SENDER=noreply@anspar.com  # Must be a Google Workspace user
EMAIL_SENDER_NAME=Clinical Trial Portal
EMAIL_ENABLED=true
```

**How it works:**
1. Service account authenticates using JSON key
2. Domain-wide delegation allows impersonating EMAIL_SENDER
3. Gmail API sends email as that user
4. Limits: 2,000 messages/day, 10,000 recipients/day

### Phase 3: Backend - Email OTP Handlers

**New File:** `portal_functions/lib/src/email_otp.dart`

```dart
// POST /api/v1/portal/auth/send-otp
// Requires: Valid Identity Platform token (password already verified)
Future<Response> sendEmailOtpHandler(Request request);

// POST /api/v1/portal/auth/verify-otp
// Body: { "code": "123456" }
Future<Response> verifyEmailOtpHandler(Request request);
```

OTP Lifecycle:
1. Generate 6 cryptographically secure digits
2. Store SHA-256 hash in `email_otp_codes`
3. Set 10-minute expiration
4. Send via Gmail API
5. Max 5 verification attempts per code

### Phase 4: Backend - Feature Flags

**New File:** `portal_functions/lib/src/feature_flags.dart`

```dart
class FeatureFlags {
  static bool get totpAdminOnly =>
      Platform.environment['FEATURE_TOTP_ADMIN_ONLY'] != 'false';

  static bool get emailOtpEnabled =>
      Platform.environment['FEATURE_EMAIL_OTP_ENABLED'] != 'false';

  static bool get emailActivation =>
      Platform.environment['FEATURE_EMAIL_ACTIVATION'] != 'false';
}
```

**New Endpoint:** `GET /api/v1/portal/config/features`
- Returns feature flags for frontend

### Phase 5: Backend - Modify Existing

**Modify:** `portal_functions/lib/src/portal_activation.dart`

1. Update `generateActivationCodeHandler`:
   - After generating code, email it to target user
   - Log in `email_audit_log`

2. Update `activateUserHandler`:
   - Check user role for MFA type
   - Developer Admin: require TOTP enrollment
   - Others: set `mfa_type = 'email_otp'`, skip TOTP

**Modify:** `portal_functions/lib/src/portal_auth.dart`

1. Update `/api/v1/portal/me` response:
   - Include `email_otp_required: true` for non-admin users
   - Include `mfa_type` in user response

### Phase 6: Frontend - Email OTP Page

**New File:** `portal-ui/lib/pages/email_otp_page.dart`

UI Components:
- "Check your email" message with masked email (t***@example.com)
- 6-digit code input (auto-submit on completion)
- "Resend code" button (rate limited, show countdown)
- Error handling (invalid, expired, max attempts)

### Phase 7: Frontend - Auth Service Updates

**Modify:** `portal-ui/lib/services/auth_service.dart`

```dart
enum MfaType { totp, emailOtp, none }

// New properties
MfaType? _mfaType;
bool get emailOtpRequired => _mfaType == MfaType.emailOtp;

// New methods
Future<void> sendEmailOtp();
Future<bool> verifyEmailOtp(String code);
Future<MfaType> getMfaType();
```

### Phase 8: Frontend - Login Flow Updates

**Modify:** `portal-ui/lib/pages/login_page.dart`

After successful password auth:
```dart
if (authService.mfaRequired) {
  // Developer Admin - TOTP via Identity Platform
  await _handleMfaChallenge(authService);
} else if (authService.emailOtpRequired) {
  // Other users - redirect to email OTP page
  context.go('/login/email-otp');
}
```

### Phase 9: Frontend - Activation Flow Updates

**Modify:** `portal-ui/lib/pages/activation_page.dart`

After password creation, check role:
```dart
final features = await _fetchFeatureFlags();
if (features.totpAdminOnly && userRole != 'Developer Admin') {
  // Skip TOTP, complete activation directly
  await _completeActivation();
} else {
  // Developer Admin - redirect to TOTP setup
  context.go('/activate/2fa');
}
```

### Phase 10: Frontend - Router Update

**Modify:** `portal-ui/lib/router/app_router.dart`

Add route:
```dart
GoRoute(
  path: '/login/email-otp',
  builder: (context, state) => const EmailOtpPage(),
),
```

---

## Critical Files

| File | Action | Description |
| ---- | ------ | ----------- |
| **Database** | | |
| `database/schema.sql` | MODIFY | Add 3 tables + mfa_type column |
| **Backend (portal_functions)** | | |
| `portal_functions/lib/src/email_service.dart` | NEW | Gmail API integration |
| `portal_functions/lib/src/email_otp.dart` | NEW | OTP handlers |
| `portal_functions/lib/src/feature_flags.dart` | NEW | Feature flag service |
| `portal_functions/lib/src/portal_activation.dart` | MODIFY | Email activation code |
| `portal_functions/lib/src/portal_auth.dart` | MODIFY | Return mfa_type |
| `portal_functions/lib/src/routes.dart` | MODIFY | Add new endpoints |
| `portal_functions/pubspec.yaml` | MODIFY | Add googleapis dependencies |
| **Frontend (portal-ui)** | | |
| `portal-ui/lib/pages/email_otp_page.dart` | NEW | Email OTP UI |
| `portal-ui/lib/services/auth_service.dart` | MODIFY | Email OTP methods |
| `portal-ui/lib/pages/login_page.dart` | MODIFY | Route to email OTP |
| `portal-ui/lib/pages/activation_page.dart` | MODIFY | Skip TOTP for non-admins |
| `portal-ui/lib/router/app_router.dart` | MODIFY | Add email-otp route |
| **Terraform (per sponsor, per env)** | | |
| `infrastructure/terraform/modules/gcp-project/main.tf` | MODIFY | Add gmail.googleapis.com API |
| `infrastructure/terraform/modules/gmail-service-account/` | NEW | Gmail SA module |
| `infrastructure/terraform/sponsor-portal/main.tf` | MODIFY | Wire Gmail SA module |
| `infrastructure/terraform/sponsor-portal/variables.tf` | MODIFY | Add gmail_* variables |
| `infrastructure/terraform/sponsor-portal/sponsor-configs/*.tfvars` | MODIFY | Add gmail config per env |

---

## Environment Variables

**Backend (Doppler):**
```
# Gmail API
GOOGLE_SERVICE_ACCOUNT_JSON=<base64-encoded service account key>
EMAIL_SENDER=noreply@anspar.com
EMAIL_SENDER_NAME=Clinical Trial Portal

# Feature Flags
FEATURE_TOTP_ADMIN_ONLY=true
FEATURE_EMAIL_OTP_ENABLED=true
FEATURE_EMAIL_ACTIVATION=true
EMAIL_ENABLED=true
```

**Frontend (compile-time):**
```
PORTAL_API_URL=https://portal.example.com
```

---

## Infrastructure/Terraform Changes

### Phase 11: Enable Gmail API

**Modify:** `infrastructure/terraform/modules/gcp-project/main.tf`

Add to `required_apis` local:
```hcl
locals {
  required_apis = [
    # ... existing 16 APIs ...
    "gmail.googleapis.com",  # Gmail API for email OTP and activation emails
  ]
}
```

### Phase 12: Gmail Service Account Module

**New Module:** `infrastructure/terraform/modules/gmail-service-account/`

Creates a dedicated service account for Gmail API access per sponsor/environment.

**Files to create:**
- `main.tf` - Service account resource, IAM bindings
- `variables.tf` - sponsor, environment, project_id
- `outputs.tf` - service_account_email, service_account_key

```hcl
# main.tf
resource "google_service_account" "gmail" {
  account_id   = "${var.sponsor}-${var.environment}-gmail"
  display_name = "Gmail Service Account for ${var.sponsor} ${var.environment}"
  description  = "Sends email OTP and activation codes via Gmail API"
  project      = var.project_id
}

# Key for Doppler (alternatively use Workload Identity)
resource "google_service_account_key" "gmail" {
  service_account_id = google_service_account.gmail.id
}

# Output key for Doppler storage
output "gmail_service_account_key_base64" {
  value     = google_service_account_key.gmail.private_key
  sensitive = true
}
```

### Phase 13: Wire Module into Sponsor Portal

**Modify:** `infrastructure/terraform/sponsor-portal/main.tf`

Add Gmail service account module call:
```hcl
module "gmail_service_account" {
  source      = "../modules/gmail-service-account"
  sponsor     = var.sponsor
  environment = var.environment
  project_id  = var.project_id
}
```

### Phase 14: Update Sponsor Config Variables

**Modify:** `infrastructure/terraform/sponsor-portal/variables.tf`

Add Gmail-related variables:
```hcl
variable "gmail_sender_email" {
  description = "Email address to send from (must exist in Google Workspace)"
  type        = string
  default     = "noreply@anspar.com"
}

variable "gmail_enabled" {
  description = "Enable Gmail API for email OTP"
  type        = bool
  default     = true
}
```

**Update:** Each `sponsor-portal/sponsor-configs/{sponsor}-{env}.tfvars`:
```hcl
gmail_sender_email = "noreply@{sponsor-domain}.com"
gmail_enabled      = true
```

---

## Google Workspace Setup Required (Manual - Per Sponsor)

**Anspar Admin tasks (before implementation):**

Each sponsor's Google Workspace admin must:
1. **Sign BAA** in Admin Console (Account → Legal and compliance)
2. **Enable domain-wide delegation** for the Gmail service account:
   - Go to: Security → API Controls → Domain-wide Delegation
   - Click "Add new"
   - Enter service account Client ID (from Terraform output)
   - Grant scope: `https://www.googleapis.com/auth/gmail.send`
3. **Create sender mailbox** (e.g., noreply@{sponsor}.com) as a Google Workspace user

**This must be done for each of the 4 environments (dev, qa, uat, prod):**
- Service account: `{sponsor}-{env}-gmail@{project_id}.iam.gserviceaccount.com`
- Each env has its own GCP project, so each needs delegation setup

**After Terraform apply:**
1. Get service account key from Terraform output
2. Add to Doppler: `GOOGLE_SERVICE_ACCOUNT_JSON` (base64 encoded)

---

## Security Considerations

1. **OTP Codes**: SHA-256 hashed, never stored plaintext
2. **Rate Limiting**: Max 3 emails per address per 15 min
3. **Expiration**: 10-minute window for OTP codes
4. **Attempts**: Max 5 failed verifications per code
5. **Audit Trail**: All emails logged in `email_audit_log` (immutable)
6. **Gmail API**: Service account key stored in Doppler, never in code

---

## Requirement Traceability

| REQ ID | Description |
| ------ | ----------- |
| REQ-p00002 | Multi-Factor Authentication for Staff |
| REQ-o00006 | MFA Configuration for Staff Accounts |
| REQ-p00010 | FDA 21 CFR Part 11 Compliance |

---

## Verification

1. **Developer Admin login**: email/password → TOTP prompt → dashboard
2. **Investigator login**: email/password → email OTP → verify → dashboard
3. **First Admin activation**: Dev Admin generates code → email sent → activate
4. **Feature flags**: Toggle `FEATURE_TOTP_ADMIN_ONLY=false` restores TOTP for all
5. **Rate limiting**: Verify max 3 OTP emails per 15 min
6. **Audit logs**: Verify `email_audit_log` entries for all sent emails
7. **Coverage**: portal_functions >=85%, portal-ui >=85%

---

## Rollback Plan

Set environment variables to restore original behavior:
```
FEATURE_TOTP_ADMIN_ONLY=false    # TOTP for all users
FEATURE_EMAIL_OTP_ENABLED=false  # Disable email OTP
FEATURE_EMAIL_ACTIVATION=false   # Manual activation codes
```
