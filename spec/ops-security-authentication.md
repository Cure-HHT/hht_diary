# TODO: delete any information in this file related to "Does access have to be audited?" 
# TODO: Determine if remaining information can be moved to other relevant documentions (centralize information for easier access and less redundancy)

# Authentication Audit Logging

### REQ-o00006: MFA Configuration for Staff Accounts

**Level**: Ops | **Implements**: p00002 | **Status**: Active

Multi-factor authentication SHALL be configured and enforced for all clinical staff, administrator, and sponsor personnel accounts, ensuring password-based authentication is augmented with additional verification.

MFA configuration SHALL include:
- MFA enrollment required before first system access
- TOTP (Time-based One-Time Password) support for authenticator apps
- SMS backup codes as fallback option
- MFA enforcement at authentication system level (Supabase Auth)
- Grace period for MFA enrollment (max 7 days)
- MFA reset procedures for lost devices

**Rationale**: Implements MFA requirement (p00002) at the operational configuration level. Supabase Auth provides MFA capabilities that must be enabled and enforced per sponsor project.

**Acceptance Criteria**:
- MFA enabled in Supabase Auth settings per sponsor
- Staff accounts cannot access system without completing MFA enrollment
- MFA verification required at each login
- MFA bypass not possible through configuration
- MFA events logged in audit trail

---

## Why It's Necessary for Compliance

Authentication audit logging is **critical** for regulatory compliance in clinical trials:

### HIPAA Requirements
- **45 CFR § 164.308(a)(5)(ii)(C)** - Log-in monitoring
- **45 CFR § 164.312(b)** - Audit controls
- Must track:
  - Who accessed the system
  - When they accessed it
  - What authentication method was used
  - Success/failure of access attempts
  - IP addresses and device information

### FDA 21 CFR Part 11
- **§ 11.10(e)** - Use of secure, computer-generated, time-stamped audit trails
- **§ 11.10(i)** - Determine that persons who develop, maintain, or use electronic record systems have the education, training, and experience to perform their assigned tasks
- **§ 11.300** - Controls for identification codes/passwords

### Security Best Practices
- Detect suspicious activity (multiple failed logins)
- Track geographic anomalies (logins from unusual locations)
- Monitor for brute force attacks
- Provide forensic data for incident response

---

## What's Been Added

The `auth_audit.sql` file adds comprehensive authentication tracking:

### Core Table: `auth_audit_log`

Tracks:
- ✅ Login success/failure
- ✅ Logout events
- ✅ Password changes
- ✅ 2FA attempts
- ✅ OAuth provider used (Google, Apple, Microsoft, SAML)
- ✅ Session management
- ✅ Client IP and user agent
- ✅ Device information
- ✅ Geographic location
- ✅ Suspicious activity flags
- ✅ Site context (multi-site trials)

### Helper Functions

1. **`log_auth_event()`** - Easy logging from application
2. **`detect_suspicious_login()`** - Automatic anomaly detection
3. **`get_failed_login_count()`** - Account lockout support

### Compliance Views

1. **`auth_audit_report`** - HIPAA-compliant audit reports
2. **`security_alerts`** - Real-time security monitoring
3. **`daily_login_stats`** - Aggregate statistics for compliance reports

---

## How to Deploy

### Step 1: Add to Your Database

```bash
# After deploying main schema
psql -d your_database -f auth_audit.sql

# Or in Supabase SQL Editor:
# Copy/paste auth_audit.sql and run
```

### Step 2: Update Init Script

The `init.sql` should include this file:

```sql
-- Add after rls_policies.sql
\ir auth_audit.sql
```

### Step 3: Application Integration

#### Log Login Success (JavaScript/TypeScript)
```javascript
// After successful authentication
await supabase.rpc('log_auth_event', {
    p_user_id: user.id,
    p_email: user.email,
    p_event_type: 'LOGIN_SUCCESS',
    p_auth_method: 'google', // or 'email', 'apple', etc.
    p_success: true,
    p_client_ip: clientIp,
    p_user_agent: navigator.userAgent,
    p_session_id: session.id
});
```

#### Log Login Failure
```javascript
// After failed authentication
await supabase.rpc('log_auth_event', {
    p_user_id: null, // May not have user_id for failed login
    p_email: attemptedEmail,
    p_event_type: 'LOGIN_FAILED',
    p_auth_method: 'email',
    p_success: false,
    p_failure_reason: 'Invalid password',
    p_client_ip: clientIp
});
```

