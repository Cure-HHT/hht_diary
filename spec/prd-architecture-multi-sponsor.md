# Multi-Sponsor Clinical Diary Architecture

**Version**: 1.1
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Draft

> **See**: dev-sponsor-repos.md for implementation details
> **See**: prd-database.md for database architecture
> **See**: prd-clinical-trials.md for FDA compliance requirements

---

## Executive Summary

The Clinical Diary platform enables multiple pharmaceutical sponsors to conduct independent clinical trials using shared software infrastructure. This document defines the multi-sponsor architecture requirements.

**Core Architecture Principles**:

| Principle | Description |
| --------- | ----------- |
| **Shared Software** | One mobile app (REQ-p00008) and one codebase (REQ-p01057) serve all sponsors |
| **Isolated Infrastructure** | Each sponsor has dedicated cloud resources (REQ-p01054) and web portal (REQ-p00009) |
| **Protected Identity** | Sponsor participation remains confidential (REQ-p01055, REQ-p01056) |
| **Controlled Changes** | Coordinated releases (REQ-p01058) with restricted in-trial UX changes (REQ-p01060) |
| **Minimal Customization** | Standard platform with policy-controlled exceptions (REQ-p01059) |

**Patient Experience**: Patients download a single app with neutral branding. Enrollment links connect them to the correct sponsor's backend automatically. The patient never sees other sponsors' data or branding.

**Sponsor Experience**: Each sponsor operates independently with their own portal, database, and user accounts. Sponsors can customize branding and request protocol-specific features while sharing platform improvements.

---

## System Components

# REQ-p00008: Single Mobile App for All Sponsors

**Level**: PRD | **Implements**: p00001 | **Status**: Draft

One mobile application in app stores SHALL serve all pharmaceutical sponsors, with each sponsor's configuration and branding loaded dynamically based on patient enrollment.

Single app approach SHALL ensure:
- One app listing in iOS App Store and Google Play Store with Cure HHT branding
- All sponsor configurations bundled in single app package
- Sponsor selection based on enrollment link, not manual choice
- Each sponsor's data and configuration completely isolated
- App updates benefit all sponsors simultaneously
- App connects to multiple sponsor backends based on patient enrollment

**Rationale**: Simplifies patient experience (one app to find and download), ensures consistent quality across sponsors, and enables efficient maintenance. Maintains sponsor isolation (p00001) through dynamic configuration rather than separate app packages. Cure HHT branding provides a neutral identity that does not reveal sponsor participation.

**Acceptance Criteria**:
- Single app package serves unlimited number of sponsors
- Patients download same app regardless of sponsor
- App size reasonable despite multiple sponsor configurations
- Updates deployed once for all sponsors
- No cross-sponsor data or configuration leakage

*End* *Single Mobile App for All Sponsors* | **Hash**: dd4bbaaa
---

# REQ-p00009: Sponsor-Specific Web Portals

**Level**: PRD | **Implements**: p00001 | **Status**: Draft

Each sponsor SHALL have a dedicated web portal at a unique URL, accessible only to that sponsor's authorized personnel and displaying only that sponsor's clinical trial data.

Portal isolation SHALL ensure:
- Unique URL per sponsor (different domain or subdomain)
- Portal displays single sponsor's data only
- Staff cannot access other sponsors' portals
- Independent customization per sponsor

**Rationale**: Web portals serve clinical staff and require strong isolation guarantees. Unlike mobile app (where patients naturally access only their own data), portal users could potentially access multiple trials. Separate portals per sponsor ensures organizational and technical isolation per p00001.

**Acceptance Criteria**:
- Each sponsor portal has unique URL
- Portal authentication scoped to single sponsor
- No navigation or links to other sponsor portals
- Portal customization independent per sponsor
- Portal cannot query other sponsors' databases

*End* *Sponsor-Specific Web Portals* | **Hash**: f1ff8218
---

