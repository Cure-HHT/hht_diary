

---

# Security Details (from prd-security.md)

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

### REQ-d00003: Supabase Auth Configuration Per Sponsor

**Level**: Dev | **Implements**: p00002, o00003 | **Status**: Active

The application SHALL integrate with Supabase Auth for user authentication, with each sponsor using their dedicated Supabase Auth instance configured for their specific requirements.

Authentication integration SHALL include:
- Initialize Supabase client with sponsor-specific project URL and anon key
- Configure JWT verification using sponsor's Supabase project secrets
- Implement MFA enrollment and verification flows
- Handle authentication state changes (login, logout, session refresh)
- Store authentication tokens securely on device

**Rationale**: Implements MFA requirement (p00002) and project isolation (o00003) at the application code level. Each sponsor's Supabase project has independent authentication configuration, ensuring complete user isolation between sponsors.

**Acceptance Criteria**:
- App initializes Supabase client from sponsor-specific config file
- MFA can be enabled/required based on user role
- Authentication tokens scoped to single sponsor project
- Session refresh handled automatically
- Logout clears all authentication state
- Auth errors handled gracefully with user feedback

---

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

### JWT Token Structure

**Claims in JWT** (custom claims added via Supabase Auth hook):

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

### REQ-d00008: MFA Enrollment and Verification Implementation

**Level**: Dev | **Implements**: o00006 | **Status**: Active

The application SHALL implement multi-factor authentication enrollment and verification flows using Supabase Auth's MFA capabilities, enforcing additional authentication factor for clinical staff, administrators, and sponsor personnel.

Implementation SHALL include:
- MFA enrollment UI displaying QR code for TOTP authenticator app registration
- TOTP verification code input and validation
- Backup code generation and secure storage
- MFA status tracking in user profile
- Grace period handling (max 7 days) for initial MFA enrollment
- MFA verification required at each login for enrolled users
- Error handling for invalid codes with rate limiting

**Rationale**: Implements MFA configuration (o00006) at the application code level. Supabase Auth provides TOTP-based MFA capabilities that require application integration for enrollment and verification flows.

**Acceptance Criteria**:
- MFA enrollment flow displays QR code and verifies first code
- Staff accounts cannot bypass MFA after grace period expires
- MFA verification required at each login session
- Backup codes generated and securely stored
- Invalid code attempts rate limited (max 5 per minute)
- MFA events logged in authentication audit trail

---

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

### REQ-d00009: Role-Based Permission Enforcement Implementation

**Level**: Dev | **Implements**: o00007 | **Status**: Active

The application SHALL implement role-based permission enforcement by reading user roles from JWT claims and restricting UI features and API calls based on role permissions, ensuring consistent access control across mobile and web applications.

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

### Single Active Role Context

**Principle**: Users with multiple roles must select **one active role** per session.

**Why**: Ensures all actions are clearly attributed to specific role for audit purposes.

**Implementation**:

### Single Active Site Context (Site-Scoped Roles)

**Applies to**: Investigators, Analysts

**Principle**: Users assigned to multiple sites must select **one active site** for current session.

**Why**: Prevents accidental cross-site actions, simplifies audit trail.

**Implementation**:

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

**2. Site-Scoped Access**:

**3. Role-Based Permissions**:

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


---

# Data Classification (from prd-security-data-classification.md)

# TODO: Review if this file contains information redundant to other files.
# TODO: Mark redundant information with TODO: replace with reference to other file.section.paragraph reference
# TODO: Implement replacement of references noted in other TODOs

# Data Classification and Privacy Architecture

> **Purpose**: Document data classification and justify encryption strategy for compliance audits
>
> **Audience**: Compliance officers, auditors, security reviewers, developers
>
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: prd-security.md for authentication and authorization

**Version**: 1.1.0 | **Date**: 2025-01-24

---

## Executive Summary

This clinical trial diary database implements a **privacy-by-design** architecture that **separates patient identity from clinical data**. The database contains **de-identified clinical observations only** and does not store protected health information (PHI) or personally identifiable information (PII).

**Key Principle**: Patient identity is managed by the authentication system (Supabase Auth). The database uses de-identified study participant IDs to link clinical data without exposing patient identity.

