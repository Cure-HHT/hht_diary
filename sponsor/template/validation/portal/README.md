# Portal Validation (Optional)

**Component**: Sponsor-Specific Web Portal
**Version**: 1.0
**Audience**: QA/Validation Team
**Status**: Template (Optional Component)

---

## Overview

This directory contains validation documentation for the sponsor-specific web portal.

**Note**: This is an **optional component**. Not all sponsors deploy a web portal. If your sponsor does not use a portal, delete this directory.

### Scope

Portal validation focuses on:
- Portal deployment and accessibility
- Role-based access control (RBAC)
- Data isolation verification
- User management functionality
- Custom dashboards and reports
- Integration with sponsor database

### Key Characteristics

**Sponsor-Specific**:
- Each sponsor has unique portal URL
- Portal customized for sponsor branding
- Portal displays sponsor data only
- Independent deployment from core platform

**Optional**:
- Portal-less deployments use mobile app exclusively
- Portal adds investigator/analyst web interface
- Not required for basic diary functionality

---

## Validation Approach

### Risk-Based Validation

Portal validation uses a risk-based approach focusing on:

**High Risk**:
- Data isolation (sponsor separation)
- Access control (role-based permissions)
- Authentication (secure login)

**Medium Risk**:
- User interface functionality
- Dashboard accuracy
- Report generation

**Low Risk**:
- Branding and styling
- Non-critical UI elements

### Validation Levels

**Installation Qualification (IQ)**:
- Verify portal deployed to hosting platform
- Verify portal URL accessible
- Verify SSL certificate valid
- Verify environment configuration correct

**Operational Qualification (OQ)**:
- Verify portal functions per requirements
- Verify role-based access control works
- Verify data isolation maintained
- Verify user management functions

**Performance Qualification (PQ)**:
- Verify portal performs acceptably under load
- Verify response times meet targets
- Verify concurrent user support

---

## Directory Structure

```
portal/
├── README.md                          # This file
├── validation-plan.md                 # Overall validation strategy
├── test-protocols/
│   ├── IQ-001-deployment.md           # Portal deployment verification
│   ├── OQ-001-authentication.md       # Login and authentication
│   ├── OQ-002-rbac.md                 # Role-based access control
│   ├── OQ-003-data-isolation.md       # Sponsor data isolation
│   ├── OQ-004-user-management.md      # User management functions
│   ├── OQ-005-dashboards.md           # Dashboard functionality
│   ├── OQ-006-reports.md              # Report generation
│   └── PQ-001-performance.md          # Performance under load
├── test-results/
│   └── {version}/                     # Results for each validation cycle
│       ├── IQ-001-results.md
│       ├── OQ-001-results.md
│       └── ...
└── validation-report.md               # Summary report
```

---

## Requirements Coverage

This validation covers the following requirements:

### Product Requirements (PRD)

| Requirement | Title | Validation Protocol |
|-------------|-------|---------------------|
| REQ-p00009 | Sponsor-Specific Web Portals | IQ-001, OQ-003 |
| REQ-p00024 | Portal User Roles and Permissions | OQ-002 |
| REQ-p00025 | Patient Enrollment Workflow | OQ-005 |
| REQ-p00026 | Patient Monitoring Dashboard | OQ-005 |
| REQ-p00027 | Questionnaire Management | OQ-005 |
| REQ-p00029 | Auditor Dashboard and Data Export | OQ-006 |
| REQ-p00030 | Role-Based Visual Indicators | OQ-002 |

### Development Requirements (DEV)

| Requirement | Title | Validation Protocol |
|-------------|-------|---------------------|
| REQ-d00028 | Portal Frontend Framework | IQ-001 |
| REQ-d00031 | Supabase Authentication Integration | OQ-001 |
| REQ-d00032 | Role-Based Access Control Implementation | OQ-002 |
| REQ-d00033 | Site-Based Data Isolation | OQ-003 |
| REQ-d00034 | Login Page Implementation | OQ-001 |
| REQ-d00035 | Admin Dashboard Implementation | OQ-005 |
| REQ-d00051 | Auditor Dashboard Implementation | OQ-006 |

### Operations Requirements (OPS)

| Requirement | Title | Validation Protocol |
|-------------|-------|---------------------|
| REQ-o00009 | Portal Deployment Per Sponsor | IQ-001 |
| REQ-o00055 | Role-Based Visual Indicator Verification | OQ-002 |

---

## Test Protocol Overview

### IQ-001: Portal Deployment

**Purpose**: Verify portal deployed correctly

**Key Tests**:
- Portal accessible at sponsor-specific URL
- SSL certificate valid and trusted
- Portal version matches deployment artifacts
- Environment configuration correct (production vs staging)
- Supabase connection configured correctly
- Portal metadata (title, favicon) sponsor-specific

**Acceptance**: Portal deployed and accessible securely

---

### OQ-001: Authentication

**Purpose**: Verify authentication works per REQ-d00031, REQ-d00034

**Key Tests**:
- Login page renders correctly
- Valid credentials allow login
- Invalid credentials rejected
- MFA enforced for staff accounts (if configured)
- Session timeout enforced
- Logout clears session
- Password reset works

**Acceptance**: Authentication secure and functional

---

### OQ-002: Role-Based Access Control

**Purpose**: Verify RBAC per REQ-p00024, REQ-p00030, REQ-d00032

**Key Tests**:
- Administrator sees admin dashboard
- Investigator sees assigned sites only
- Analyst has read-only access
- Auditor sees compliance dashboard
- Role-based visual indicators displayed (banners, badges)
- Unauthorized pages return 403 error
- Navigation limited per role

**Acceptance**: All roles restricted correctly, visual indicators present

---

### OQ-003: Data Isolation

**Purpose**: Verify sponsor data isolation per REQ-p00009, REQ-d00033