# REQ-p00018: Multi-Site Support Per Sponsor

**Level**: PRD | **Implements**: p00044 | **Status**: Draft

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

## Infrastructure Isolation

# REQ-p01054: Complete Infrastructure Isolation Per Sponsor

**Level**: PRD | **Implements**: p00001 | **Status**: Active

Each sponsor SHALL have completely isolated cloud infrastructure to ensure data security, regulatory compliance, and prevent data leakage between sponsors.

Infrastructure isolation SHALL ensure:
- Dedicated cloud project per sponsor
- Isolated database instance per sponsor
- Separate serverless functions deployment per sponsor
- Independent web portal instance per sponsor
- No shared compute or storage resources between sponsors

**Rationale**: Complete infrastructure isolation ensures data security, regulatory compliance, and prevents any possibility of data leakage between sponsors. This supports FDA 21 CFR Part 11 requirements for data integrity and access control.

**Acceptance Criteria**:
- Each sponsor has dedicated cloud project
- No shared resources between sponsors
- Serverless functions cannot access other sponsors' resources
- Database connections scoped to single sponsor
- Network isolation prevents cross-sponsor traffic

**See**: ops-deployment.md for infrastructure provisioning details

*End* *Complete Infrastructure Isolation Per Sponsor* | **Hash**: 6ae292f7
---

## Repository and Deployment

# REQ-p01057: Mono Repository with Sponsor Repositories

**Level**: PRD | **Implements**: p00001 | **Status**: Active

The platform SHALL use a mono repository architecture for core code with separate sponsor-specific repositories for customization.

Repository architecture SHALL ensure:
- Core platform code maintained in single mono repository
- Each sponsor has a separate repository containing their configuration files, branding assets, and customizations
- Each sponsor has access to their own repository only
- All changes to sponsor repositories require approval by authorized Sponsor AND Developer personnel

**Rationale**: Enables shared platform improvements while maintaining sponsor isolation and customization capability. Sponsors can review and approve changes to their specific configurations without accessing core platform code or other sponsors' repositories.

**Acceptance Criteria**:
- Core platform code in single mono repository
- Each sponsor has dedicated repository
- Sponsor repos contain configuration, assets, and customizations
- Access control enforces sponsor repository isolation

*End* *Mono Repository with Sponsor Repositories* | **Hash**: 6872ae0f
---

# REQ-p01058: Unified App Deployment

**Level**: PRD | **Implements**: p00008 | **Status**: Active

Every release of the shared Diary App SHALL be approved by all Sponsors currently collecting data through the App.

Release coordination SHALL ensure:
- Sponsors agree to a maximum review time after which they will be considered to approve the release, unless they have communicated otherwise
- Sponsor approval requirements may be waived when the Operator deems it necessary to release a targeted patch to address a Critical system issue
- Emergency releases SHALL be accompanied by a notice to all Sponsors as soon as practical
- Sponsors SHALL conduct UAT after emergency releases and report any issues in a timely manner

**Rationale**: Because all Sponsors rely on the same software, the software must pass UAT for each sponsor individually, regardless of the scope of changes in the app.

**Acceptance Criteria**:
- Each Sponsor has an agreement to conduct UAT at the Operator's request, within defined parameters: allowed frequency of request, review duration, failure criteria
- Each Sponsor has an agreement with the Operator regarding waiver of the normal UAT process
- Release process documents approval status from all active sponsors

*End* *Unified App Deployment* | **Hash**: 0f391a78
---

# REQ-p01060: UX Changes During Trials

**Level**: PRD | **Implements**: p00010 | **Status**: Active

Changes to the patient user experience, either in terms of application logic or graphical presentation, SHALL NOT be made during the active trial period for any users enrolled in that trial without explicit justification by the Operator and Sponsor approval.

**Rationale**: Changes to the UX may affect the data collected, potentially compromising data integrity and regulatory compliance. Trial protocol consistency is essential for FDA 21 CFR Part 11 compliance.