#### Check for Suspicious Activity
```javascript
// Before allowing login
const { data: isSuspicious } = await supabase.rpc(
    'detect_suspicious_login',
    { p_user_id: user.id }
);

if (isSuspicious) {
    // Require additional verification (2FA, CAPTCHA, etc.)
    // Or temporarily lock account
}
```

#### Check Failed Login Count (Account Lockout)
```javascript
const { data: failedCount } = await supabase.rpc(
    'get_failed_login_count',
    {
        p_user_id: user.id,
        p_time_window: '1 hour'
    }
);

if (failedCount >= 5) {
    // Lock account
    // Send alert to admin
    // Require password reset
}
```

---

## Compliance Reports

### HIPAA Access Audit Report

```sql
-- Get all authentication events for audit
SELECT * FROM auth_audit_report
WHERE timestamp >= '2025-01-01'
  AND timestamp < '2025-02-01'
ORDER BY timestamp;

-- Export to CSV for regulatory submission
COPY (
    SELECT * FROM auth_audit_report
    WHERE timestamp >= '2025-01-01'
) TO '/path/to/hipaa_access_audit_2025_jan.csv' CSV HEADER;
```

### Security Monitoring

```sql
-- View recent security alerts
SELECT * FROM security_alerts
WHERE timestamp > now() - interval '24 hours';

-- Failed login attempts by user
SELECT
    user_id,
    email,
    COUNT(*) as failed_attempts,
    MAX(timestamp) as last_attempt
FROM auth_audit_log
WHERE event_type = 'LOGIN_FAILED'
  AND timestamp > now() - interval '7 days'
GROUP BY user_id, email
HAVING COUNT(*) >= 3
ORDER BY failed_attempts DESC;

-- Logins from multiple countries (potential compromise)
SELECT
    user_id,
    email,
    COUNT(DISTINCT geo_location->>'country') as country_count,
    array_agg(DISTINCT geo_location->>'country') as countries
FROM auth_audit_log
WHERE event_type = 'LOGIN_SUCCESS'
  AND timestamp > now() - interval '24 hours'
  AND geo_location IS NOT NULL
GROUP BY user_id, email
HAVING COUNT(DISTINCT geo_location->>'country') > 1;
```

### Daily Statistics

```sql
-- View daily login trends
SELECT * FROM daily_login_stats
WHERE login_date >= current_date - 30
ORDER BY login_date DESC;

-- Authentication method usage
SELECT
    auth_method,
    SUM(total_attempts) as total,
    SUM(successful_logins) as successful,
    SUM(failed_logins) as failed,
    ROUND(100.0 * SUM(successful_logins) / SUM(total_attempts), 2) as success_rate
FROM daily_login_stats
WHERE login_date >= current_date - 30
GROUP BY auth_method;
```

---

## OAuth Provider Tracking

The auth audit table tracks which OAuth provider was used:

### Supported Providers
- `email` - Email/password authentication
- `google` - Google OAuth
- `apple` - Apple Sign In
- `microsoft` - Microsoft OAuth
- `saml` - SAML SSO (for enterprise)
- `magic_link` - Passwordless authentication
- `api_key` - API/service authentication

### Why Track OAuth Providers?

1. **Compliance**: Know exactly how users authenticated
2. **Security**: Detect if compromised provider is used
3. **Audit Trail**: FDA requires knowing authentication method
4. **Troubleshooting**: Debug provider-specific issues
5. **Analytics**: Understand user preferences

### Example Queries

```sql
-- Logins by provider in last 30 days
SELECT
    auth_method,
    COUNT(*) as login_count,
    COUNT(DISTINCT user_id) as unique_users
FROM auth_audit_log
WHERE event_type = 'LOGIN_SUCCESS'
  AND timestamp > now() - interval '30 days'
GROUP BY auth_method
ORDER BY login_count DESC;

-- Users using multiple authentication methods
SELECT
    user_id,
    email,
    array_agg(DISTINCT auth_method) as methods_used,
    COUNT(DISTINCT auth_method) as method_count
FROM auth_audit_log
WHERE event_type = 'LOGIN_SUCCESS'
  AND timestamp > now() - interval '90 days'
GROUP BY user_id, email
HAVING COUNT(DISTINCT auth_method) > 1;
```

---

## Integration with Existing Schema