---

## Multi-Sponsor Privacy Architecture

### Infrastructure-Level Isolation

**Deployment Model**: Each sponsor has a dedicated Supabase instance, providing complete data isolation:

```
Sponsor A Environment          Sponsor B Environment
┌─────────────────────────┐   ┌─────────────────────────┐
│ Supabase Project A      │   │ Supabase Project B      │
│ ├─ PostgreSQL Database  │   │ ├─ PostgreSQL Database  │
│ ├─ Supabase Auth        │   │ ├─ Supabase Auth        │
│ └─ Separate encryption  │   │ └─ Separate encryption  │
└─────────────────────────┘   └─────────────────────────┘
```

**Privacy Benefits**:
- **Physical Separation**: No shared database infrastructure
- **Independent Encryption**: Each sponsor has separate encryption keys
- **Isolated Auth**: No shared authentication system or user database
- **Breach Containment**: Compromise of Sponsor A data cannot expose Sponsor B data
- **Independent Compliance**: Each sponsor can implement their own privacy policies

**See**: prd-architecture-multi-sponsor.md for complete architecture

---

## Data Classification

### De-Identified Data (Stored in Database)

#### Clinical Trial Data
**Location**: `record_audit.data` (JSONB), `record_state.current_data` (JSONB)

**Contains**:
- Diary entries (symptom logs, activity data)
- Clinical observations
- Non-identifying health metrics
- Timestamps of events

**Does NOT contain**:
- Patient names
- Dates of birth
- Social security numbers
- Medical record numbers
- Any direct identifiers

**Classification**: De-identified clinical data
**Encryption**: At-rest (database level), In-transit (TLS)
**Justification**: No PHI/PII present; suitable for regulatory review

#### Study Participant Identifiers
**Location**: `record_audit.patient_id`, `user_site_assignments.patient_id`, `user_site_assignments.study_patient_id`

**Contains**:
- Randomized study participant IDs
- Site-specific enrollment identifiers

**Does NOT contain**:
- Real names or contact information
- Any re-identification keys in same database

**Classification**: De-identified research identifiers
**Encryption**: At-rest (database level), In-transit (TLS)
**Justification**: Random IDs cannot re-identify patients without external key

#### Site Information
**Location**: `sites` table

**Contains**:
- Clinical site names (e.g., "Memorial Hospital Clinical Research")
- Site addresses (business locations)
- Site contact information (business phone/email)

**Classification**: Public or business information
**Encryption**: At-rest (database level), In-transit (TLS)
**Justification**: Business contact information, not personal health information

#### Investigator Information
**Location**: `investigator_site_assignments`, `user_profiles`

**Contains**:
- Investigator user IDs (references to auth system)
- Role assignments
- Email addresses (business/professional)

**Does NOT contain**:
- Personal contact information
- Home addresses
- Personal identification numbers

**Classification**: Professional contact information
**Encryption**: At-rest (database level), In-transit (TLS)
**Justification**: Business email addresses and role assignments

---

### Identified Data (NOT Stored in Database)

#### Patient Identity
**Location**: Supabase Auth system (separate from application database)

**Contains**:
- Real names
- Email addresses
- Phone numbers (if provided)
- Authentication credentials

**Classification**: Personally Identifiable Information (PII)
**Encryption**: Managed by Supabase Auth
**Access**: Strictly controlled, separate from clinical data

#### Re-Identification Key
**Location**: Secure key management system (outside database scope)

**Contains**:
- Mapping between real patient identities and study participant IDs

**Classification**: Critical security asset
**Storage**: NOT in this database
**Access**: Restricted to authorized study personnel only

---

## Encryption Strategy

### REQ-d00010: Data Encryption Implementation

**Level**: Dev | **Implements**: p00017 | **Status**: Active

The application SHALL implement data encryption at rest and in transit using platform-provided encryption capabilities, ensuring all clinical trial data is protected from unauthorized access during storage and transmission.

Implementation SHALL include:
- TLS/SSL configuration for all HTTP connections to Supabase (HTTPS enforced)
- Secure local storage encryption for SQLite database on mobile devices
- Platform keychain/keystore usage for authentication token storage
- TLS certificate validation preventing man-in-the-middle attacks
- Encrypted backup files for local data
- No plaintext storage of sensitive configuration values