**Acceptance Criteria**:
- UX change requests during active trials require documented justification
- Sponsor approval required for any patient UX modifications during trial period
- Change impact assessment documented before implementation
- Audit trail captures all approved UX changes during trials

*End* *UX Changes During Trials* | **Hash**: 350e44c0
---

## Customization

# REQ-p01059: Customization Policy

**Level**: PRD | **Implements**: p00001 | **Status**: Active

Sponsors MAY request modifications ("Customizations") to the standard UX in order to support their trial protocol.

Customization governance SHALL ensure:
- Customizations are kept minimal and only added when sponsors explicitly request and need specific features
- Customizations are separate for each Sponsor
- Operator MAY designate some Customization requests as Core feature requests; Core features MAY be configuration options and SHALL NOT be considered Customizations or proprietary to the Sponsor
- Sponsor Customizations and Configurations SHALL be confidential information
- All Sponsor-specific behavior is controlled at runtime by the Sponsor's Configuration

**Rationale**: Minimizing customization reduces maintenance burden and code divergence as sponsor count grows. The System is intended to embody best-practices for collection of HHT Diary data, therefore gratuitous changes are counter to this objective.

**Acceptance Criteria**:
- Operator has a defined Customization request, review and approval process during pre-trial and in-trial periods
- Sponsor Configurations are stored separately from each other
- Changes to Sponsor Configurations require Customer and Operator approval
- Customizations are only added when Sponsors request and justify need
- Custom features documented in sponsor repository

*End* *Customization Policy* | **Hash**: cadd2d4e
---

## Sponsor Confidentiality

# REQ-p01055: Sponsor Confidentiality

**Level**: PRD | **Implements**: p00001 | **Status**: Active

Operator shall not divulge the participation of any Sponsor publicly or privately without written agreement.

System confidentiality SHALL ensure:
- The System does not expose Sponsor identities in the shared Diary App's base installation
- Sponsor-identifying content is downloaded to an instance of the Diary App ONLY after the user has been linked to that Sponsor's portal through the agreed-upon linking process
- Any confidentiality requirements may be waived, amended or modified ONLY by written agreement with the Sponsor

Sponsor-identifying content includes:
- Sponsor name (text or graphical format)
- Sponsor Logo or other branding
- URLs associated with the Sponsor
- Other content located in the Sponsor's Configuration

**Rationale**: Clinical trial activity is proprietary business information. Using a shared application is a risk to the Sponsor's confidentiality. The application must take reasonable measures to protect the Sponsor's confidentiality.

**Acceptance Criteria**:
- Base app installation reveals no sponsor identities
- Sponsor content loaded only after successful linking
- No sponsor identifiers in app metadata or store listings
- Configuration download requires valid enrollment credentials

*End* *Sponsor Confidentiality* | **Hash**: e3274f2f
---

# REQ-p01056: Confidentiality Sufficiency

**Level**: PRD | **Implements**: p01055 | **Status**: Active

Operator and Sponsor contract SHALL state that REQ-p01055 (Sponsor Confidentiality) constitutes sufficient protection against unwanted exposure of the Sponsor's trial or use of the System.

**Rationale**: The Operator can only restrict sharing information with the User. There is no protection the Operator can provide that will limit what information the User will share or with whom they share it. Contractual acknowledgment sets appropriate expectations.

**Acceptance Criteria**:
- Sponsor contract includes confidentiality sufficiency clause
- Contract references REQ-p01055 protections explicitly
- Sponsor acknowledges limitations of technical protections

*End* *Confidentiality Sufficiency* | **Hash**: 0b60200a
---

## References

- **Implementation Details**: dev-sponsor-repos.md
- **Database Architecture**: prd-database.md
- **Security Architecture**: prd-security.md
- **FDA Compliance**: prd-clinical-trials.md
