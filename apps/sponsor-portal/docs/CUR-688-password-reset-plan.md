# Password Reset Implementation Plan - CUR-688

**Ticket:** CUR-688 - User Password Reset (Auth Journey 2)
**Scope:** Sponsor Portal Staff Authentication ONLY (not patients)
**Status:** Ready for Implementation

## Overview

Implement password reset feature for **sponsor portal staff users** (investigators, coordinators, admins, sponsors) to allow password recovery via email link, following REQ-CAL-p00044 and REQ-CAL-p00071 from `hht_diary_callisto/spec/prd-portal-authentication.md`.

**Important Context:**
- This is for **staff authentication only** (investigators, coordinators, admins)
- **NOT for patients** - the Web Diary has a separate linking code system
- Staff emails ARE stored in `portal_users` table (already compliant)
- HIPAA applies to patient PHI, NOT staff authentication data
- GDPR applies to staff, but storing staff emails with consent is acceptable

## Architecture Decision

**Use GCP Identity Platform's password reset capability** (via Firebase Auth SDK) with **custom email delivery via Gmail API**.

**Key Approach:**
1. **Token Generation:** Use Identity Platform's secure password reset token generation (via Firebase Admin SDK `generatePasswordResetLink()`)
2. **Email Delivery:** Send custom-branded emails via Gmail API (NOT Identity Platform's default emails)
3. **Reset Page:** Custom UI hosted at `/reset-password` on portal domain
4. **Audit Trail:** Log all events to `auth_audit_log` table (FDA compliance)

**Why This Works:**
- Identity Platform and Firebase Auth are functionally identical at API level
- Existing `firebase_auth` Dart SDK works with Identity Platform backend
- Staff email storage is acceptable under GDPR (legitimate interest for authentication)
- HIPAA doesn't apply to staff authentication (only patient PHI)
- Full control over branding and audit logging via custom email delivery

## Critical Files to Modify

### Backend (portal_functions)
1. **NEW:** `lib/src/portal_password_reset.dart` - Password reset request handler
2. **MODIFY:** `lib/src/email_service.dart` - Add `sendPasswordResetEmail()` method
3. **MODIFY:** `lib/portal_functions.dart` - Export new module
4. **MODIFY:** `bin/server.dart` - Add route: `POST /api/v1/portal/auth/password-reset/request`

### Frontend (portal-ui)
1. **NEW:** `lib/pages/forgot_password_page.dart` - Request reset UI
2. **NEW:** `lib/pages/reset_password_page.dart` - Complete reset UI
3. **MODIFY:** `lib/pages/login_page.dart` - Add "Forgot Password?" link (line ~215)
4. **MODIFY:** `lib/services/auth_service.dart` - Add password reset methods
5. **MODIFY:** `lib/router/app_router.dart` - Add `/forgot-password` and `/reset-password` routes

### Database
1. **NO CHANGES NEEDED** - `auth_audit_log` already has PASSWORD_RESET event type (database/auth_audit.sql line 36)

## Implementation Details

### Phase 1: Backend API

#### 1.1 New File: `portal_password_reset.dart`

**Location:** `/apps/sponsor-portal/portal_functions/lib/src/portal_password_reset.dart`

**Header:**
```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00044: Password Reset
//   REQ-CAL-p00071: Password Complexity Requirements
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-p00010: FDA 21 CFR Part 11 Compliance
//   REQ-d00031: Identity Platform Integration
```

**Key Function:**
```dart
/// Request password reset email
/// POST /api/v1/portal/auth/password-reset/request
/// Body: { "email": "user@example.com" }
Future<Response> requestPasswordResetHandler(Request request) async {
  final body = await request.readAsString();
  final data = jsonDecode(body);
  final email = data['email'] as String;

  // 1. Validate email format
  if (!_isValidEmail(email)) {
    return Response.json({'success': true}); // Generic response for security
  }

  // 2. Check rate limiting (3 requests per email per 15 min)
  if (await _isRateLimited(email, 'password_reset')) {
    return Response(429, body: 'Too many requests');
  }

  // 3. Check if email exists in portal_users and is active
  final user = await _getPortalUser(email);

  if (user != null && user['status'] == 'active') {
    // 4. Generate Identity Platform password reset link
    final resetLink = await _generatePasswordResetLink(email);

    // 5. Send email via Gmail API (custom template)
    await emailService.sendPasswordResetEmail(
      recipientEmail: email,
      recipientName: user['name'],
      resetUrl: resetLink,
      expiresInHours: 24,
    );

    // 6. Log to auth_audit_log
    await _logAuthEvent(
      email: email,
      eventType: 'PASSWORD_RESET',
      success: true,
      clientIp: request.headers['x-forwarded-for'],
    );
  } else {
    // Still log the attempt (for security monitoring)
    await _logAuthEvent(
      email: email,
      eventType: 'PASSWORD_RESET',
      success: false,
      failureReason: 'Email not found or inactive',
      clientIp: request.headers['x-forwarded-for'],
    );
  }

  // 7. ALWAYS return generic success (prevent email enumeration per REQ-CAL-p00044.B)
  return Response.json({'success': true});
}

/// Generate password reset link using Firebase Admin SDK
Future<String> _generatePasswordResetLink(String email) async {
  // Use Firebase Admin SDK (works with Identity Platform)
  // This generates a secure token and constructs the action link
  final link = await FirebaseAuth.instance.generatePasswordResetLink(
    email,
    actionCodeSettings: ActionCodeSettings(
      url: 'https://portal.domain.com/reset-password',
      handleCodeInApp: true,
    ),
  );
  return link;
}
```

**Rate Limiting:**
Reuse existing `email_rate_limits` table pattern:
```dart
Future<bool> _isRateLimited(String email, String type) async {
  final result = await db.query(
    'SELECT COUNT(*) as count FROM email_rate_limits '
    'WHERE email = @email AND email_type = @type '
    'AND sent_at > NOW() - INTERVAL \'15 minutes\'',
    substitutionValues: {'email': email, 'type': type},
  );
  return result.first['count'] >= 3;
}
```

#### 1.2 Email Service Enhancement

**Location:** `/apps/sponsor-portal/portal_functions/lib/src/email_service.dart`

**Add Method:**
```dart
/// Send password reset email with Identity Platform reset link
Future<EmailResult> sendPasswordResetEmail({
  required String recipientEmail,
  required String recipientName,
  required String resetUrl,
  required int expiresInHours,
  String? sentByUserId,
}) async {
  final subject = 'Reset Your Clinical Trial Portal Password';

  final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .button {
      display: inline-block;
      padding: 12px 24px;
      background-color: #1976D2;
      color: white;
      text-decoration: none;
      border-radius: 4px;
      font-weight: 500;
    }
    .warning {
      background-color: #FFF3CD;
      border-left: 4px solid #FFC107;
      padding: 12px;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <h2>Reset Your Password</h2>
    <p>Hello $recipientName,</p>
    <p>We received a request to reset your Clinical Trial Portal password.</p>
    <p style="text-align: center; margin: 30px 0;">
      <a href="$resetUrl" class="button">Reset Password</a>
    </p>
    <p>Or copy and paste this link into your browser:</p>
    <p style="word-break: break-all; color: #666;">$resetUrl</p>

    <div class="warning">
      <strong>Security Notice:</strong>
      <ul>
        <li>This link expires in $expiresInHours hours</li>
        <li>Do not share this link with anyone</li>
        <li>If you didn't request this reset, please contact support immediately</li>
      </ul>
    </div>

    <p style="margin-top: 30px; font-size: 12px; color: #666;">
      If you need assistance, contact support at ${config.senderEmail}
    </p>
  </div>
</body>
</html>
''';

  final plainBody = '''
Reset Your Clinical Trial Portal Password

Hello $recipientName,

We received a request to reset your password.

Click this link to reset your password:
$resetUrl

This link expires in $expiresInHours hours.

SECURITY NOTICE:
- Do not share this link with anyone
- If you didn't request this reset, contact support immediately

Support: ${config.senderEmail}
''';

  // Send via Gmail API (reuse existing send logic)
  return await _sendEmail(
    recipientEmail: recipientEmail,
    subject: subject,
    htmlBody: htmlBody,
    plainBody: plainBody,
    emailType: 'password_reset',
    sentByUserId: sentByUserId,
  );
}
```

#### 1.3 Wire Up Route

**Location:** `/apps/sponsor-portal/portal_functions/bin/server.dart`

Add route:
```dart
app.post('/api/v1/portal/auth/password-reset/request', requestPasswordResetHandler);
```

### Phase 2: Frontend UI

#### 2.1 Login Page Modification

**Location:** `/apps/sponsor-portal/portal-ui/lib/pages/login_page.dart`

**Change at line ~215** (after password field, before error message):
```dart
// Password field
TextFormField(
  controller: _passwordController,
  obscureText: !_passwordVisible,
  // ... existing properties ...
),

// ADD THIS:
const SizedBox(height: 8),
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () => context.go('/forgot-password'),
    child: const Text('Forgot Password?'),
  ),
),
const SizedBox(height: 16),

// Existing error message widget
if (_errorMessage != null) ...
```

#### 2.2 Forgot Password Page

**Location:** `/apps/sponsor-portal/portal-ui/lib/pages/forgot_password_page.dart`

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00044: Password Reset
//   REQ-d00031: Identity Platform Integration

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.requestPasswordReset(_emailController.text.trim());

      // Always show success (per REQ-CAL-p00044.B - generic message for security)
      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to process request. Please try again later.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _emailSent ? _buildSuccessView() : _buildFormView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit button
          FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Reset Link'),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'Check Your Email',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Generic success message per REQ-CAL-p00044.B
        const Text(
          'If an account exists with that email, you will receive a password reset link within a few minutes.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Please check your spam folder if you don\'t see it. The link expires in 24 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Return to Login'),
        ),
      ],
    );
  }
}
```

#### 2.3 Reset Password Page

**Location:** `/apps/sponsor-portal/portal-ui/lib/pages/reset_password_page.dart`

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00044: Password Reset
//   REQ-CAL-p00071: Password Complexity Requirements
//   REQ-d00031: Identity Platform Integration

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? oobCode;

  const ResetPasswordPage({super.key, this.oobCode});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _resetComplete = false;
  String? _errorMessage;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    if (widget.oobCode == null) {
      setState(() {
        _errorMessage = 'Invalid reset link';
        _isLoading = false;
      });
      return;
    }

    try {
      final authService = context.read<AuthService>();
      final email = await authService.verifyPasswordResetCode(widget.oobCode!);

      setState(() {
        _userEmail = email;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'This reset link is invalid or has expired';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.confirmPasswordReset(
        widget.oobCode!,
        _passwordController.text,
      );

      setState(() {
        _resetComplete = true;
        _isSubmitting = false;
      });

      // Redirect to login after 3 seconds (per REQ-CAL-p00044.G)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          context.go('/login');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to reset password. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Verifying reset link...'),
        ],
      );
    }

    if (_resetComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Password Reset Complete',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your password has been successfully reset. You will be redirected to the login page.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_errorMessage != null && _userEmail == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Return to Login'),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'Create New Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (_userEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              _userEmail!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 32),

          // New password field
          TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
              border: const OutlineInputBorder(),
              helperText: 'Minimum 8 characters',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (value.length > 64) {
                return 'Password must be less than 64 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_confirmPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_confirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit button
          FilledButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reset Password'),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
```