The auth audit table integrates seamlessly:

### Links to User Profiles
```sql
-- Get user's authentication history
SELECT
    aal.*,
    up.full_name,
    up.role
FROM auth_audit_log aal
JOIN user_profiles up ON aal.user_id = up.user_id
WHERE aal.user_id = 'user_123'
ORDER BY aal.timestamp DESC;
```

### Links to Sites
```sql
-- Authentication events by site
SELECT
    s.site_name,
    COUNT(*) as login_count,
    COUNT(DISTINCT aal.user_id) as unique_users
FROM auth_audit_log aal
JOIN sites s ON aal.site_id = s.site_id
WHERE aal.event_type = 'LOGIN_SUCCESS'
  AND aal.timestamp > now() - interval '7 days'
GROUP BY s.site_name
ORDER BY login_count DESC;
```

### Links to Sessions
```sql
-- Active sessions with authentication details
SELECT
    us.session_id,
    us.user_id,
    us.last_activity_at,
    aal.auth_method,
    aal.client_ip,
    aal.timestamp as login_time
FROM user_sessions us
JOIN auth_audit_log aal
    ON us.session_id = aal.session_id
WHERE us.is_active = true
  AND aal.event_type = 'LOGIN_SUCCESS'
ORDER BY us.last_activity_at DESC;
```

---

## Row-Level Security

Auth logs respect the role-based access control:

- **Users** can view their own auth logs
- **Investigators** can view logs for users at their sites
- **Admins** can view all auth logs
- **Service role** can insert logs

This ensures compliance with least-privilege principle.

---

## Comparison with ctest

| Feature | dbtest (with auth_audit.sql) | ctest |
|---------|------------------------------|-------|
| Authentication events | ✅ All types | ✅ Basic |
| OAuth provider tracking | ✅ Yes | ✅ Yes |
| Suspicious activity detection | ✅ Automatic | ❌ No |
| Risk scoring | ✅ Yes | ❌ No |
| Geographic tracking | ✅ Yes | ❌ No |
| Site context | ✅ Yes | ❌ No |
| Security alerts | ✅ View provided | ❌ No |
| Daily statistics | ✅ Materialized view | ❌ No |
| Failed login tracking | ✅ Function provided | ❌ Manual |

---

## Deployment Checklist

- [ ] Run `auth_audit.sql` after main schema
- [ ] Update `init.sql` to include auth_audit.sql
- [ ] Integrate `log_auth_event()` in application auth flow
- [ ] Set up cron job to refresh `daily_login_stats` view
- [ ] Configure alerts for suspicious activity
- [ ] Test auth logging for all providers (email, Google, Apple)
- [ ] Document auth audit procedures for regulatory submission
- [ ] Train security team on `security_alerts` view
- [ ] Set up automated reports for HIPAA compliance

---

## Maintenance

### Daily
```sql
-- Check for suspicious activity
SELECT COUNT(*) FROM security_alerts
WHERE timestamp > now() - interval '24 hours';
```

### Weekly
```sql
-- Refresh statistics
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_login_stats;

-- Review failed login trends
SELECT * FROM daily_login_stats
WHERE login_date >= current_date - 7
  AND failed_logins > 10;
```

### Monthly
```sql
-- Generate compliance report
SELECT * FROM auth_audit_report
WHERE timestamp >= date_trunc('month', now() - interval '1 month')
  AND timestamp < date_trunc('month', now());
```

---

## Regulatory Audits

When regulators request authentication audit data:

1. **Export full audit log**
   ```sql
   COPY auth_audit_log TO '/audit/auth_audit_2025.csv' CSV HEADER;
   ```

2. **Provide summary statistics**
   ```sql
   COPY daily_login_stats TO '/audit/login_stats_2025.csv' CSV HEADER;
   ```

3. **Include security incidents**
   ```sql
   COPY security_alerts TO '/audit/security_alerts_2025.csv' CSV HEADER;
   ```

---

## Conclusion

**Yes, OAuth/authentication tracking IS necessary for compliance** in the dbtest multi-site architecture.

The `auth_audit.sql` file provides:
- ✅ HIPAA-compliant access logging
- ✅ FDA 21 CFR Part 11 audit trail
- ✅ Security monitoring
- ✅ OAuth provider tracking
- ✅ Automated anomaly detection
- ✅ Compliance reporting

**Deploy this file as part of your standard schema.**
