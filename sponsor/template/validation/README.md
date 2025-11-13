# Operational System Validation

**Version**: 1.0
**Audience**: QA/Validation Team, Sponsor Operations
**Last Updated**: 2025-01-13
**Status**: Template

---

## Purpose

This directory contains operational validation documentation for the production clinical trial system. Operational validation focuses on verifying that the deployed system operates correctly in the production environment and continues to meet specifications during routine use.

**Key Focus Areas**:
- Mobile application functionality in production
- Database system operation and integrity
- Portal functionality (if deployed)
- DevOps infrastructure (monitoring, backups, incident response)

---

## Validation Approach

### FDA Compliance Context

Per FDA 21 CFR Part 11 and REQ-p00020 (System Validation and Traceability), all clinical trial systems must be validated to ensure:
- The system performs as intended
- Data integrity is maintained
- All features are traceable to documented requirements
- Changes are controlled and documented

### Validation Strategy

We follow a risk-based validation approach based on FDA guidance, focusing on:

1. **Installation Qualification (IQ)**: Verify system installed correctly
2. **Operational Qualification (OQ)**: Verify system operates per specifications
3. **Performance Qualification (PQ)**: Verify system performs reliably under real-world conditions

This is NOT a full GAMP 5 validation - we use critical thinking to design validation appropriate to our risk profile while meeting FDA requirements.

---

## Validation Structure

### Sponsor-Specific Validation

Each sponsor receives their own independent validation package in their `sponsor/{sponsor-name}/validation/` directory:

```
sponsor/{sponsor-name}/validation/
├── README.md                    # This file (customized)
├── mobile-app/                  # Mobile app validation
│   ├── validation-plan.md
│   ├── test-protocols/
│   └── validation-report.md
├── operations/                  # DevOps validation
│   ├── validation-plan.md
│   ├── monitoring/
│   ├── backup-recovery/
│   ├── incident-response/
│   └── validation-report.md
├── portal/                      # Portal validation (optional)
│   ├── validation-plan.md
│   ├── test-protocols/
│   └── validation-report.md
└── database/                    # Database validation (optional)
    ├── validation-plan.md
    ├── test-protocols/
    └── validation-report.md
```

### Template vs Sponsor Copies

- **Template** (`sponsor/template/validation/`): Exemplar version, maintained by development team
- **Sponsor Copies** (`sponsor/{sponsor-name}/validation/`): Independent copies, customized for each sponsor

Once a sponsor's validation package is created, it becomes **independent** from the template. This allows:
- Flexibility to customize for sponsor-specific requirements
- Inclusion/exclusion of optional components (portal, database)
- Sponsor-specific test scenarios (e.g., BYOD vs tablets-only)
- Independent lifecycle management

---

## System Components

### 1. Mobile App (Required)

**Scope**: Shared mobile application executable in app stores

The mobile app is a **shared executable** deployed to Apple App Store and Google Play Store. It contains configurations for all active sponsors and automatically connects to the correct sponsor based on enrollment tokens.

**Key Characteristics**:
- Single app binary shared by all sponsors
- Multi-sponsor configuration bundled in app
- Each sponsor gets their own validation report
- Sponsor-specific customizations (e.g., BYOD support, tablet-only) affect validation scope

**Validation Focus**:
- App store deployment verification
- Multi-sponsor configuration loading
- Offline functionality
- Data synchronization
- Security (encryption, authentication)

**Reference Requirements**:
- REQ-p00006: Offline-First Data Entry
- REQ-p00007: Automatic Sponsor Configuration
- REQ-p00008: Single Mobile App for All Sponsors
- REQ-d00004: Local-First Data Entry Implementation
- REQ-d00005: Sponsor Configuration Detection Implementation

See: `mobile-app/README.md`

---

### 2. Operations (Required)

**Scope**: DevOps infrastructure supporting production operations

Operational validation covers the infrastructure and processes that keep the system running:
- Uptime monitoring and alerting
- Error tracking and incident response
- Backup and disaster recovery
- Performance monitoring
- Audit trail integrity monitoring

**Key Characteristics**:
- Shared infrastructure vendor accounts (GitHub, Supabase, Netlify, Doppler)
- Sponsor-specific monitoring configurations
- Sponsor-specific incident response procedures
- Independent backup schedules per sponsor

**Validation Focus**:
- Monitoring system accuracy (uptime, errors, performance)
- Incident detection and alerting
- Backup and recovery procedures
- Audit trail tamper detection

**Reference Requirements**:
- REQ-o00045: Error Tracking and Monitoring
- REQ-o00046: Uptime Monitoring
- REQ-o00047: Performance Monitoring
- REQ-o00048: Audit Log Monitoring
- REQ-o00008: Backup and Retention Policy

See: `operations/README.md`

---

### 3. Portal (Optional)

**Scope**: Sponsor-specific web portal (if deployed)

Not all sponsors deploy a web portal. Those who do receive a dedicated portal validation package.

**Key Characteristics**:
- Sponsor-specific deployment (unique URL per sponsor)
- Optional component (not all sponsors use portals)
- Based on shared portal template
- Customizable dashboards and reports

**Validation Focus**:
- Portal deployment verification
- Role-based access control
- Data isolation verification
- Custom features validation

**Reference Requirements**:
- REQ-p00009: Sponsor-Specific Web Portals
- REQ-p00024: Portal User Roles and Permissions
- REQ-d00028-d00052: Portal implementation requirements

See: `portal/README.md`

---

### 4. Database (Optional)

**Scope**: Sponsor-specific database instance (if portal deployed)

Database validation is typically only needed when a sponsor deploys a web portal, as portal-less deployments use the mobile app exclusively.