**Rationale**: Implements data encryption requirement (p00017) at the application code level. Supabase provides database-level encryption at rest, while application must ensure encrypted transit (TLS) and secure local storage on mobile devices.

**Acceptance Criteria**:
- All API requests use HTTPS (TLS 1.2 or higher)
- SQLite database encrypted on device using platform encryption
- Authentication tokens stored in secure keychain (iOS Keychain, Android Keystore)
- TLS certificate validation enabled and tested
- Local backups encrypted with device encryption key
- No sensitive data logged in plaintext

---

### 1. Encryption at Rest

**Provider**: Supabase (PostgreSQL)
**Algorithm**: AES-256
**Scope**: Entire database

**Purpose**:
- Protect data integrity
- Prevent unauthorized physical access to storage
- Compliance with data security requirements

**What is encrypted**:
✅ All tables and indexes
✅ Database backups
✅ Write-ahead logs (WAL)
✅ Temporary files

**Key Management**: Managed by Supabase infrastructure with automatic key rotation

### 2. Encryption in Transit

**Protocol**: TLS 1.3 / TLS 1.2
**Scope**: All database connections

**Purpose**:
- Prevent network eavesdropping
- Ensure data integrity during transmission
- Authenticate server identity

**Required for**:
✅ Application-to-database connections
✅ Admin database access
✅ Backup/replication traffic

**Certificate Management**: Managed by Supabase

### 3. Field-Level Encryption

**Status**: NOT IMPLEMENTED

**Justification**:
1. **No PHI/PII in Database**: Data is de-identified; no personal health information or personally identifiable information stored
2. **Regulatory Compliance**: Auditors and regulators need to read clinical trial data; field-level encryption would obstruct legitimate audit activities
3. **Data Utility**: Clinical researchers need queryable data; encryption prevents SQL operations
4. **Separation of Concerns**: Patient identity managed by separate authentication system
5. **Risk Assessment**: Risk of database compromise mitigated by database-level encryption, access controls, and audit trails

**When field-level encryption WOULD be required**:
- ❌ If database stored patient names → Not applicable (uses study IDs)
- ❌ If database stored SSNs or MRNs → Not applicable (none stored)
- ❌ If database stored re-identification keys → Not applicable (keys stored separately)
- ❌ If single breach exposed identity + clinical data → Not applicable (separated by design)

---

## Privacy-by-Design Architecture

### Separation of Identity and Clinical Data

```
┌─────────────────────────────────┐
│   Supabase Auth (Identity)      │
│                                  │
│  - Real names                    │
│  - Email addresses               │
│  - Authentication                │
└────────────┬────────────────────┘
             │
             │ Authentication only
             │ (JWT with study_id)
             ▼
┌─────────────────────────────────┐
│   Application Database           │
│   (Clinical Data)                │
│                                  │
│  - Study participant IDs         │
│  - De-identified diary entries   │
│  - Clinical observations         │
│  - Audit trail                   │
└─────────────────────────────────┘

         No link in database
              between
         identity and data
```

### Re-Identification Protection

**Requirement**: Re-identify patient for medical emergency or study conclusion

**Implementation**:
1. Secure key management system (outside database) maintains mapping
2. Access to re-identification key requires:
   - Multi-factor authentication
   - Authorization by principal investigator
   - Logged and audited access
   - Business justification
3. Re-identification process documented in study protocol

**Database role**: Stores only de-identified data; no re-identification capability

---

## Compliance Justification

### FDA 21 CFR Part 11

**Requirement**: "Electronic records shall be accurate, reliable, and tamper-evident"

**Compliance**:
- ✅ Encryption at rest protects data integrity
- ✅ Audit trail captures all modifications
- ✅ Cryptographic hashing ensures tamper-evidence
- ✅ Access controls prevent unauthorized changes

**Field-level encryption**: Not required for de-identified research data

### HIPAA

**Requirement**: Protect PHI through encryption or alternative security measures