#### 2.4 AuthService Enhancement

**Location:** `/apps/sponsor-portal/portal-ui/lib/services/auth_service.dart`

Add these methods to the `AuthService` class:

```dart
/// Request password reset email
/// Calls backend API to generate reset link and send email
Future<void> requestPasswordReset(String email) async {
  final response = await http.post(
    Uri.parse('$_baseUrl/api/v1/portal/auth/password-reset/request'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to request password reset');
  }
}

/// Verify password reset code and return email
/// Returns the email address if code is valid, null otherwise
Future<String?> verifyPasswordResetCode(String code) async {
  try {
    final email = await _auth.verifyPasswordResetCode(code);
    return email;
  } catch (e) {
    return null;
  }
}

/// Confirm password reset with new password
/// Uses Identity Platform's confirmPasswordReset
Future<void> confirmPasswordReset(String code, String newPassword) async {
  await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
}
```

#### 2.5 Router Configuration

**Location:** `/apps/sponsor-portal/portal-ui/lib/router/app_router.dart`

Add routes to the `routes` list:

```dart
GoRoute(
  path: '/forgot-password',
  name: 'forgot-password',
  builder: (context, state) => const ForgotPasswordPage(),
),
GoRoute(
  path: '/reset-password',
  name: 'reset-password',
  builder: (context, state) {
    final oobCode = state.uri.queryParameters['oobCode'];
    return ResetPasswordPage(oobCode: oobCode);
  },
),
```

