# Data Classification and Privacy Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: dev-security.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: prd-security.md for authentication and authorization

---

## Executive Summary

The system is designed with privacy as a core principle. Patient identity information is kept separate from clinical trial data, ensuring privacy protection while maintaining data needed for regulatory compliance.

**Key Principle**: The database contains de-identified clinical observations only. Patient names, contact information, and other identifying details are stored separately in the authentication system.

---

## What Data We Store (and Don't Store)

### Clinical Trial Data (What We DO Store)

**Patient Diary Entries**:
- Symptom reports
- Activity logs
- Questionnaire responses
- Medication adherence
- Timestamps of entries

**Study Information**:
- Clinical site names and locations (business addresses)
- Study protocols
- Configuration settings

**Random Identifiers**:
- Study participant IDs (random numbers)
- No connection to real identity within database

### Personal Information (What We DON'T Store in Database)

**Patient Identity** - Stored separately in authentication system:
- Real names
- Email addresses
- Phone numbers
- Dates of birth
- Social security numbers

**Why Separate**: Privacy protection. Even if clinical database is accessed, patient identities remain protected.

---

## Privacy by Design

# REQ-p00016: Separation of Identity and Clinical Data

**Level**: PRD | **Status**: Draft | **Implements**: p00010

## Rationale

Privacy by design protects patient confidentiality by ensuring that clinical trial data cannot be directly linked to patient identities. This architectural separation means that even if the clinical database is accessed or breached, patient identities remain protected. The requirement supports HIPAA privacy requirements and reduces the impact of potential privacy breaches. Clinical staff can review trial data without unnecessary exposure to personal information, maintaining the minimum necessary principle for data access.

## Assertions

A. The system SHALL store patient identity information separately from clinical trial data.
B. The clinical database SHALL contain only de-identified participant records.
C. The authentication system SHALL store patient names, email addresses, and contact information.
D. The clinical database SHALL store only random participant IDs with observations.
E. The clinical database SHALL NOT contain any direct linkage between participant ID and real identity.
F. The mapping between identity and participant ID SHALL be accessible only through the secure authentication system.
G. The system SHALL enable review of clinical data without exposing patient identities.
H. The clinical database SHALL NOT contain patient names, email addresses, or direct identifiers.
I. Participant IDs SHALL be randomly generated.
J. Participant IDs SHALL NOT be derivable from personal information.
K. The identity-to-participant mapping SHALL be isolated in the authentication system.
L. Clinical data exports SHALL contain participant IDs only.
M. Clinical data exports SHALL NOT contain real patient identities.
N. A data breach of the clinical database SHALL NOT expose patient identities.

*End* *Separation of Identity and Clinical Data* | **Hash**: ce95a5e6
---

# REQ-p00017: Data Encryption

**Level**: PRD | **Status**: Draft | **Implements**: p00016

## Rationale

This requirement protects patient privacy (p00016) and clinical trial confidentiality during transmission and storage. Encryption provides an additional protection layer beyond access controls, ensuring data remains protected even if storage media or network traffic is intercepted. The multi-sponsor architecture requires sponsor-specific encryption keys to maintain data isolation. Industry best practices for key management ensure long-term security and compliance with FDA 21 CFR Part 11 requirements for electronic record protection.

## Assertions

A. The system SHALL encrypt sensitive data at rest in database storage.
B. The system SHALL encrypt sensitive data in transit during transmission.
C. The mobile app SHALL encrypt data on patient devices before transmission.
D. The system SHALL transmit data over encrypted channels only.
E. The system SHALL use TLS 1.2 or higher for all network communication.
F. The system SHALL use HTTPS protocol for all network communication.
G. The system SHALL encrypt database storage with sponsor-specific encryption keys.
H. Encryption keys SHALL be unique per sponsor.
I. The system SHALL manage encryption keys following industry best practices.
J. The system SHALL rotate encryption keys according to security policy.
K. The system SHALL NOT allow encryption to be disabled.

*End* *Data Encryption* | **Hash**: 2ca02635
---

### Separation of Identity and Data

**Two Separate Systems**:

1. **Authentication System**: Knows who patients are
   - Real names and contact info
   - Login credentials
   - Account information

2. **Clinical Database**: Knows what data exists
   - Study participant IDs (random)
   - Clinical observations
   - No personal identifiers

**Connection**: Only the authentication system knows which real person corresponds to which participant ID.

**Benefit**: Clinical data can be reviewed without exposing patient identities.

---

## Multi-Sponsor Privacy

### Complete Isolation

