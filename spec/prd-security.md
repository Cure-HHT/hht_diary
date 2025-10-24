# Security Architecture: Authentication & Authorization

**Version**: 2.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **Scope**: Authentication and authorization ONLY - who can access what and how access is verified
>
> **See**: prd-security-RBAC.md for complete role definitions and permissions
> **See**: prd-security-RLS.md for database row-level security policies
> **See**: prd-security-data-classification.md for encryption and data privacy
> **See**: prd-clinical-trials.md for audit trail and compliance requirements
> **See**: prd-database.md for audit trail implementation
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture

---

## Executive Summary

This document specifies how the system **authenticates users** (verifies identity) and **authorizes access** (controls what authenticated users can do). The system implements defense-in-depth with multiple authorization layers across a multi-sponsor architecture.

**Authentication**: Supabase Auth (per sponsor)
**Authorization Layers**:
1. Role-Based Access Control (RBAC)
2. Row-Level Security (RLS) at database
3. Multi-sponsor infrastructure isolation

---

## Multi-Sponsor Access Isolation

### Infrastructure-Level Separation

Each sponsor operates a completely isolated Supabase instance, providing **infrastructure-level access isolation**:

```
Sponsor A Environment           Sponsor B Environment
┌─────────────────────────┐    ┌─────────────────────────┐
│ Supabase Project A      │    │ Supabase Project B      │
│ ├─ PostgreSQL Database  │    │ ├─ PostgreSQL Database  │
│ ├─ Supabase Auth        │    │ ├─ Supabase Auth        │
│ └─ Separate JWT secrets │    │ └─ Separate JWT secrets │
└─────────────────────────┘    └─────────────────────────┘
         ↑                              ↑
         │                              │
    Mobile App                     Mobile App
    (connects to A)                (connects to B)
```

**Access Isolation Guarantees**:
- No shared database instances
- No shared authentication systems
- No shared JWT secrets
- Users authenticated in Sponsor A cannot access Sponsor B data
- JWTs from Sponsor A invalid for Sponsor B
- Complete authentication/authorization independence

### Code Repository Access Control

**Public Core Repository** (`clinical-diary`):
- Contains no authentication credentials
- Contains no sponsor-specific access policies
- Abstract interfaces only (SponsorConfig, EdcSync, etc.)

**Private Sponsor Repositories** (`clinical-diary-{sponsor}`):
- Access restricted via GitHub private repos
- Contains sponsor-specific:
  - Supabase URL and anon key
  - Custom authentication configurations
  - Site assignments
  - Role mappings

---

## Authentication Layer

### Supabase Auth (Per Sponsor)

**Each sponsor** has dedicated Supabase Auth instance providing:
- User registration and login
- JWT token generation
- Session management
- Password policies
- Multi-factor authentication (2FA)

**Supported Authentication Methods**:
- Email + password
- Magic link (passwordless email)
- OAuth providers (Google, Apple, Microsoft)
- SAML/SSO (enterprise sponsors)

**Configuration Example** (Sponsor-specific):
```javascript
// Each sponsor has unique Supabase configuration
const supabase = createClient(
  'https://sponsor-xyz.supabase.co',  // Sponsor-specific URL
  'sponsor-xyz-anon-key',              // Sponsor-specific anon key
);
```

### JWT Token Structure

**Claims in JWT** (custom claims added via Supabase Auth hook):
```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "INVESTIGATOR",
  "site_assignments": ["site_001", "site_002"],
  "active_site": "site_001",
  "two_factor_verified": true,
  "exp": 1704067200
}
```

**JWT Usage**:
- Generated on login
- Included in all database requests
- Validated by PostgreSQL RLS policies
- Scoped to single sponsor (cannot cross sponsors)

**See**: ops-security-authentication.md for authentication configuration procedures

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

**Required for**:
- Investigators
- Sponsors
- Auditors
- Administrators
- Developer Admins

**Implementation**: TOTP (Time-based One-Time Password)
- QR code enrollment
- 6-digit codes via authenticator app
- Backup codes provided

**Enforcement**: Cannot access system without 2FA enabled (after grace period)

---

### Session Management

**Session Properties**:
- JWT-based (stateless)
- Configurable timeout (default: 1 hour for privileged, 24 hours for patients)
- Automatic refresh when active
- Explicit logout clears session

**Session Security**:
- Secure, HttpOnly cookies (web)
- Secure storage (mobile - flutter_secure_storage)
- Session invalidation on password change
- Concurrent session limits (configurable)

**Inactivity Timeout**:
- Privileged users: 60 minutes
- Patients: 24 hours
- Configurable per sponsor

---

## Authorization Layer 1: Role-Based Access Control (RBAC)

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

### Single Active Role Context

**Principle**: Users with multiple roles must select **one active role** per session.