## Requirements Traceability

### REQ-CAL-p00044: Password Reset

| Assertion                                 | Implementation                                  | File/Location                                         |
|-------------------------------------------|-------------------------------------------------|-------------------------------------------------------|
| A. Provide "Forgot Password" link         | TextButton on login page                        | login_page.dart:215                                   |
| B. Generic success message                | Always return success regardless of email       | forgot_password_page.dart, portal_password_reset.dart |
| C. Email only to valid addresses          | Check `portal_users` table, only send if active | portal_password_reset.dart                            |
| D. 24-hour expiration                     | Firebase Admin SDK default                      | Identity Platform config                              |
| E. Password complexity per REQ-CAL-p00071 | Min 8 chars validation                          | reset_password_page.dart                              |
| F. Invalidate all sessions                | Call `revokeRefreshTokens()`                    | Backend (future enhancement)                          |
| G. Redirect to login                      | Navigate to `/login` after 3 seconds            | reset_password_page.dart                              |

### REQ-CAL-p00071: Password Complexity

| Assertion                            | Implementation                                 | File/Location            |
|--------------------------------------|------------------------------------------------|--------------------------|
| A. Min 8 characters                  | Frontend validation + Identity Platform config | reset_password_page.dart |
| B. Max 64 characters                 | Frontend validation                            | reset_password_page.dart |
| C. Any printable characters          | No composition rules enforced                  | reset_password_page.dart |
| D. Check breached passwords (SHOULD) | Phase 2 enhancement                            | Future work              |
| E. No composition rules              | Follows NIST SP 800-63B guidance               | reset_password_page.dart |

