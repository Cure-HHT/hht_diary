# Mobile App Operational Validation

**Component**: Clinical Diary Mobile Application
**Version**: 1.0
**Audience**: QA/Validation Team
**Status**: Template

---

## Overview

This directory contains validation documentation for the production mobile application deployed to Apple App Store and Google Play Store.

### Scope

The mobile app is a **shared executable** containing configurations for all active sponsors. Validation focuses on verifying:
- App deployment to app stores
- Multi-sponsor configuration system
- Offline-first data entry
- Data synchronization with sponsor databases
- Security and encryption
- User experience and accessibility

### Key Characteristic

Unlike sponsor-specific components (portal, database), the mobile app is a single shared executable. However, each sponsor receives their own validation report that may differ based on:
- **Device support**: BYOD (iOS + Android) vs tablets-only (Android)
- **Feature set**: Enabled features per sponsor configuration
- **Integration**: EDC sync requirements (proxy mode vs endpoint mode)

**Example**:
- **Sponsor TTN**: Validates Android tablets only (investigator-provided devices)
- **Sponsor CAL**: Validates BYOD on iOS and Android (patient-owned devices)

Even though the mobile app executable is identical, the validation scope and acceptance criteria differ.

---

## Validation Approach

### Risk-Based Validation

Mobile app validation uses a risk-based approach focusing on:

**High Risk**:
- Data integrity (offline sync, event sourcing)
- Security (encryption, authentication)
- Sponsor isolation (configuration loading)

**Medium Risk**:
- User interface functionality
- Device compatibility
- Accessibility

**Low Risk**:
- Branding and styling
- Non-critical UI elements

### Validation Levels

**Installation Qualification (IQ)**:
- Verify app deployed to app stores correctly
- Verify app version and build number
- Verify signing certificates
- Verify app metadata (description, screenshots)

**Operational Qualification (OQ)**:
- Verify app functions per requirements
- Verify offline data entry works
- Verify data synchronization
- Verify sponsor configuration loading

**Performance Qualification (PQ)**:
- Verify app performs reliably under real-world conditions
- Verify sync performance with poor connectivity
- Verify battery usage acceptable
- Verify storage requirements reasonable

---

## Directory Structure

```
mobile-app/
├── README.md                       # This file
├── validation-plan.md              # Overall validation strategy
├── test-protocols/
│   ├── IQ-001-deployment.md        # App store deployment verification
│   ├── OQ-001-enrollment.md        # Patient enrollment flow
│   ├── OQ-002-offline-entry.md     # Offline data entry
│   ├── OQ-003-synchronization.md   # Data sync to database
│   ├── OQ-004-security.md          # Authentication and encryption
│   ├── OQ-005-configuration.md     # Sponsor configuration loading
│   └── PQ-001-performance.md       # Performance under load
├── test-results/
│   └── {version}/                  # Results for each validated version
│       ├── IQ-001-results.md
│       ├── OQ-001-results.md
│       └── ...
└── validation-report.md            # Summary report
```

---

## Requirements Coverage

This validation covers the following requirements:

### Product Requirements (PRD)

| Requirement | Title | Validation Protocol |
| --- | --- | --- |
| REQ-p00006 | Offline-First Data Entry | OQ-002, PQ-001 |
| REQ-p00007 | Automatic Sponsor Configuration | OQ-005 |
| REQ-p00008 | Single Mobile App for All Sponsors | IQ-001, OQ-005 |

### Development Requirements (DEV)

| Requirement | Title | Validation Protocol |
| --- | --- | --- |
| REQ-d00004 | Local-First Data Entry Implementation | OQ-002 |
| REQ-d00005 | Sponsor Configuration Detection Implementation | OQ-005 |
| REQ-d00006 | Mobile App Build and Release Process | IQ-001 |
| REQ-d00013 | Application Instance UUID Generation | OQ-004 |

### Operations Requirements (OPS)

| Requirement | Title | Validation Protocol |
| --- | --- | --- |
| REQ-o00010 | Mobile App Release Process | IQ-001 |

---

## Test Protocol Overview

### IQ-001: Deployment Verification

**Purpose**: Verify app deployed correctly to app stores

**Key Tests**:
- App listing exists in Apple App Store
- App listing exists in Google Play Store
- App version matches build artifacts
- App signing certificate valid
- App permissions appropriate
- App metadata accurate

**Acceptance**: App deployed and accessible in both stores

---

### OQ-001: Enrollment Flow

**Purpose**: Verify patient enrollment works correctly

**Key Tests**:
- Enrollment link opens correct sponsor
- QR code scanning works
- Sponsor branding loads correctly
- Enrollment token validated
- Patient linked to correct sponsor database
- Enrollment recorded in audit trail

**Acceptance**: Patients successfully enroll via link/QR code

---

### OQ-002: Offline Data Entry

**Purpose**: Verify offline-first data entry per REQ-p00006

**Key Tests**:
- App functions without network connectivity
- Data entered offline persists locally
- Encrypted local storage verified
- User can continue entering data offline
- Offline queue visible to user
- No data loss on app restart

**Acceptance**: All data entry works offline, data persists

---

### OQ-003: Data Synchronization

**Purpose**: Verify offline data syncs to database

**Key Tests**:
- Offline events sync when connectivity restored
- Events appear in database `record_audit` table
- Event order preserved during sync
- Conflict resolution works correctly
- Sync retries on failure
- Sync status visible to user

