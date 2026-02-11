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

**Level**: PRD | **Status**: Draft | **Implements**: p00001

## Rationale

This requirement establishes a unified mobile application architecture that simplifies the patient experience while maintaining strict sponsor isolation. By publishing a single app under sponsor branding, patients can easily find and download one application regardless of which pharmaceutical sponsor's trial they are enrolled in. This approach eliminates confusion from multiple app listings, ensures consistent quality and security updates across all sponsors simultaneously, and reduces maintenance overhead. Dynamic configuration loading based on enrollment links allows the app to serve multiple sponsors without exposing sponsor participation or allowing cross-sponsor data access. This design aligns with multi-sponsor isolation requirements (REQ-p00001) while optimizing operational efficiency and user experience.

## Assertions

A. The platform SHALL publish exactly one mobile application listing in the iOS App Store.
B. The platform SHALL publish exactly one mobile application listing in the Google Play Store.
C. The mobile application listings SHALL use sponsor branding.
D. The mobile application package SHALL contain configurations for all pharmaceutical sponsors.
E. The system SHALL determine sponsor context based on the patient's enrollment link.
F. The system SHALL NOT present manual sponsor selection to patients.
G. The system SHALL isolate each sponsor's data such that no cross-sponsor access is possible.
H. The system SHALL isolate each sponsor's configuration such that no cross-sponsor access is possible.
I. The system SHALL route patient data to the correct sponsor backend based on enrollment context.
J. The platform SHALL deploy application updates to all sponsors simultaneously.
K. The mobile application package size SHALL remain within reasonable limits for app store distribution when containing multiple sponsor configurations.
L. The system SHALL NOT allow configuration or data from one sponsor to be accessible to patients enrolled with a different sponsor.

*End* *Single Mobile App for All Sponsors* | **Hash**: 3fe1fad0
---

# REQ-p00009: Sponsor-Specific Portals

**Level**: PRD | **Status**: Draft | **Implements**: p00001

## Rationale

Web portals serve clinical staff and require strong isolation guarantees beyond those needed for patient-facing mobile apps. While patients naturally access only their own data through mobile interfaces, portal users could potentially access multiple trials across different sponsors. Dedicated web portals at unique URLs provide organizational and technical isolation to ensure sponsors never access each other's data, supporting the multi-sponsor deployment model defined in REQ-p00001. This isolation extends to authentication, data queries, navigation, and customization capabilities.

## Assertions

A. The platform SHALL provide a dedicated web portal for each sponsor at a unique URL.
B. Each sponsor's portal URL SHALL use a different domain or subdomain from all other sponsor portals.
C. The portal SHALL display only the data belonging to its associated sponsor.
D. The portal authentication system SHALL scope access to a single sponsor only.
E. The portal SHALL NOT provide navigation links or interface elements that could access other sponsors' portals.
F. Staff authenticated to one sponsor's portal SHALL NOT be able to access any other sponsor's portal.
G. Each sponsor portal SHALL support independent customization without affecting other sponsors' portals.
H. The portal SHALL NOT be capable of querying database records belonging to other sponsors.

*End* *Sponsor-Specific Portals* | **Hash**: e26dfd95
---

# REQ-p00018: Multi-Site Support Per Sponsor

**Level**: PRD | **Status**: Draft | **Implements**: p70001

## Rationale

Clinical trials typically involve multiple sites (hospitals, clinics, research centers) coordinating under one sponsor. Each site needs independent operation while contributing to the sponsor's unified trial. Site-level access control prevents investigators at one site from accessing another site's data, maintaining data integrity and regulatory compliance. This requirement ensures proper isolation between sites while enabling sponsor-level oversight and reporting across the entire trial.

## Assertions

A. The system SHALL support multiple clinical trial sites within each sponsor's isolated environment.
B. The system SHALL store multiple site records in each sponsor's database.
C. The system SHALL identify each site using a unique site identifier within the sponsor's environment.
D. The system SHALL assign users (investigators and analysts) to specific sites.
E. The system SHALL enforce access control such that users can only access data from their assigned sites.
F. The system SHALL capture site context in the audit trail for all data changes.
G. The system SHALL enable reports to be filtered by site.
H. The system SHALL enable reports to aggregate data across multiple sites.
I. The system SHALL enable sponsors to create new sites.
J. The system SHALL enable sponsors to manage existing sites.
K. The system SHALL store unique identifier metadata for each site.
L. The system SHALL restrict investigators to viewing only data from their assigned site.
M. The system SHALL track site assignments in the audit trail.
N. The system SHALL include site information in data exports for regulatory submission.

*End* *Multi-Site Support Per Sponsor* | **Hash**: c4d7df6f
---

## Infrastructure Isolation

# REQ-p01054: Complete Infrastructure Isolation Per Sponsor

**Level**: PRD | **Status**: Active | **Implements**: p00001

## Rationale

Complete infrastructure isolation ensures data security, regulatory compliance, and prevents any possibility of data leakage between sponsors. This supports FDA 21 CFR Part 11 requirements for data integrity and access control by ensuring that each sponsor's electronic records and signatures remain completely segregated at the infrastructure level, eliminating any technical possibility of unauthorized cross-sponsor data access.