**Key Characteristics**:
- Sponsor-specific Supabase project
- Shared schema (deployed from common `database/schema.sql`)
- Sponsor-specific data and users
- Row-level security (RLS) policies

**Validation Focus**:
- Schema deployment verification
- RLS policy enforcement
- Event sourcing integrity
- Backup and recovery procedures

**Reference Requirements**:
- REQ-p00003: Separate Database Per Sponsor
- REQ-p00004: Immutable Audit Trail via Event Sourcing
- REQ-p00015: Database-Level Access Enforcement
- REQ-d00007: Database Schema Implementation and Deployment

See: `database/README.md`

---

## Shared vs Sponsor-Specific Validation

### What's Shared (Common Validation)

Common validation scripts and procedures can be referenced by multiple sponsors to avoid duplication:

**Location**: `sponsor/template/validation/common/`

**Examples**:
- Mobile app functional test scripts (reusable across sponsors)
- Database schema validation scripts
- Standard monitoring checks

**Benefits**:
- Avoid maintaining redundant scripts
- Ensure consistency across sponsors
- Centralized updates for common procedures

### What's Sponsor-Specific

Each sponsor's validation package includes:

**Unique to Sponsor**:
- Sponsor-specific configuration validation
- Custom feature validation (e.g., EDC integration)
- Deployment environment specifics
- Sponsor-specific acceptance criteria

**Examples**:
- Sponsor TTN validates Android tablets only (no BYOD)
- Sponsor CAL validates BYOD on iOS and Android
- Different uptime monitoring thresholds
- Custom portal dashboards

---

## Validation Lifecycle

### Initial Validation

When a new sponsor is onboarded:

1. **Copy template** to `sponsor/{sponsor-name}/validation/`
2. **Customize** for sponsor-specific requirements
3. **Execute** validation protocols
4. **Document** results in validation reports
5. **Archive** validation package with deployment artifacts

### Ongoing Validation

After initial deployment:

1. **Change-Based Revalidation**: When system changes (software updates, configuration changes)
2. **Periodic Revalidation**: Annual verification (per 21 CFR Part 11)
3. **Continuous Monitoring**: Operational qualification via monitoring systems

### Change Control

All changes triggering revalidation must:
- Reference requirement IDs (REQ-xxxxx)
- Document validation impact analysis
- Update affected validation protocols
- Re-execute affected tests
- Update validation reports

**See**: `spec/ops-requirements-management.md` (REQ-o00017)

---

## Validation Artifacts

### Required Documentation

Each validation component produces:

1. **Validation Plan**: Describes what will be validated and how
2. **Test Protocols**: Step-by-step test procedures
3. **Test Results**: Documented execution of test protocols
4. **Validation Report**: Summary of validation activities and conclusion

### Artifact Storage

**During Validation**: Working files in `sponsor/{sponsor-name}/validation/`

**After Validation**:
- Archived to S3 with deployment artifacts
- Sponsor-specific S3 path: `s3://clinical-diary-{sponsor}/validation/{version}/`
- Retention: 7 years (per REQ-p00012)

**See**: `spec/ops-artifact-management.md` (REQ-o00049)

---

## Leveraging Existing Requirements

This validation approach leverages existing requirements defined in `spec/` to avoid duplication:

### Requirement Traceability

All validation protocols reference specific requirements:

**Format**: `REQ-{type}{number}`
- `REQ-p00006`: Product requirement (what the system does)
- `REQ-o00046`: Operations requirement (how it's deployed/operated)
- `REQ-d00004`: Development requirement (how it's implemented)

**Benefit**: Validation demonstrates compliance with formal requirements already documented in the system.

### Validation Coverage Matrix

Each validation report includes a traceability matrix showing:
- Which requirements were validated
- Which test protocols covered each requirement
- Test results for each requirement
- Overall validation status

**See**: `tools/requirements/generate-traceability-matrix.py`

---

## Using This Template

### For New Sponsors

1. **Copy template** to sponsor directory:
   ```bash
   cp -r sponsor/template/validation sponsor/{sponsor-name}/validation
   ```

2. **Customize README**: Update sponsor name, deployment specifics

3. **Select components**:
   - Mobile app (required)
   - Operations (required)
   - Portal (optional - delete if not deployed)
   - Database (optional - delete if portal not deployed)

4. **Review validation plans**: Customize for sponsor requirements

5. **Execute validation**: Follow protocols in each component

6. **Generate reports**: Document results

7. **Archive artifacts**: Upload to sponsor S3 bucket

### For Updating Validation

When system changes:

1. **Identify affected components** (mobile, operations, portal, database)
2. **Review change impact** on validation protocols
3. **Update test protocols** if needed
4. **Re-execute affected tests**
5. **Update validation reports**
6. **Archive updated artifacts**

---

## References

### Requirements Specifications

- `spec/prd-clinical-trials.md` - FDA 21 CFR Part 11 compliance requirements
- `spec/prd-requirements-management.md` - REQ-p00020 (System Validation)
- `spec/ops-monitoring-observability.md` - Operational monitoring requirements
- `spec/ops-artifact-management.md` - Artifact retention requirements

### Architecture Documentation

- `spec/prd-architecture-multi-sponsor.md` - Multi-sponsor system architecture
- `spec/dev-architecture-multi-sponsor.md` - Implementation architecture

### Tools

- `tools/requirements/generate-traceability-matrix.py` - Generate requirement coverage
- `tools/requirements/validate-requirements.py` - Validate requirement format

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-13 | 1.0 | Development Team | Initial validation framework |

---

**Next Steps**:
1. Review component-specific validation plans in subdirectories
2. Customize for sponsor-specific requirements
3. Execute validation protocols
4. Document results in validation reports
