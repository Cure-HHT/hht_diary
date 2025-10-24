# Multi-Sponsor Clinical Diary Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: dev-architecture-multi-sponsor.md for implementation details
> **See**: prd-database.md for database architecture
> **See**: prd-clinical-trials.md for FDA compliance requirements

---

## Executive Summary

The Clinical Diary system serves multiple pharmaceutical sponsors using a single mobile app and separate web portals. Each sponsor operates independently with their own database and users, while sharing the underlying software platform.

**How It Works**:
- One mobile app in the app stores serves all sponsors
- Each sponsor gets their own web portal at a unique address
- Patient enrollment links automatically connect to the correct sponsor
- All sponsor data stays completely separate
- Core software is shared and maintained centrally

**Why This Approach**:
- Patients download one app, not different apps per sponsor
- Sponsors get customized branding and features
- Updates and improvements benefit all sponsors simultaneously
- Each sponsor's data remains private and isolated
- Lower costs through shared development

---

## System Components

Each sponsor deployment includes:

**Mobile App**: Single app containing all sponsor configurations. When patients enroll, the app automatically connects to their sponsor's system and displays that sponsor's branding.

**Web Portal**: Each sponsor gets their own portal website where investigators and staff can view patient data, run reports, and manage the study. Each portal is separately hosted and customized.

**Database**: Each sponsor has their own private database that stores patient data, study configuration, and audit records. No data is shared between sponsors.

**Authentication**: Each sponsor controls their own user accounts and can integrate with their company's existing login systems.

---

## How Patients Enroll

1. Investigator provides patient with enrollment link or QR code
2. Patient opens link, which takes them to app store (first time) or opens app (already installed)
3. App reads enrollment information and connects to correct sponsor
4. App displays sponsor's branding and logo
5. Patient completes enrollment and begins using diary

The patient never needs to know which technical system they're using - it just works.

---

## Data Isolation

Each sponsor's data is completely isolated:
- Separate databases mean no possibility of cross-sponsor data access
- Different web addresses for each portal
- Independent user accounts
- Separate audit trails

This architecture ensures regulatory compliance and protects confidential sponsor information.

---

## Customization Options

Sponsors can customize:
- Company logo and color scheme
- Custom questionnaires and data fields
- Specialized reports and data exports
- Integration with their existing systems
- Portal dashboard layout

---

## Software Updates

The core platform receives regular updates for:
- Security improvements
- New features
- Bug fixes
- Performance enhancements

Updates are tested and validated before deployment. Sponsors can control when updates are applied to their production systems to align with their study schedules and validation requirements.

---

## Compliance and Validation

The system is designed to meet FDA 21 CFR Part 11 requirements:
- Complete audit trail of all data changes
- Tamper-evident record keeping
- Secure authentication
- Electronic signatures
- Data integrity verification

**See**: prd-clinical-trials.md for detailed compliance requirements

---

## References

- **Implementation Details**: dev-architecture-multi-sponsor.md
- **Database Architecture**: prd-database.md
- **Security Architecture**: prd-security.md
- **FDA Compliance**: prd-clinical-trials.md