**Implements:**
- REQ-p00002: Multi-Factor Authentication for Staff
- REQ-p00010: FDA 21 CFR Part 11 Compliance (audit trail)
- REQ-d00031: Identity Platform Integration

## Security & Compliance

### 1. Email Enumeration Prevention (REQ-CAL-p00044.B)
**Always return generic success message**, whether email exists or not. This prevents attackers from discovering valid staff email addresses.

### 2. Rate Limiting
- **Limit:** 3 password reset requests per email per 15 minutes
- **Implementation:** Reuse `email_rate_limits` table pattern
- **Response:** HTTP 429 with appropriate message

### 3. Token Security
- **Generation:** Identity Platform secure token via Firebase Admin SDK
- **Expiration:** 24 hours (configurable)
- **Single-use:** Identity Platform invalidates token after successful reset
- **Transport:** HTTPS only

### 4. Audit Trail (FDA 21 CFR Part 11)
Log to `auth_audit_log` table:
- Event: `PASSWORD_RESET`
- Data: email, timestamp, client IP, success/failure
- Immutable record for compliance

### 5. GDPR Compliance (Staff Data)
- **Lawful Basis:** Legitimate interest (staff authentication for job function)
- **Data Minimization:** Only store necessary fields (email, name, role)
- **Transparency:** Staff aware of data processing (employment agreement)
- **Data Subject Rights:** Staff can request data access/deletion
- **Difference from Patients:** Staff emails acceptable; patient emails prohibited (REQ-p01049)

