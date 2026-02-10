# Security Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Draft

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

# REQ-p00001: Complete Multi-Sponsor Data Separation

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

This requirement establishes complete data isolation between pharmaceutical sponsors to eliminate any possibility of accidental data mixing or unauthorized cross-sponsor access. Multi-sponsor platforms face unique regulatory and competitive challenges where data breaches between sponsors could violate FDA compliance, compromise competitive confidentiality, and undermine sponsor trust. By enforcing architectural isolation at multiple layers (database, authentication, encryption, and user management), the system ensures that cross-sponsor access becomes technically impossible rather than merely administratively prohibited.

## Assertions

A. The system SHALL ensure complete data isolation between pharmaceutical sponsors such that no user, administrator, or automated process can access data belonging to a different sponsor.
B. Each sponsor SHALL operate with a dedicated database instance.
C. Each sponsor SHALL operate with a separate authentication system.
D. Each sponsor SHALL operate with independent encryption keys.
E. Each sponsor SHALL operate with isolated user accounts.
F. The system SHALL NOT allow database queries to return records from other sponsors.
G. Authentication tokens SHALL be scoped to a single sponsor.
H. Encryption keys SHALL NOT be shared between sponsors.
I. Administrative access SHALL be limited to a single sponsor.
J. The system architecture SHALL make cross-sponsor access technically impossible.

*End* *Complete Multi-Sponsor Data Separation* | **Hash**: 57702900
---

## User Authentication

# REQ-p00002: Multi-Factor Authentication for Staff

**Level**: PRD | **Status**: Draft | **Implements**: p00011

## Rationale

Clinical trial data is highly sensitive and subject to FDA 21 CFR Part 11 regulations, which mandate controls to ensure that only authorized individuals can access electronic records and electronic signatures. Multi-factor authentication significantly reduces the risk of unauthorized access via compromised credentials by requiring both knowledge-based and possession-based authentication factors. This requirement applies to all clinical staff, administrators, and sponsor personnel who have elevated privileges to access, modify, or manage clinical trial data. Patients may optionally use MFA but are not required due to accessibility concerns and the lower risk profile of patient-only access.

## Assertions

A. The system SHALL require multi-factor authentication (MFA) for all clinical staff accessing the system.
B. The system SHALL require multi-factor authentication (MFA) for all administrators accessing the system.
C. The system SHALL require multi-factor authentication (MFA) for all sponsor personnel accessing the system.
D. MFA SHALL consist of something the user knows (password) as the first factor.
E. MFA SHALL consist of something the user has (time-based code from authenticator app or SMS) as the second factor.
F. The system SHALL NOT allow staff access without successful MFA completion.
G. The system SHALL NOT allow administrator access without successful MFA completion.
H. The system SHALL require all clinical staff accounts to complete MFA enrollment before first use.
I. The system SHALL NOT allow administrator accounts to be created without MFA.
J. The system SHALL perform MFA verification at each login session.
K. The system SHALL allow users to configure TOTP authenticator apps for MFA.
L. The system SHALL allow users to configure SMS as a backup MFA method.
M. The system SHALL log all MFA authentication attempts including successes.
N. The system SHALL log all MFA authentication attempts including failures.

*End* *Multi-Factor Authentication for Staff* | **Hash**: b014564d
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