**Compliance**:
- ✅ No PHI stored in database (de-identified data only)
- ✅ Safe Harbor method: All 18 HIPAA identifiers removed
- ✅ Patient identity managed separately
- ✅ Re-identification keys secured outside database

**Field-level encryption**: Not applicable (no PHI in database)

### GDPR (if applicable)

**Requirement**: Pseudonymization and encryption

**Compliance**:
- ✅ Pseudonymization: Study participant IDs used
- ✅ Encryption: At-rest and in-transit
- ✅ Right to be forgotten: Supported via soft delete
- ✅ Data minimization: Only clinical data stored

**Field-level encryption**: Not required for pseudonymized data with proper access controls

---

## Security Controls (Beyond Encryption)

### Access Controls
- Row-level security (RLS) policies
- Role-based access control (RBAC)
- Multi-factor authentication for investigators/admins
- Session management and timeout

### Audit Trail
- Immutable audit log (append-only)
- Cryptographic tamper detection
- Complete change history
- User attribution for all actions

### Network Security
- TLS 1.2+ for all connections
- Certificate validation
- No mixed content (all resources over HTTPS)
- Firewall rules restricting database access

### Operational Security
- Regular security audits
- Vulnerability scanning
- Penetration testing
- Incident response procedures

---

## Risk Assessment

### Threat: Database Compromise

**Scenario**: Attacker gains unauthorized access to database

**Impact with current architecture**:
- ⚠️ Clinical diary data exposed
- ✅ Patient identities NOT exposed (stored separately)
- ✅ Cannot re-identify patients without external key
- ✅ Audit trail detects unauthorized access
- ✅ Encryption at rest limits physical storage compromise

**Mitigation**:
- Defense in depth: Multiple layers of security
- Monitoring and alerting for suspicious access
- Regular security reviews
- Incident response plan

### Threat: Network Eavesdropping

**Scenario**: Attacker intercepts network traffic

**Impact with current architecture**:
- ✅ TLS encryption prevents reading data in transit
- ✅ Certificate validation prevents man-in-the-middle
- ✅ No sensitive data exposed

### Threat: Insider Abuse

**Scenario**: Authorized user attempts unauthorized data access

**Impact with current architecture**:
- ✅ RLS policies limit data visibility by role
- ✅ Audit trail logs all access attempts
- ✅ Cannot re-identify patients without external key access
- ✅ Regular access reviews detect anomalies

---

## Developer Guidelines

### DO:
✅ Use parameterized queries to prevent SQL injection
✅ Validate all user input
✅ Use HTTPS for all application connections
✅ Implement certificate pinning in mobile apps
✅ Log security events for monitoring
✅ Follow least privilege principle
✅ Use study participant IDs, never request real names
✅ Treat all diary data as confidential (even though de-identified)

### DON'T:
❌ Store patient names, SSNs, or direct identifiers in database
❌ Store re-identification keys in application database
❌ Bypass RLS policies
❌ Log sensitive data in application logs
❌ Share database credentials
❌ Implement custom encryption (use platform-provided)
❌ Store unvalidated user input

---

## Audit Checklist

For compliance audits, verify:

- [ ] Database encryption at rest enabled
- [ ] TLS 1.2+ enforced for all connections
- [ ] No PHI/PII in database tables
- [ ] Study participant IDs are de-identified
- [ ] Patient identity managed separately (Supabase Auth)
- [ ] Re-identification keys stored securely outside database
- [ ] RLS policies enforced on all tables
- [ ] Audit trail immutable and tamper-evident
- [ ] Access controls follow least privilege
- [ ] Multi-factor authentication enabled for privileged users
- [ ] Regular security audits conducted
- [ ] Incident response procedures documented

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-10-14 | Initial documentation | Development Team |

---

## References

- FDA 21 CFR Part 11: Electronic Records and Electronic Signatures
- HIPAA Privacy Rule: De-identification Standards (45 CFR 164.514)
- GDPR Article 32: Security of Processing
- NIST SP 800-122: Guide to Protecting PII
- ICH E6(R2): Good Clinical Practice Guidelines

---

**Document Classification**: Internal Use - Security Documentation
**Review Frequency**: Annually or when architecture changes
**Owner**: Technical Lead / Security Team