### 6. HIPAA Compliance
- **Not Applicable:** Staff authentication data is NOT Protected Health Information (PHI)
- **PHI Applies To:** Patient clinical data in the diary system
- **Separation:** Portal staff authentication completely separate from patient diary data

## Testing Strategy

### Unit Tests

**Backend:** `test/portal_password_reset_test.dart`
```dart
- test_request_reset_valid_email_sends_email()
- test_request_reset_invalid_email_returns_success() // Security
- test_request_reset_rate_limiting_enforced()
- test_request_reset_audit_log_entry_created()
- test_generate_reset_link_includes_oobCode()
```

**Frontend:** `test/pages/forgot_password_page_test.dart`
```dart
- test_email_validation_valid()
- test_email_validation_invalid()
- test_success_message_displayed()
- test_navigation_to_login()
```

**Frontend:** `test/pages/reset_password_page_test.dart`
```dart
- test_password_min_length_validation()
- test_password_max_length_validation()
- test_passwords_must_match()
- test_invalid_code_shows_error()
- test_success_redirects_to_login()
```

### Integration Tests

**File:** `integration_test/password_reset_flow_test.dart`

```dart
testWidgets('Complete password reset flow', (tester) async {
  // 1. Navigate to login and click "Forgot Password?"
  // 2. Enter email and submit
  // 3. Verify success message shown
  // 4. Mock reset link click (simulate email)
  // 5. Enter new password
  // 6. Verify redirect to login
  // 7. Attempt login with NEW password
  // 8. Verify successful authentication
});

testWidgets('Expired token shows error', (tester) async {
  // Test with expired oobCode
  // Verify error message displayed
});

testWidgets('Rate limiting enforced', (tester) async {
  // Make 4 reset requests in succession
  // Verify 4th request returns 429
});
```

### Manual Testing Checklist

#### Happy Path
- [ ] Navigate to login page
- [ ] Click "Forgot Password?" link
- [ ] Enter valid staff email (from `portal_users` table)
- [ ] Verify generic success message shown
- [ ] Check email inbox for password reset email
- [ ] Verify email contains reset button/link
- [ ] Click reset link
- [ ] Verify redirected to `/reset-password?oobCode=...`
- [ ] Enter new password (8+ characters)
- [ ] Confirm password matches
- [ ] Click "Reset Password"
- [ ] Verify success message
- [ ] Verify automatic redirect to login after 3 seconds
- [ ] Login with NEW password
- [ ] Verify successful authentication
- [ ] Verify old password no longer works

#### Security Testing
- [ ] Request reset for non-existent email → Still shows success (no enumeration)
- [ ] Request reset for inactive account → Still shows success (no enumeration)
- [ ] Make 4 requests in 15 minutes → 4th blocked with 429 error
- [ ] Use expired oobCode (25+ hours old) → Shows error
- [ ] Use already-used oobCode → Shows error
- [ ] Verify audit log entries created for all attempts

#### Edge Cases
- [ ] Invalid email format → Shows validation error
- [ ] Password too short (<8 chars) → Shows validation error
- [ ] Password too long (>64 chars) → Shows validation error
- [ ] Passwords don't match → Shows validation error
- [ ] Test on mobile browser (responsive UI)
- [ ] Test on desktop browser

## Verification Plan