Each sponsor's environment is completely separate:

**Sponsor A**:
- Own authentication system
- Own database
- Own encryption keys
- Own patient identities

**Sponsor B**:
- Different authentication system
- Different database
- Different encryption keys
- Different patient identities

**Result**: Compromise of one sponsor's system doesn't affect other sponsors.

---

## Data Protection Levels

### Public Information

**What**: Clinical site business addresses, study protocols

**Protection**: Standard encryption during transmission

**Risk Level**: Low - information is publicly available

### De-Identified Clinical Data

**What**: Diary entries linked to random participant IDs

**Protection**:
- Encrypted during transmission
- Encrypted at rest in database
- Access controls limit who can view
- All access logged

**Risk Level**: Medium - data has medical information but no direct identifiers

### Identified Personal Information

**What**: Patient names, contact information, authentication credentials

**Protection**:
- Stored in separate authentication system
- Multiple layers of encryption
- Strict access controls
- Minimal personnel have access

**Risk Level**: High - direct identifiers protected at highest level

---

## Encryption

### What Gets Encrypted

**All Data**:
- Encrypted during transmission (between app and server)
- Encrypted at rest (in database storage)
- Encryption keys secured separately

**Multiple Layers**:
- Transport layer (HTTPS/TLS)
- Database encryption
- Application-level encryption for sensitive fields

### What This Means

**For Patients**: Their data is protected even if:
- Someone intercepts network traffic
- Database backup stolen
- Server physically compromised

**For Sponsors**: Regulatory compliance and reduced breach risk

---

## De-identification Strategy

### Random Study IDs

**How It Works**:
1. Patient enrolls and creates account
2. System assigns random study participant ID
3. Clinical data tagged with random ID only
4. Real identity stays in authentication system

**Example**:
- Patient: Jane Smith (real identity - in auth system)
- Study ID: P-7492-XK (random - in clinical database)
- Link between them: Only in authentication system

**Benefit**: Clinical data can be analyzed without knowing patient identities.

### Re-identification Protection

**What**: Mapping between real identities and study IDs

**Where Stored**: Secure key management system (not in clinical database)

**Who Has Access**: Extremely limited personnel with strict oversight

**Why This Matters**: Even with access to clinical database, cannot determine which real person corresponds to which data.

---

## Regulatory Compliance

### HIPAA (United States)

When applicable:
- Protected Health Information (PHI) encrypted
- Access controls limit exposure
- Audit trails track all access
- Breach notification procedures in place

**Our Approach**: De-identification reduces PHI in clinical database, minimizing HIPAA scope.

### GDPR (European Union)

For EU participants:
- Data minimization (collect only what's needed)
- Privacy by design (built into system architecture)
- Right to access (patients can download their data)
- Right to erasure (with clinical trial exceptions)
- Data portability (standard export formats)

**Our Approach**: Separation of identity and clinical data, all data is stored in the EU and services run in EU regions, support GDPR principles.

---

## Data Retention

### How Long Data Is Kept

**Clinical Trial Data**: Minimum 7 years (regulatory requirement)

**Audit Trails**: Same retention as clinical data

**Personal Identities**: Retained for study duration plus retention period

**After Retention Period**: Data archived or securely destroyed per sponsor policy

---

## Privacy Benefits

**For Patients**:
- Identity protected even if database accessed
- Control over their own data
- Transparency of who accessed records

**For Investigators**:
- Can analyze data without unnecessary identity exposure
- Reduced privacy violation risk
- Clear guidelines on data handling

**For Sponsors**:
- Regulatory compliance (HIPAA, GDPR)
- Reduced breach liability
- Protection of confidential trial data

**For Society**:
- Enables clinical research while protecting privacy
- Maintains trust in clinical trial system
- Balances transparency and confidentiality

---

## Common Questions

**Q: If data is de-identified, how do we know which patient to contact?**
A: The authentication system maintains the link. When needed (for safety alerts, etc.), authorized personnel can look up the real identity.

**Q: What if there's a data breach?**
A: Because identity and clinical data are separated, a breach of the clinical database wouldn't expose patient identities.

**Q: Can patients be re-identified from their clinical data?**
A: Very difficult without access to both the clinical database AND the authentication system, which have separate security controls.

**Q: Is de-identified data still useful for research?**
A: Yes - researchers can analyze patterns and outcomes without knowing patient identities.

---

## References

- **Implementation**: dev-security.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security Overview**: prd-security.md
- **Access Control**: prd-security-RBAC.md
- **Compliance**: prd-clinical-trials.md
