# PRD Requirements Plan

## Identified PRD Requirements (Product Level - WHAT)

### Already Added (p00001-p00005)
- ✅ **REQ-p00001**: Complete Multi-Sponsor Data Separation (prd-security.md)
- ✅ **REQ-p00002**: Multi-Factor Authentication for Staff (prd-security.md)
- ✅ **REQ-p00003**: Separate Database Per Sponsor (prd-database.md)
- ✅ **REQ-p00004**: Immutable Audit Trail via Event Sourcing (prd-database-event-sourcing.md)
- ✅ **REQ-p00005**: Role-Based Access Control (prd-security-RBAC.md)

### To Add - Core Functional Requirements

**prd-app.md** (Mobile Application):
- **REQ-p00006**: Offline-First Data Entry
  - Patients SHALL be able to record diary entries without internet connectivity
  - Entries saved locally and synchronized when connection available

- **REQ-p00007**: Automatic Sponsor Configuration
  - App SHALL automatically configure for correct sponsor based on enrollment link
  - Patients SHALL NOT manually select sponsor or study

**prd-architecture-multi-sponsor.md** (Architecture):
- **REQ-p00008**: Single Mobile App for All Sponsors
  - One app in app stores SHALL serve all pharmaceutical sponsors
  - Each sponsor's branding and configuration loaded dynamically

- **REQ-p00009**: Sponsor-Specific Web Portals
  - Each sponsor SHALL have dedicated web portal at unique URL
  - Portal SHALL display only that sponsor's data

**prd-clinical-trials.md** (Compliance):
- **REQ-p00010**: FDA 21 CFR Part 11 Compliance
  - System SHALL meet all FDA 21 CFR Part 11 requirements for electronic records
  - Including: audit trails, electronic signatures, system validation, access control

- **REQ-p00011**: ALCOA+ Data Integrity
  - All clinical data SHALL adhere to ALCOA+ principles
  - Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available

- **REQ-p00012**: Data Retention Requirements
  - Clinical trial data and audit trails SHALL be retained for minimum 7 years
  - Data SHALL remain accessible and readable throughout retention period

**prd-database.md** (Database):
- **REQ-p00013**: Complete Change History
  - System SHALL preserve complete history of all data modifications
  - Original values SHALL never be overwritten or deleted

**prd-database-event-sourcing.md** (Event Sourcing):
- (p00004 already covers core requirement)

**prd-security.md** (Security):
- (p00001, p00002 already cover core requirements)

**prd-security-RBAC.md** (Access Control):
- (p00005 already covers core requirement)

- **REQ-p00014**: Least Privilege Access
  - Users SHALL be granted minimum permissions necessary for their role
  - No user SHALL have access beyond their job function requirements

**prd-security-RLS.md** (Row-Level Security):
- **REQ-p00015**: Database-Level Access Enforcement
  - Access control SHALL be enforced at database layer, not just application layer
  - Database SHALL prevent unauthorized data access even if application bypassed

**prd-security-data-classification.md** (Privacy):
- **REQ-p00016**: Separation of Identity and Clinical Data
  - Patient identity information SHALL be stored separately from clinical trial data
  - Clinical database SHALL contain de-identified data only

- **REQ-p00017**: Data Encryption
  - Sensitive data SHALL be encrypted at rest and in transit
  - Encryption keys SHALL be managed securely per sponsor

## Rationale for This Set

These 17 requirements cover:
- Multi-sponsor isolation (p00001, p00003, p00008, p00009)
- Security & Auth (p00002, p00005, p00014, p00015, p00017)
- Compliance & Audit (p00004, p00010, p00011, p00012, p00013)
- Privacy (p00016)
- Core Functionality (p00006, p00007)

This provides comprehensive PRD coverage without overwhelming the system. Each requirement is:
- Pure "WHAT" - no implementation details
- Business/clinical/regulatory focused
- Testable and verifiable
- Foundation for Ops/Dev requirements

## Next Steps

1. Add these 12 new requirements to appropriate PRD files
2. Keep language implementation-agnostic
3. Focus on business value and regulatory compliance
4. No mention of technologies (Supabase, PostgreSQL, Flutter, etc.)