### End-to-End Manual Test

1. **Request Reset**
   ```bash
   # Navigate to: http://localhost:8080/login
   # Click "Forgot Password?"
   # Enter: test-coordinator@anspar.org
   # Click "Send Reset Link"
   # Verify: Success message displayed
   ```

2. **Check Backend Logs**
   ```bash
   # Backend should log password reset request
   # Gmail API should send email
   ```

3. **Verify Email Sent**
   ```sql
   SELECT * FROM email_audit_log
   WHERE email_type = 'password_reset'
     AND recipient_email = 'test-coordinator@anspar.org'
   ORDER BY sent_at DESC LIMIT 1;
   ```

4. **Complete Reset**
   ```bash
   # Click reset link in email
   # Should redirect to: /reset-password?oobCode=...&mode=resetPassword
   # Enter new password: NewSecurePass123
   # Confirm password: NewSecurePass123
   # Click "Reset Password"
   # Verify: Success message + redirect to login
   ```

5. **Verify New Password Works**
   ```bash
   # Login page: test-coordinator@anspar.org / NewSecurePass123
   # Verify: Successful authentication
   ```

6. **Verify Audit Trail**
   ```sql
   SELECT * FROM auth_audit_log
   WHERE event_type = 'PASSWORD_RESET'
     AND email = 'test-coordinator@anspar.org'
   ORDER BY timestamp DESC LIMIT 5;
   ```

## Implementation Timeline

### Day 1: Backend Foundation
- [ ] Create `portal_password_reset.dart`
- [ ] Add `sendPasswordResetEmail()` to EmailService
- [ ] Wire up route in server.dart
- [ ] Write backend unit tests
- [ ] Manual test: Backend can generate reset links

### Day 2: Frontend Pages
- [ ] Create `ForgotPasswordPage`
- [ ] Create `ResetPasswordPage`
- [ ] Write widget tests
- [ ] Manual test: UI flows work

### Day 3: Integration
- [ ] Update `LoginPage` with "Forgot Password?" link
- [ ] Add AuthService methods
- [ ] Update router configuration
- [ ] Manual test: End-to-end flow

### Day 4: Testing & Refinement
- [ ] Write integration tests
- [ ] Complete manual testing checklist
- [ ] Fix any bugs found
- [ ] Verify audit logging works

### Day 5: Documentation & Deploy
- [ ] Update user documentation
- [ ] Create deployment checklist
- [ ] Deploy to staging
- [ ] UAT with stakeholders
- [ ] Deploy to production

## Known Limitations & Future Enhancements

### Current Scope
✅ Password reset request via email
✅ Custom branded reset emails
✅ Token expiration (24 hours)
✅ Rate limiting (3 per 15 min)
✅ Audit logging (FDA compliance)
✅ Generic success messages (security)

### Phase 2 Enhancements
🔜 Session invalidation on password change (requires backend enhancement)
🔜 Breached password checking (Have I Been Pwned API)
🔜 Password strength meter UI
🔜 Account unlock via password reset (REQ-CAL-p00069)
🔜 Multi-language support for emails

### Out of Scope
❌ Patient password reset (uses linking codes per REQ-p01049)
❌ SMS-based password reset (email only)
❌ Admin-initiated forced password reset (separate feature)

## References

- **PRD:** `hht_diary_callisto/spec/prd-portal-authentication.md`
- **Auth Service:** `/apps/sponsor-portal/portal-ui/lib/services/auth_service.dart`
- **Email Service:** `/apps/sponsor-portal/portal_functions/lib/src/email_service.dart`
- **Audit Log Schema:** `/database/auth_audit.sql`
- **Identity Platform Setup:** `/docs/gcp/identity-platform-setup.md`

---

**Plan Status:** ✅ Ready for Implementation
**Estimated Effort:** 5 days
**Risk Level:** Low (using proven Identity Platform capabilities)
**Dependencies:** None (all infrastructure exists)