**Acceptance**: 100% of offline events sync successfully

---

### OQ-004: Security

**Purpose**: Verify authentication and encryption per REQ-d00013

**Key Tests**:
- App generates unique instance UUID
- Enrollment token validated correctly
- Local data encrypted at rest
- Network communication encrypted (TLS)
- Authentication required for sensitive operations
- Session timeout enforced

**Acceptance**: All security requirements met

---

### OQ-005: Configuration Loading

**Purpose**: Verify sponsor configuration loads per REQ-p00007, REQ-d00005

**Key Tests**:
- Correct sponsor detected from enrollment token
- Sponsor branding applied correctly
- Sponsor Supabase URL configured correctly
- Sponsor-specific features enabled/disabled
- No cross-sponsor configuration leakage
- Configuration changes require re-enrollment

**Acceptance**: Correct sponsor configuration loaded, no cross-contamination

---

### PQ-001: Performance

**Purpose**: Verify acceptable performance under real-world conditions

**Key Tests**:
- App launch time <3 seconds
- Data entry responsive (<100ms latency)
- Sync completes within reasonable time (100 events <30 seconds)
- App operates on poor connectivity (2G)
- Battery usage acceptable (<5% per hour active use)
- Storage requirements reasonable (<50MB)

**Acceptance**: All performance targets met

---

## Validation Execution

### Pre-Validation Setup

Before executing validation:

1. **Identify app version** to validate (e.g., `v1.2.3`)
2. **Verify app deployed** to app stores
3. **Create test environment**:
   - Test sponsor database (staging Supabase project)
   - Test enrollment tokens
   - Test user accounts
4. **Prepare test devices**:
   - iOS device(s) per sponsor support (BYOD vs tablets)
   - Android device(s) per sponsor support
   - Various OS versions if applicable
5. **Document test environment** in validation report

### Execution Process

For each test protocol:

1. **Review protocol**: Ensure test steps are current
2. **Execute tests**: Follow protocol step-by-step
3. **Document results**: Record actual results for each test
4. **Capture evidence**: Screenshots, logs, database queries
5. **Note deviations**: Document any unexpected behavior
6. **Pass/fail decision**: Compare results to acceptance criteria

### Post-Validation

After all protocols executed:

1. **Review results**: Ensure all tests passed
2. **Address failures**: Investigate and resolve any failed tests
3. **Re-test if needed**: Re-execute failed tests after fixes
4. **Generate validation report**: Summarize results
5. **Archive artifacts**: Store validation package with build artifacts

---

## Validation Report

The validation report (` validation-report.md`) includes:

**Executive Summary**:
- App version validated
- Validation date range
- Overall validation conclusion (pass/fail)

**Validation Scope**:
- Components validated
- Requirements covered
- Test protocols executed

**Test Results Summary**:
- Test protocol results (pass/fail)
- Deviations and resolutions
- Evidence references

**Traceability Matrix**:
- Requirements-to-test-protocol mapping
- Test coverage analysis

**Conclusion**:
- Validation statement
- Approvals (QA lead, sponsor representative)
- Effective date

---

## Sponsor-Specific Customization

### Customization Points

When customizing this template for a sponsor:

1. **Device Support**:
   - Update test protocols for BYOD vs tablets-only
   - Add/remove iOS testing if not applicable
   - Document supported OS versions

2. **Feature Set**:
   - Validate sponsor-enabled features only
   - Skip protocols for disabled features
   - Add protocols for custom features

3. **Integration Mode**:
   - Endpoint mode: Validate data stays in sponsor database
   - Proxy mode: Validate EDC sync (add OQ-006-edc-sync.md)

4. **Acceptance Criteria**:
   - Customize performance targets (e.g., battery usage)
   - Adjust sync thresholds for sponsor's connectivity
   - Define sponsor-specific quality gates

### Example: Tablet-Only Sponsor

For sponsor TTN (Android tablets only):

**Remove**:
- iOS test protocols
- BYOD-specific tests (user-owned device scenarios)

**Add**:
- Tablet-specific tests (landscape orientation)
- Device provisioning validation (IT-managed devices)

**Update**:
- Acceptance criteria for tablet battery life
- Storage requirements for larger tablets

---

## Revalidation Triggers

Revalidation required when:

1. **New app version released**:
   - Full validation for major versions (1.x.0)
   - Regression testing for minor versions (1.0.x)
   - Smoke testing for patches (1.0.0.x)

2. **Configuration changes**:
   - Sponsor feature enable/disable
   - Integration mode changes (endpoint ↔ proxy)

3. **Infrastructure changes**:
   - Database schema changes
   - API changes affecting mobile app

4. **Annual validation**:
   - Per 21 CFR Part 11 requirements
   - Execute critical test protocols
   - Verify ongoing compliance

---

## References

### Requirements

- `spec/prd-diary-app.md` - Mobile app product requirements
- `spec/dev-app.md` - Mobile app implementation requirements
- `spec/prd-clinical-trials.md` - FDA compliance requirements

### Architecture

- `spec/prd-architecture-multi-sponsor.md` - Multi-sponsor architecture
- `spec/dev-architecture-multi-sponsor.md` - Implementation details

### Related Validation

- `../operations/README.md` - DevOps validation (monitoring, backups)
- `../database/README.md` - Database validation (if applicable)

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-13 | 1.0 | Development Team | Initial validation framework |