**Why**: Ensures all actions are clearly attributed to specific role for audit purposes.

**Implementation**:
```javascript
// User selects active role at login
await setActiveRole('INVESTIGATOR');

// JWT contains selected role
{
  "role": "INVESTIGATOR",
  "available_roles": ["INVESTIGATOR", "ANALYST"]
}

// All actions logged with this role
```

### Single Active Site Context (Site-Scoped Roles)

**Applies to**: Investigators, Analysts

**Principle**: Users assigned to multiple sites must select **one active site** for current session.

**Why**: Prevents accidental cross-site actions, simplifies audit trail.

**Implementation**:
```javascript
// Investigator selects active site
await setActiveSite('site_001');

// JWT updated with active site
{
  "role": "INVESTIGATOR",
  "site_assignments": ["site_001", "site_002", "site_003"],
  "active_site": "site_001"
}

// Queries automatically filtered to active site
```

---

## Authorization Layer 2: Row-Level Security (RLS)

### Database-Enforced Access Control

**PostgreSQL RLS** policies enforce access control **at the database level**, ensuring application code cannot bypass restrictions.

**Key Features**:
- Automatic query filtering based on JWT claims
- Cannot be disabled by application
- Policies evaluated on every database operation
- Independent of application logic

### RLS Policy Categories

**1. User Data Isolation**:
```sql
-- Users can only access their own data
CREATE POLICY patient_select_own ON record_state
    FOR SELECT TO authenticated
    USING (patient_id = current_user_id() AND current_user_role() = 'USER');
```

**2. Site-Scoped Access**:
```sql
-- Investigators limited to assigned sites
CREATE POLICY investigator_select_site ON record_state
    FOR SELECT TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND site_id = current_user_active_site()
    );
```

**3. Role-Based Permissions**:
```sql
-- Analysts have read-only access
-- No INSERT/UPDATE/DELETE policies defined for ANALYST role
```

**See**: prd-security-RLS.md for complete RLS policy specifications

---

## Access Control Matrix

| Resource | Patient | Investigator | Analyst | Sponsor | Auditor | Admin |
|----------|---------|--------------|---------|---------|---------|-------|
| Own diary entries | Read/Write | Read-only (site) | - | - | Read-only | Read/Write |
| Other patient entries | - | Read-only (site) | Read-only (site) | Read-only (de-ID) | Read-only | Read/Write |
| Annotations | View own | Create (site) | - | - | View all | Create |
| Site configuration | - | View (site) | View (site) | View all | View all | Full |
| User management | View own | - | - | Create Investigators/Analysts | - | Full |
| Audit trail | View own | View (site) | View (site) | View all (de-ID) | View all | View all |

**Legend**:
- **Read/Write**: Full CRUD operations
- **Read-only**: SELECT only
- **site**: Limited to assigned sites
- **de-ID**: De-identified data only
- **-**: No access

---

## Break-Glass Access

### Emergency Access for Administrators

**Use Case**: Administrator needs temporary elevated access for emergency troubleshooting.

**Requirements**:
1. Must create **elevation ticket** with justification
2. Access granted with **time-to-live (TTL)** (e.g., 2 hours)
3. All actions logged with ticket reference
4. Cannot access PHI by default (even with break-glass)

**Process**:
```javascript
// Admin requests break-glass access
const ticket = await createElevationTicket({
  reason: "Critical system issue affecting data sync",
  requested_permissions: ["view_all_sites"],
  requested_duration_hours: 2,
});

// Approval (can be auto-approved or require sponsor approval)
await approveElevationTicket(ticket.id);

// JWT updated with temporary permissions
{
  "role": "ADMIN",
  "elevation_ticket": "TICKET-123",
  "elevated_until": "2025-01-24T16:00:00Z",
  "temp_permissions": ["view_all_sites"]
}

// After TTL expires, permissions automatically revoked
```

**Monitoring**: All break-glass access logged and reviewed weekly.

**See**: ops-security.md for break-glass monitoring procedures

---

## Threat Model: Unauthorized Access

### Threat 1: Credential Compromise

**Risk**: Attacker obtains user credentials (phishing, brute force, credential stuffing)

**Mitigations**:
- ✅ MFA required for privileged users
- ✅ Strong password requirements
- ✅ Account lockout after failed attempts
- ✅ Session timeout
- ✅ Failed login monitoring and alerts

### Threat 2: Session Hijacking

**Risk**: Attacker steals session token (XSS, man-in-the-middle, physical access)

**Mitigations**:
- ✅ JWT tokens with short expiration
- ✅ TLS 1.3 for all connections
- ✅ Secure, HttpOnly cookies
- ✅ Automatic logout on inactivity
- ✅ Session invalidation on suspicious activity

### Threat 3: Privilege Escalation

**Risk**: User gains access beyond their authorized role/scope