**Key Tests**:
- Portal queries sponsor database only
- No cross-sponsor data leakage
- Site-based isolation enforced (investigators see assigned sites only)
- Database RLS policies enforced at database level
- Portal cannot access other sponsors' databases
- Test with multi-sponsor test data

**Acceptance**: Complete data isolation verified, no cross-sponsor access

---

### OQ-004: User Management

**Purpose**: Verify user management functions

**Key Tests**:
- Admin can create new users
- User roles assigned correctly
- User site assignments work
- User permissions propagate immediately
- User deactivation works
- User audit trail captured

**Acceptance**: User management functions correctly

---

### OQ-005: Dashboards

**Purpose**: Verify dashboard functionality per REQ-p00026, REQ-d00035

**Key Tests**:
- Admin dashboard displays correct data
- Investigator dashboard shows assigned sites
- Patient monitoring dashboard accurate
- Dashboard updates in real-time (or near-real-time)
- Filtering works correctly
- Data export functions work

**Acceptance**: Dashboards display correct data for all roles

---

### OQ-006: Reports

**Purpose**: Verify report generation per REQ-p00029, REQ-d00051

**Key Tests**:
- Auditor can generate compliance reports
- Reports include complete audit trail data
- Reports formatted correctly (PDF, CSV)
- Reports include required metadata
- Reports can be filtered by date range, site
- Report generation logged in audit trail

**Acceptance**: Reports accurate and complete

---

### PQ-001: Performance

**Purpose**: Verify acceptable performance under load

**Key Tests**:
- Portal page load time <2 seconds
- Dashboard rendering <3 seconds
- Report generation completes within reasonable time (<30 seconds)
- Portal supports concurrent users (10+ simultaneous)
- Database queries optimized (no N+1 queries)
- Resource usage acceptable (memory, CPU)

**Acceptance**: All performance targets met

---

## Validation Execution

### Pre-Validation Setup

Before executing validation:

1. **Verify portal deployed**:
   - Portal URL accessible
   - SSL certificate configured
   - Environment variables set correctly

2. **Prepare test environment**:
   - Test database with sample data
   - Test user accounts (all roles)
   - Multiple sites configured
   - Sample patients enrolled

3. **Document environment**:
   - Portal URL
   - Portal version
   - Database connection details
   - Test user credentials

4. **Coordinate access**:
   - QA team has test accounts
   - Validation team has admin access
   - Stakeholders available for UAT

### Execution Process

For each test protocol:

1. **Review protocol**: Ensure test steps current
2. **Execute tests**: Follow protocol step-by-step
3. **Document results**: Record actual results
4. **Capture evidence**: Screenshots, logs, database queries
5. **Note deviations**: Document unexpected behavior
6. **Pass/fail decision**: Compare to acceptance criteria

### Post-Validation

After all protocols executed:

1. **Review results**: Ensure all tests passed
2. **Address failures**: Investigate and resolve
3. **Re-test if needed**: Re-execute failed tests
4. **Generate validation report**: Summarize results
5. **Archive artifacts**: Store with deployment artifacts

---

## Validation Report

The validation report (`validation-report.md`) includes:

**Executive Summary**:
- Portal version validated
- Validation date range
- Overall validation conclusion

**Validation Scope**:
- Components validated
- Requirements covered
- Test protocols executed

**Test Results Summary**:
- Protocol results (pass/fail)
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

1. **Custom Features**:
   - Add validation for sponsor-specific dashboards
   - Add validation for custom reports
   - Validate sponsor-specific integrations

2. **User Roles**:
   - Customize role list for sponsor
   - Adjust permissions per sponsor requirements
   - Validate sponsor-specific workflows

3. **Performance Targets**:
   - Adjust based on expected user count
   - Define sponsor-specific SLAs
   - Customize concurrent user targets

4. **Compliance**:
   - Add sponsor-specific compliance checks
   - Validate sponsor-required audit trails
   - Include sponsor-specific documentation requirements

### Example: Multi-Site Sponsor

For sponsor with 20+ clinical trial sites:

**Update**:
- Site isolation validation (expanded test matrix)
- Performance targets (50+ concurrent users)
- Dashboard scalability (100+ patients)

**Add**:
- OQ-007-multi-site-isolation.md
- PQ-002-scalability.md

---

## Revalidation Triggers

Revalidation required when:

1. **Portal version updates**:
   - Full validation for major versions
   - Regression testing for minor versions
   - Smoke testing for patches

2. **Configuration changes**:
   - Custom feature additions
   - Role/permission changes
   - Integration changes

3. **Infrastructure changes**:
   - Hosting platform changes
   - Database schema changes
   - Authentication provider changes

4. **Annual validation**:
   - Per 21 CFR Part 11 requirements
   - Execute critical protocols
   - Verify ongoing compliance

---

## Portal-Less Deployments

If your sponsor does **not** deploy a portal:

1. **Delete this directory**: Remove `portal/` entirely
2. **Update main README**: Note portal not deployed
3. **Focus validation on**: Mobile app and operations only

Portal-less deployments are valid - the mobile app provides all core functionality. Portals add investigator/analyst web access but are optional.

---

## References

### Requirements

- `spec/prd-portal.md` - Portal product requirements
- `spec/dev-portal.md` - Portal implementation requirements
- `spec/ops-portal.md` - Portal deployment requirements

### Architecture

- `spec/prd-architecture-multi-sponsor.md` - Multi-sponsor architecture
- `spec/dev-architecture-multi-sponsor.md` - Implementation details

### Related Validation

- `../mobile-app/README.md` - Mobile app validation
- `../database/README.md` - Database validation
- `../operations/README.md` - Operations validation

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-13 | 1.0 | Development Team | Initial portal validation framework |