## Assertions

A. The platform SHALL provide completely isolated cloud infrastructure for each sponsor.
B. Each sponsor SHALL have a dedicated cloud project.
C. Each sponsor SHALL have an isolated database instance.
D. Each sponsor SHALL have a separate serverless functions deployment.
E. Each sponsor SHALL have an independent web portal instance.
F. The platform SHALL NOT share compute resources between sponsors.
G. The platform SHALL NOT share storage resources between sponsors.
H. Serverless functions SHALL NOT access resources belonging to other sponsors.
I. Database connections SHALL be scoped to a single sponsor.
J. The platform SHALL implement network isolation to prevent cross-sponsor traffic.

*End* *Complete Infrastructure Isolation Per Sponsor* | **Hash**: 5f9f93ed
---

## Repository and Deployment

# REQ-p01057: Mono Repository with Sponsor Repositories

**Level**: PRD | **Status**: Active | **Implements**: p00009

## Rationale

This requirement establishes a mono repository architecture that balances centralized platform development with sponsor-specific customization needs. The mono repository pattern enables efficient sharing of core platform improvements, dependency management, and coordinated releases while maintaining strict isolation between sponsors. Each sponsor receives a dedicated repository for their configurations, branding assets, and customizations, allowing them to review and approve changes specific to their implementation without exposing them to core platform code or other sponsors' proprietary customizations. This architecture supports the multi-sponsor deployment model required for clinical trial platforms where multiple organizations may be running trials simultaneously while maintaining data and configuration isolation for regulatory compliance and competitive separation.

## Assertions

A. The platform SHALL use a mono repository architecture for core platform code.
B. The platform SHALL provide separate sponsor-specific repositories for customization.
C. The platform SHALL maintain core platform code in a single mono repository.
D. The system SHALL create a dedicated repository for each sponsor.
E. Sponsor repositories SHALL contain configuration files specific to that sponsor.
F. Sponsor repositories SHALL contain branding assets specific to that sponsor.
G. Sponsor repositories SHALL contain customizations specific to that sponsor.
H. The system SHALL restrict each sponsor's access to their own repository only.
I. The system SHALL NOT grant sponsors access to the core platform repository.
J. The system SHALL NOT grant sponsors access to other sponsors' repositories.
K. The system SHALL require approval from authorized Sponsor personnel for all changes to sponsor repositories.
L. The system SHALL require approval from authorized Developer personnel for all changes to sponsor repositories.
M. Access control mechanisms SHALL enforce sponsor repository isolation.

*End* *Mono Repository with Sponsor Repositories* | **Hash**: a54d5ad6
---

# REQ-p01058: Unified App Deployment

**Level**: PRD | **Status**: Active | **Implements**: p00008

## Rationale

The unified deployment model requires that all sponsors share the same production software version, creating a dependency where changes affecting any sponsor could impact all sponsors. This necessitates collective approval before releases to ensure the shared platform meets each sponsor's clinical trial requirements. The multi-sponsor UAT process balances operational efficiency with risk management, allowing emergency overrides when system stability is at risk while maintaining transparency through post-release validation and notification requirements.

## Assertions

A. The system SHALL require approval from all Sponsors currently collecting data before releasing any version of the shared Diary App.
B. The Operator SHALL establish with each Sponsor a maximum review time after which approval will be presumed unless the Sponsor has communicated otherwise.
C. The Operator SHALL have authority to waive Sponsor approval requirements when releasing a targeted patch to address a Critical system issue.
D. The Operator SHALL send a notice to all Sponsors after an emergency release, as soon as practical.
E. Sponsors SHALL conduct User Acceptance Testing (UAT) after emergency releases.
F. Sponsors SHALL report any issues discovered during post-emergency UAT in a timely manner.
G. Each Sponsor SHALL maintain an agreement with the Operator defining UAT parameters including: allowed frequency of UAT requests, review duration, and failure criteria.
H. Each Sponsor SHALL maintain an agreement with the Operator regarding waiver conditions for the normal UAT process.
I. The release process SHALL document approval status from all active Sponsors for each release.

*End* *Unified App Deployment* | **Hash**: c22435c6
---

# REQ-p01060: UX Changes During Trials

**Level**: PRD | **Status**: Active | **Implements**: p80010

## Rationale

Changes to the patient user experience during active trials can affect the data collected, potentially compromising data integrity and regulatory compliance. Trial protocol consistency is essential for FDA 21 CFR Part 11 compliance. Maintaining consistent UX throughout a trial period ensures that all enrolled participants experience the same application behavior, preventing confounding variables that could invalidate trial results or violate regulatory requirements.

## Assertions