**Mitigations**:
- ✅ RLS policies enforce authorization at database level
- ✅ Cannot be bypassed by application code
- ✅ Role changes logged and audited
- ✅ Single active role prevents role confusion
- ✅ Site assignments enforced by RLS

### Threat 4: Insider Threat

**Risk**: Authorized user abuses legitimate access

**Mitigations**:
- ✅ Principle of least privilege (minimal necessary access)
- ✅ Separation of duties (no single user has all permissions)
- ✅ All actions logged with user attribution
- ✅ Regular access reviews
- ✅ Break-glass requires justification and TTL
- ✅ Anomaly detection for unusual access patterns

### Threat 5: Cross-Sponsor Access

**Risk**: User from Sponsor A tries to access Sponsor B data

**Mitigations**:
- ✅ Complete infrastructure isolation (separate Supabase instances)
- ✅ Separate JWT secrets per sponsor
- ✅ JWTs cannot cross sponsor boundaries
- ✅ No shared authentication system
- ✅ Mobile app connects to single sponsor per enrollment

---

## Authentication & Authorization Testing

### Test Categories

**1. Authentication Tests**:
- Login with valid credentials succeeds
- Login with invalid credentials fails
- Account lockout after N failed attempts
- MFA required for privileged users
- Password reset workflow secure
- Session expires after timeout

**2. Authorization Tests**:
- User can access own data only
- User cannot access other users' data
- Investigator limited to assigned sites
- Investigator cannot access unassigned sites
- Analyst has read-only access (write operations fail)
- Admin actions logged

**3. RLS Policy Tests**:
```sql
-- Test user isolation
SET request.jwt.claims = '{"sub": "patient_001", "role": "USER"}';
SELECT COUNT(*) FROM record_state WHERE patient_id != 'patient_001';
-- Should return 0

-- Test site scoping
SET request.jwt.claims = '{"sub": "inv_001", "role": "INVESTIGATOR", "active_site": "site_001"}';
SELECT COUNT(*) FROM record_state WHERE site_id != 'site_001';
-- Should return 0
```

**See**: ops-security.md for testing procedures

---

## Access Review Procedures

### Quarterly Access Reviews

**Process**:
1. Generate report of all users and their roles
2. For each user, verify:
   - Current role assignment is correct
   - Site assignments are correct (for site-scoped roles)
   - MFA enabled (for privileged users)
   - Last login date (flag inactive accounts)
3. Review elevation tickets from past quarter
4. Document review and any changes made

### Role Change Process

**Requirements**:
1. Request submitted by authorized personnel
2. Justification documented
3. Approval from appropriate authority
4. Change logged in role_change_log table
5. User notified of role change

**Logging**:
```sql
INSERT INTO role_change_log (
  user_id,
  old_role,
  new_role,
  changed_by,
  change_reason,
  approval_ticket
) VALUES (...);
```

---

## Security Monitoring

### Real-Time Alerts

**Immediate notification for**:
- Multiple failed login attempts (>5 in 15 minutes)
- MFA disabled for privileged user
- Role change without approval ticket
- Break-glass access requested
- Suspicious access patterns (e.g., access from unusual location)

### Daily Reports

**Generated each morning**:
- Failed authentication attempts (previous 24 hours)
- New user registrations
- Role changes
- Active elevation tickets

### Weekly Digest

**Sent to security team**:
- Summary of access reviews completed
- Elevation tickets summary
- Failed login trends
- Inactive accounts (>90 days)

**See**: ops-operations.md for operational monitoring procedures

---

## Developer Responsibilities

### Secure Authentication Implementation

**Required**:
- ✅ Always use Supabase Auth for authentication (never custom auth)
- ✅ Never bypass RLS policies with service role key in client code
- ✅ Validate JWT on every request
- ✅ Use parameterized queries (no SQL injection)
- ✅ Never log authentication tokens

**Forbidden**:
- ❌ Storing passwords in plain text
- ❌ Custom authentication schemes
- ❌ Client-side only authorization checks
- ❌ Disabling RLS for convenience
- ❌ Using service role key in client applications

**See**: dev-core-practices.md for development standards

---

## References

- **Role Definitions**: prd-security-RBAC.md
- **RLS Policies**: prd-security-RLS.md
- **Data Privacy**: prd-security-data-classification.md
- **Audit Requirements**: prd-clinical-trials.md
- **Audit Implementation**: prd-database.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Security Operations**: ops-security.md
- **Authentication Setup**: ops-security-authentication.md

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 2.0 | 2025-01-24 | Scope revision: Authentication & authorization only | Development Team |
| 1.0 | 2025-01-24 | Initial security architecture (superseded) | Development Team |

---

**Document Classification**: Internal Use - Security Architecture
**Review Frequency**: Quarterly or after security incidents
**Owner**: Security Team / Technical Lead
