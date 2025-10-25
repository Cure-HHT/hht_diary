# Security Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: dev-security.md for implementation details
> **See**: prd-security-RBAC.md for role definitions
> **See**: prd-security-RLS.md for data access policies
> **See**: prd-security-data-classification.md for data protection
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor isolation

---

## Executive Summary

The system protects clinical trial data through multiple layers of security, ensuring that only authorized people can access information they're permitted to see. Each sponsor's data is completely isolated from other sponsors, and patient data is protected at all times.

**Security Layers**:
- Unique accounts for each user
- Strong password requirements
- Multi-factor authentication for staff
- Role-based access control
- Database-level enforcement
- Complete activity logging

---

## Multi-Sponsor Data Isolation

### REQ-p00001: Complete Multi-Sponsor Data Separation

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL ensure complete data isolation between pharmaceutical sponsors such that no user, administrator, or automated process can access data belonging to a different sponsor.

Each sponsor SHALL operate in a completely separate environment with:
- Dedicated database instances
- Separate authentication systems
- Independent encryption keys
- Isolated user accounts

**Rationale**: Eliminates any possibility of accidental data mixing or unauthorized cross-sponsor access. Critical for regulatory compliance, sponsor trust, and competitive confidentiality.

**Acceptance Criteria**:
- Database queries cannot return records from other sponsors
- Authentication tokens are scoped to a single sponsor
- Encryption keys are never shared between sponsors
- Administrative access is limited to single sponsor
- System architecture makes cross-sponsor access technically impossible

**Traced by**: o00001, o00002, d00001

---

### What Complete Separation Means

**Different Systems Per Sponsor**:
- Different databases
- Different user accounts
- Different encryption keys
- Different authentication systems

**Practical Examples**:
- Pfizer users cannot access Novartis data
- Novartis users cannot access Merck data
- No shared login credentials
- No shared infrastructure

---

## User Authentication

### REQ-p00002: Multi-Factor Authentication for Staff

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL require multi-factor authentication (MFA) for all clinical staff, administrators, and sponsor personnel accessing the system.

MFA SHALL consist of:
1. Something the user knows (password)
2. Something the user has (time-based code from authenticator app or SMS)

The system SHALL NOT allow staff or administrator access without successful MFA completion.

**Rationale**: Clinical trial data is highly sensitive and subject to FDA 21 CFR Part 11 regulations. MFA significantly reduces the risk of unauthorized access via compromised credentials. Patients may optionally use MFA but are not required due to accessibility concerns.

**Acceptance Criteria**:
- All clinical staff accounts require MFA enrollment before first use
- Administrator accounts cannot be created without MFA
- MFA verification occurs at each login session
- Users can configure TOTP authenticator apps or SMS backup
- System logs all MFA authentication attempts (success and failure)

**Traced by**: o00003, d00002

---

### How Users Log In

**Patients**:
- Create account during enrollment
- Email and password required
- Can use Google/Apple login (optional)
- Password must be at least 8 characters
- MFA optional but recommended

**Clinical Staff** (Investigators, Analysts):
- Account created by sponsor administrator
- Strong password required (12+ characters)
- Must enable two-factor authentication (required)
- Password expires every 90 days

**Administrators**:
- Highest security requirements
- Two-factor authentication mandatory
- Strong password requirements
- All actions logged

### Two-Factor Authentication (2FA) - How It Works

**What It Is**: Extra security step beyond just password

**Process**:
1. User enters password (something they know)
2. User enters 6-digit code from phone app (something they have)
3. Both required to log in successfully

**Implementation**: Uses standard TOTP (Time-based One-Time Password) protocol compatible with Google Authenticator, Authy, 1Password, etc.

---

## Access Control

### Who Can See What

**Patients**:
- Can see only their own diary entries
- Can view their own profile
- Cannot see other patients' data
- Cannot see staff-only information

**Investigators**:
- Can view patient data at assigned clinical sites only
- Can add notes and annotations
- Cannot modify patient entries directly
- Must select one site at a time

**Analysts**:
- Can view study data (de-identified)
- Limited to assigned sites
- Read-only access
- Cannot modify any data

**Sponsors**:
- Can view aggregate data across all sites
- Can manage user accounts
- Cannot access individual patient details
- All access logged

**Auditors**:
- Read-only access to all data
- Can export audit logs
- Must provide justification for access
- All actions recorded

### How Access Control Works

**Role-Based**: Each user assigned specific role(s) with defined permissions

**Database-Enforced**: Access rules built into database itself, cannot be bypassed

**Site-Scoped**: Staff can only access data at their assigned clinical sites

**Automatic**: No manual checking required - system enforces automatically

---

## Session Security

### Active Sessions

**Session Duration**:
- Patients: 24 hours
- Clinical staff: 1 hour
- Administrators: 1 hour

**Automatic Logout**: Sessions expire after period of inactivity

**Secure Storage**: Session information encrypted and protected

**Logout**: Users can manually log out anytime

### Security Features

**Password Changes**: Immediately invalidate all active sessions

**Suspicious Activity**: Automatic logout and security alert

**Multiple Devices**: Each device has separate session

---

## Data Protection

### Encryption

**In Transit**: All data encrypted during transmission between app and server

**At Rest**: Data encrypted when stored in database

**What This Means**: Even if someone intercepts data, they cannot read it

### Privacy Protection

**Patient Identity**: Stored separately from clinical data

**De-identification**: Study data uses random IDs, not patient names

**Access Logging**: Every data access recorded with who, when, and why

---

## Security Monitoring

### What We Monitor

**Login Attempts**:
- Failed login attempts
- Successful logins from new locations
- Unusual login patterns

**Data Access**:
- Who accessed what data
- When access occurred
- What actions were performed

**System Changes**:
- User account modifications
- Permission changes
- Configuration updates

### Automated Alerts

**Suspicious Activity**:
- Multiple failed login attempts
- Access from unusual locations
- Large data exports

**Security Events**:
- Password changes
- Role modifications
- System configuration changes

---

## Compliance

### Regulatory Requirements

**FDA 21 CFR Part 11**:
- Unique user identification
- Secure access controls
- Activity logging
- Electronic signatures

**HIPAA** (when applicable):
- Protected health information security
- Access controls
- Audit trails
- Breach notification procedures

**GDPR** (EU participants):
- Data protection by design
- Access controls
- Right to access logs
- Data portability

---

## Incident Response

### If Security Issue Occurs

**Immediate Actions**:
1. Affected accounts locked automatically
2. Security team notified
3. Incident logged and investigated
4. Users notified if their data affected

**Investigation**:
- Review audit logs
- Determine scope of issue
- Identify cause
- Implement corrective actions

**Reporting**:
- Sponsor notified
- Regulatory reporting if required
- Affected patients notified

---

## Security Benefits

**For Patients**:
- Privacy protected
- Control over own data
- Transparency of who accessed records

**For Sponsors**:
- Regulatory compliance
- Protection against breaches
- Reduced liability

**For Investigators**:
- Clear access boundaries
- Protection against accusations
- Confidence in system security

**For Auditors**:
- Complete activity logs
- Verification of proper controls
- Evidence of compliance

---

## References

- **Implementation**: dev-security.md
- **Role Definitions**: prd-security-RBAC.md
- **Access Policies**: prd-security-RLS.md
- **Data Classification**: prd-security-data-classification.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Operations**: ops-security.md