A. The system SHALL NOT permit changes to patient application logic during the active trial period for users enrolled in that trial without documented justification and approval.
B. The system SHALL NOT permit changes to patient graphical presentation during the active trial period for users enrolled in that trial without documented justification and approval.
C. UX change requests during active trials SHALL require documented justification by the Operator.
D. UX change requests during active trials SHALL require Sponsor approval before implementation.
E. The system SHALL require a documented change impact assessment before implementing any patient UX modifications during the trial period.
F. The system SHALL capture all approved UX changes during active trials in the audit trail.

*End* *UX Changes During Trials* | **Hash**: fadb4f60
---

## Customization

# REQ-p01059: Customization Policy

**Level**: PRD | **Status**: Active | **Implements**: p00001

## Rationale

Minimizing customization reduces maintenance burden and code divergence as sponsor count grows. The system embodies best-practices for Diary data collection, therefore gratuitous changes are counter to this objective. A clear policy defines when customizations are allowed, how they are governed, and ensures sponsor-specific modifications remain confidential and isolated.

## Assertions

A. The system SHALL allow sponsors to request modifications ("Customizations") to the standard UX to support their trial protocol.
B. The system SHALL keep customizations minimal and add them only when sponsors explicitly request and justify need for specific features.
C. The system SHALL maintain customizations separately for each sponsor.
D. The operator SHALL have the option to designate customization requests as Core feature requests.
E. The system SHALL NOT consider Core features as customizations or proprietary to any sponsor.
F. The system SHALL treat sponsor customizations and configurations as confidential information.
G. The system SHALL control all sponsor-specific behavior at runtime through the sponsor's configuration.
H. The operator SHALL maintain a defined customization request, review, and approval process for pre-trial and in-trial periods.
I. The system SHALL store sponsor configurations separately from each other.
J. The system SHALL require both customer and operator approval for changes to sponsor configurations.
K. The system SHALL document custom features in the sponsor repository.

*End* *Customization Policy* | **Hash**: bf7c7b8e
---

## Sponsor Confidentiality

# REQ-p01055: Sponsor Confidentiality

**Level**: PRD | **Status**: Active | **Implements**: p00001

## Rationale

Clinical trial activity is proprietary business information. Using a shared multi-sponsor application platform creates inherent confidentiality risks for sponsors, as competitors or the public could potentially identify their clinical trial activities, therapeutic areas, or strategic initiatives. This requirement protects sponsor confidentiality by ensuring the base diary application contains no sponsor-identifying information until a participant has been explicitly linked to a specific sponsor through authenticated enrollment credentials. This isolation prevents inadvertent disclosure of sponsor participation and allows sponsors to maintain competitive confidentiality around their clinical programs while still benefiting from a shared platform infrastructure.

## Assertions

A. The operator SHALL NOT divulge the participation of any sponsor publicly or privately without written agreement from that sponsor.
B. The system SHALL NOT expose sponsor identities in the base installation of the shared Diary App.
C. The system SHALL download sponsor-identifying content to a Diary App instance ONLY after the user has been linked to that sponsor's portal through the agreed-upon linking process.
D. Sponsor-identifying content SHALL include sponsor name in text or graphical format.
E. Sponsor-identifying content SHALL include sponsor logos and other branding materials.
F. Sponsor-identifying content SHALL include URLs associated with the sponsor.
G. Sponsor-identifying content SHALL include any other content located in the sponsor's configuration.
H. Confidentiality requirements SHALL be waived, amended, or modified ONLY by written agreement with the affected sponsor.
I. The base app installation SHALL reveal no sponsor identities.
J. The system SHALL load sponsor content ONLY after successful linking.
K. The system SHALL NOT include sponsor identifiers in app metadata or store listings.
L. The system SHALL require valid enrollment credentials for configuration download.

*End* *Sponsor Confidentiality* | **Hash**: 364675e2
---

# REQ-p01056: Confidentiality Sufficiency

**Level**: PRD | **Status**: Active | **Implements**: p01055

## Rationale

This requirement establishes contractual acknowledgment of the inherent limitations in protecting sponsor confidentiality in a clinical trial system. While the system implements technical protections (REQ-p01055) to restrict information sharing between the Operator and Users, it cannot control what information Users choose to share externally after receiving it. The contract creates a legal framework that sets realistic expectations about the scope of confidentiality protections the Operator can provide, clarifying that technical measures address operator-side risks but cannot prevent User-initiated disclosure. This contractual clarity is essential for informed consent and risk allocation between parties.

## Assertions

A. The Operator and Sponsor contract SHALL state that REQ-p01055 constitutes sufficient protection against unwanted exposure of the Sponsor's trial.
B. The Operator and Sponsor contract SHALL state that REQ-p01055 constitutes sufficient protection against unwanted exposure of the Sponsor's use of the System.
C. The contract SHALL include a confidentiality sufficiency clause.
D. The contract SHALL reference REQ-p01055 protections explicitly.
E. The contract SHALL include Sponsor acknowledgment of the limitations of technical protections.

*End* *Confidentiality Sufficiency* | **Hash**: f29524ee
---

## References

- **Implementation Details**: dev-sponsor-repos.md
- **Database Architecture**: prd-database.md
- **Security Architecture**: prd-security.md
- **FDA Compliance**: prd-clinical-trials.md
