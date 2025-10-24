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
