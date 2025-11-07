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

# REQ-p00008: Single Mobile App for All Sponsors

**Level**: PRD | **Implements**: p00001 | **Status**: Active

One mobile application in app stores SHALL serve all pharmaceutical sponsors, with each sponsor's configuration and branding loaded dynamically based on patient enrollment.

Single app approach SHALL ensure:
- One app listing in iOS App Store and Google Play Store
- All sponsor configurations bundled in single app package
- Sponsor selection based on enrollment link, not manual choice
- Each sponsor's data and configuration completely isolated
- App updates benefit all sponsors simultaneously

**Rationale**: Simplifies patient experience (one app to find and download), ensures consistent quality across sponsors, and enables efficient maintenance. Maintains sponsor isolation (p00001) through dynamic configuration rather than separate app packages.

**Acceptance Criteria**:
- Single app package serves unlimited number of sponsors
- Patients download same app regardless of sponsor
- App size reasonable despite multiple sponsor configurations
- Updates deployed once for all sponsors
- No cross-sponsor data or configuration leakage

*End* *Single Mobile App for All Sponsors* | **Hash**: f638b9f4
---

# REQ-p00009: Sponsor-Specific Web Portals

**Level**: PRD | **Implements**: p00001 | **Status**: Active

Each sponsor SHALL have a dedicated web portal at a unique URL, accessible only to that sponsor's authorized personnel and displaying only that sponsor's clinical trial data.

Portal isolation SHALL ensure:
- Unique URL per sponsor (different domain or subdomain)
- Portal displays single sponsor's data only
- Staff cannot access other sponsors' portals
- Independent customization per sponsor
- Separate hosting and deployment per sponsor

**Rationale**: Web portals serve clinical staff and require strong isolation guarantees. Unlike mobile app (where patients naturally access only their own data), portal users could potentially access multiple trials. Separate portals per sponsor ensures organizational and technical isolation per p00001.

**Acceptance Criteria**:
- Each sponsor portal has unique URL
- Portal authentication scoped to single sponsor
- No navigation or links to other sponsor portals
- Portal customization independent per sponsor
- Portal cannot query other sponsors' databases

*End* *Sponsor-Specific Web Portals* | **Hash**: 4ebd0c72
---

## How Patients Enroll

1. Investigator provides patient with enrollment link or QR code
2. Patient opens link, which takes them to app store (first time) or opens app (already installed)
3. App reads enrollment information and connects to correct sponsor
4. App displays sponsor's branding and logo
5. Patient completes enrollment and begins using diary

The patient never needs to know which technical system they're using - it just works.

---

# REQ-p00018: Multi-Site Support Per Sponsor

**Level**: PRD | **Implements**: - | **Status**: Active

Each sponsor SHALL support multiple clinical trial sites within their isolated environment, with site-level access control ensuring investigators and analysts access only data from their assigned sites.

Multi-site support SHALL include:
- Each sponsor's database contains multiple site records
- Sites identified by unique site identifiers within sponsor
- Users (investigators, analysts) assigned to specific sites
- Access control enforces site-level data visibility
- Audit trail captures site context for all data changes
- Reports and exports can be filtered by site

**Rationale**: Clinical trials typically involve multiple sites (hospitals, clinics, research centers) coordinating under one sponsor. Each site needs independent operation while contributing to the sponsor's unified trial. Site-level access control prevents investigators at one site from accessing another site's data, maintaining data integrity and regulatory compliance.

**Acceptance Criteria**:
- Sponsor can create and manage multiple sites
- Each site has unique identifier and metadata
- Investigators assigned to specific sites see only that site's data
- Site assignments tracked in audit trail
- Reports aggregate across sites or filter to specific sites
- Site information included in data exports for regulatory submission

*End* *Multi-Site Support Per Sponsor* | **Hash**: b3de8bbb
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
