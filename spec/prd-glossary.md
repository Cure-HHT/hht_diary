# Diary Platform - Glossary

**Version**: 2.0
**Audience**: Product Requirements
**Last Updated**: 2026-02-09
**Status**: Draft

> **Purpose**: Establishes canonical terminology for the Diary Platform across all documentation, requirements, and communication.

---

# REQ-p01020: Privacy Policy and Regulatory Compliance Documentation

**Level**: PRD | **Status**: Draft | **Implements**: p80050

## Rationale

Privacy regulations such as GDPR and HIPAA mandate transparent disclosure of data collection practices and user rights, while clinical trial regulations including FDA 21 CFR Part 11, ICH-GCP E6(R2), and EU Clinical Trial Regulation 536/2014 impose additional protections for research participant data. Comprehensive privacy documentation serves multiple purposes: ensuring legal compliance across jurisdictions, building user trust through transparency, protecting patient rights with clear explanations of legal protections, and supporting regulatory submissions for clinical trials. The multi-layered documentation approach (general policies, diary-specific addenda, clinical trial templates, sponsor-specific supplements) accommodates different user types and regulatory contexts while maintaining a consistent baseline of privacy protection. Version control and annual reviews ensure documentation remains current with evolving regulations and platform capabilities.

## Assertions

A. The platform SHALL provide comprehensive privacy policy documentation that complies with GDPR, HIPAA, FDA 21 CFR Part 11, and EU data protection regulations.
B. The platform SHALL provide a general privacy policy covering all users engaged in personal health tracking.
C. The platform SHALL provide a diary-specific privacy addendum covering application-specific data collection and usage.
D. The platform SHALL provide clinical trial informed consent templates for research participants.
E. The platform SHALL provide sponsor-specific privacy addenda addressing organization-specific requirements.
F. Privacy documentation SHALL include clear explanations of user rights under GDPR, HIPAA, and other applicable regulations.
G. Privacy documentation SHALL include data retention policies compliant with regulatory requirements.
H. Privacy documentation SHALL include contact information for privacy inquiries and data subject rights requests.
I. Privacy documentation SHALL address GDPR compliance for EU residents, including rights to access, rectification, erasure, portability, restriction, and objection.
J. Privacy documentation SHALL address HIPAA compliance for U.S. health data, including PHI safeguards, Business Associate Agreements, and breach notification.
K. Privacy documentation SHALL address FDA 21 CFR Part 11 requirements for clinical trials, including electronic records, electronic signatures, audit trails, and data integrity.
L. Privacy documentation SHALL address EU Clinical Trial Regulation 536/2014 requirements for clinical trial data protection and retention.
M. Privacy documentation SHALL address EU GMP Annex 11 requirements for computerized systems in clinical trials, including 25-year retention.
N. Privacy documentation SHALL address ICH-GCP E6(R2) standards for participant protection and data integrity.
O. Privacy policies SHALL be written in clear, accessible language appropriate for patients and users.
P. Privacy policies SHALL be available in the Diary application.
Q. Privacy policies SHALL be available on sponsor websites.
R. Privacy policies SHALL be updated at least annually.
S. Privacy policies SHALL be updated when material changes occur.
T. Privacy policies SHALL be versioned with effective dates clearly marked.
U. Privacy policies SHALL be provided to users before data collection begins.
V. Privacy policies SHALL require electronic consent from users.
W. The system SHALL maintain an audit trail of all privacy policy consent events including timestamps.
X. The platform SHALL maintain privacy policy version history.
Y. Privacy policy documents SHALL exist for all user types, including personal health tracking users, research participants, and clinical trial participants.
Z. The platform SHALL provide a documented annual review process for privacy policies.

*End* *Privacy Policy and Regulatory Compliance Documentation* | **Hash**: c67b91d2

---

## Executive Summary

This glossary defines the standard terminology used throughout the Diary Platform project. Consistent terminology ensures clear communication among users, healthcare providers, clinical trial staff, developers, and regulatory auditors.

**Key Principles**:
- Primary purpose: Personal health diary for tracking health observations
- Secondary feature: Clinical trial support (extensive but not the core identity)
- Use patient-friendly terms in user-facing contexts (avoid jargon like "ePRO", "eCRF")
- Use regulatory-compliant terms in formal documentation and submissions
- Use precise technical terms in development and architecture documentation
- Maintain consistent terminology across all spec/ files and code

---

## System Components

### Diary Platform / Diary System

**Definition**: The complete system comprising all software, infrastructure, and data storage components that enable individuals to record and manage personal health observations, with optional clinical trial support features.

**Components**:
- Diary (mobile application)
- Sponsor Portal
- Database
- Supporting infrastructure and APIs

**Primary Purpose**: Personal health diary for tracking daily health observations

**Secondary Features**: Clinical trial support, data sharing with healthcare providers, research contribution

**Usage Context**: Use when referring to the entire system architecture or in formal documentation.

**Avoid**: "Clinical Diary Platform" (implies clinical trials are primary), "eSource system", "ePRO platform" (use only in sponsor-specific external documentation)

**See**: REQ-p00044 (Clinical Trial Compliant Diary Platform)

### Diary / Mobile Diary

**Definition**: The iOS and Android smartphone application that individuals use to record daily health observations.

**Preferred Terms**:
- **"Diary"** - Primary term, patient-friendly, simple and clear
- **"Mobile Diary"** - When distinguishing from web portal
- **"Diary app"** - Informal, acceptable when context is clear

**Usage Context**:
- User-facing: "Diary" or "the app"
- Formal documentation: "Diary mobile application"
- Technical documentation: "Mobile Diary" or "Diary app"

**Clinical Trial Context**: May use "Clinical Diary" when emphasizing regulatory compliance

**Avoid**:
- "ePRO application" (too technical, confusing to users)
- "eCRF" (refers to different concept in clinical trials)
- "eSource" (refers to the complete platform, not just the mobile app)
- "Clinical Diary" as the primary name (clinical trials are a feature, not the identity)

**Examples**:
- "Open the Diary and tap the + button to record a nosebleed"
- "The Diary mobile application works offline"
- "When used in clinical trials, the Diary serves as an eSource"

**See**: REQ-p00043 (Diary Mobile Application), prd-diary-app.md

### Sponsor Portal / Portal

**Definition**: The web-based application used by healthcare providers, administrators, and (in clinical trial contexts) investigators, sponsors, auditors, and analysts to review user data, manage accounts, and administer features.

**Preferred Terms**:
- **"Sponsor Portal"** - Primary term, used when distinguishing from mobile Diary
- **"Portal"** - Short form when context is clear

**Usage Context**: Use to distinguish from the mobile Diary application.

**Components**:
- User Data Review
- Admin Dashboard
- Healthcare Provider Dashboard
- Investigator Dashboard (clinical trial feature)
- Auditor Dashboard (clinical trial feature)
- Analyst Dashboard
- Sponsor Configuration (clinical trial feature)

**Note**: Portal serves both personal health tracking use cases (e.g., healthcare provider reviewing a user's diary) and clinical trial use cases (investigator monitoring trial participants).

**Avoid**: "Admin app", "web app" (too generic), "Clinical Trial Portal" as primary name

**See**: REQ-p70001 (Sponsor Portal Application), prd-portal.md

### Database

**Definition**: The PostgreSQL database (hosted on Cloud SQL) that stores all diary entries, audit trails, user accounts, and configuration.

**Architecture**:
- Event Store (immutable audit trail)
- Record State (current values, derived from events)
- Row-Level Security policies for access control

**Usage Context**: Use when discussing data storage, schema, or database architecture.

**Clinical Trial Context**: May be referred to as "Clinical Trial Database" when emphasizing regulatory compliance features.

**See**: REQ-p00046 (Clinical Data Storage System), REQ-p00003 (Separate Database Per Sponsor), prd-database.md

### eSource

**Definition**: The Diary Platform as a whole, when used as the original electronic source of patient-reported data in a clinical trial (as opposed to transcribing from paper diaries).

**Usage Context**: Regulatory submissions, protocol documentation, when emphasizing the system is the primary data source in a clinical trial context.

**Important**:
- "eSource" is a regulatory/clinical trial term, not the system's primary identity
- Refers to the complete platform (Diary + Database + Portal), not just the mobile app
- Use only when discussing clinical trial regulatory compliance

**Regulatory Basis**: FDA guidance on electronic source documentation

**See**: REQ-p00010 (FDA 21 CFR Part 11 Compliance)

---

## Roles and Users

### Personal Health Tracking Roles

#### User

**Definition**: Any individual who uses the Diary Platform. The default term for someone using the Diary for personal health tracking outside of a clinical trial.

**Usage Context**:
- Personal health tracking: "User" is the standard term
- Clinical trial contexts: Use specific role names instead (Study Participant, Investigator, etc.) since "User" is ambiguous when multiple roles exist
- Technical documentation: Acceptable as a generic term when role is irrelevant

**Note**: "User" is acceptable in general documentation. In clinical trial contexts, always prefer specific role names to avoid ambiguity.

#### Healthcare Provider

**Definition**: A licensed healthcare professional (physician, nurse, specialist) who reviews a user's diary data to support clinical care. The healthcare provider typically accesses data through the Portal with the user's consent.

**Usage Context**: Personal health tracking context where the Diary data is shared with a care team.

**Distinction from Investigator**: A Healthcare Provider reviews diary data for clinical care purposes. An Investigator reviews diary data as part of a clinical trial protocol.

**See**: REQ-p70001 (Sponsor Portal Application)

#### Caregiver

**Definition**: A family member or trusted individual who has been granted delegated access to view or assist with a user's diary entries. Caregivers act on behalf of the user and are subject to the same privacy protections.

**Usage Context**: Personal health tracking context where the user shares diary access with someone who helps manage their health.

### Clinical Trial Roles

#### Patient / Study Participant

**Definition**: An individual who uses the mobile Diary to record personal health observations.

**Preferred Terms**:
- **"Patient"** - When emphasizing health tracking context (empathetic, widely understood)
- **"Study Participant"** - When the individual is enrolled in a clinical trial (formal clinical trial context)

**Usage Context**:
- Personal health tracking: "User" (see above) or "Patient"
- Clinical trial context: "Study Participant" or "Patient"
- Formal regulatory submissions: "Study Participant" (when required by convention)

**Key Distinction**: Not all Diary users are in clinical trials. Many use it purely for personal health tracking or to share with their healthcare providers.

**Avoid**: "Subject" (outdated, depersonalizing)

#### Investigator

**Definition**: A licensed clinical researcher responsible for enrolling patients, managing a clinical trial site, and ensuring protocol compliance. This is a clinical-trial-specific role.

**Responsibilities**:
- Enroll patients using linking codes
- Monitor patient engagement and data quality
- Send questionnaires and reminders to patients
- Review patient diary data for protocol compliance

**Access**: Site-specific data only (via Row-Level Security)

**Avoid**: "Site staff", "clinical user", "researcher" (be specific)

**See**: REQ-p00036 (Investigator Site-Scoped Access), REQ-p00037 (Investigator Annotation Restrictions)

#### Site

**Definition**: A physical location (hospital, clinic, research center) where clinical trial activities are conducted. Each site has one or more investigators. This is a clinical-trial-specific concept.

**Usage Context**: Sites are organizational units within a sponsor's clinical trial. Patients are enrolled at a specific site by an investigator at that site.

**See**: REQ-p00018 (Multi-Site Support Per Sponsor)

#### Sponsor

**Definition**: An organization (pharmaceutical company, foundation, research institution) that uses the Diary Platform to support a clinical trial. This is a clinical-trial-specific concept.

**Multi-Sponsor Context**: The Diary Platform supports multiple sponsors simultaneously, with complete data isolation between sponsors (separate databases, portals, and configurations).

**Examples**: Cure HHT Foundation (current), pharmaceutical companies developing HHT treatments

**Key Distinction**: Sponsors are organizations using the clinical trial features of the Diary Platform. Not all Diary Platform deployments involve sponsors—some may be purely personal health tracking.

**See**: REQ-p00001 (Complete Multi-Sponsor Data Separation), prd-architecture-multi-sponsor.md

#### Admin / Administrator

**Definition**: A staff member with privileges to create and manage user accounts, configure sites, and manage system settings. In clinical trial deployments, the Admin is typically a sponsor employee scoped to one sponsor's data.

**Scope**: Sponsor-wide access (all sites within one sponsor) in clinical trial context; organization-wide in non-CT deployments.

**Avoid**: "Sponsor admin" (redundant in CT context), "super admin" (no such role)

**See**: REQ-p00039 (Administrator Access with Audit Trail)

#### Auditor

**Definition**: An independent compliance reviewer with read-only access to all data and audit trails for regulatory compliance verification.

**Access**: Full read-only access across all sites within a sponsor

**Key Distinction**: Auditors can view but NEVER modify data.

**See**: REQ-p00038 (Auditor Compliance Access)

#### Analyst / Data Analyst

**Definition**: A researcher or data scientist with read-only access to data for analysis and reporting.

**Access**: Typically scoped to specific sites (may be sponsor-wide depending on assignment)

**Key Distinction**: Focused on data analysis, not compliance auditing.

**See**: REQ-p00022 (Analyst Read-Only Access)

#### Developer Admin

**Definition**: A system administrator with infrastructure-level access for deployment, monitoring, and maintenance.

**Scope**: Cross-sponsor system administration (database backups, infrastructure monitoring)

**Data Access**: Developer Admins have NO routine access to patient data. A documented break-glass procedure exists for emergency situations only, with full audit trail logging of all access.

**Context**: Internal operations only, not accessible to sponsors or clinical trial users.

**See**: ops-security.md for developer admin procedures

---

## Data and Records

### Diary Entry / Health Observation

**Definition**: A single user-reported record of a health event (e.g., nosebleed episode) including time, severity, duration, and other relevant details.

**Preferred Terms**:
- **"Diary Entry"** - Standard term
- **"Health Observation"** - More formal context
- **"Entry"** - Short form when context is clear

**Usage Context**: Use "diary entry" in user-facing communication and general documentation.

**Clinical Trial Context**: When used in clinical trials, diary entries may capture protocol-specified data elements and serve as ePRO data.

**Avoid**: "Event" (too generic), "Record" (too technical), "Data point" (depersonalizing)

**See**: REQ-p00042 (HHT Epistaxis Data Capture Standard)

### Event Store

**Definition**: The immutable log of all changes to diary entries and system data, implementing the Event Sourcing architectural pattern. Every create, update, or delete operation is stored as an event that is never modified or deleted (append-only). Current state is derived by replaying events, providing a complete change history.

**Usage Context**: Developer and architecture documentation.

**Clinical Trial Context**: The Event Store implements the Audit Trail required by FDA 21 CFR Part 11 and other regulations.

**See**: REQ-p00004 (Immutable Audit Trail via Event Sourcing), REQ-p01000 (Event Sourcing Client Interface), prd-event-sourcing-system.md

### Record State / Current Values

**Definition**: The current values of diary entries and other data, derived from the Event Store by replaying all events. In Event Sourcing architecture, this is the "read model" (also known as a Materialized View in database terminology) optimized for queries.

**Usage Context**: Developer and technical architecture documentation.

**Contrast**: "Event Store" contains the history; "Record State" contains current values.

**See**: REQ-p01006 (Type-Safe Materialized View Queries), prd-event-sourcing-system.md

### Audit Trail

**Definition**: The complete, tamper-evident record of all changes to health data, showing who made each change, when, why, and from what device.

**Key Attributes**:
- Who: User identification
- What: Change description
- When: Timestamp (UTC)
- Why: Reason for change (if applicable)
- Where: Device/platform information

**Usage Context**: Compliance documentation, audit procedures, data integrity requirements.

**Clinical Trial Context**: Required by FDA 21 CFR Part 11, EU Annex 11, and ICH-GCP guidelines for regulatory compliance.

**Implementation**: Implemented using the Event Store architecture (technical term) to create an Audit Trail (regulatory term).

**See**: REQ-p00004 (Immutable Audit Trail via Event Sourcing), REQ-p70006 (Comprehensive Audit Trail), prd-clinical-trials.md

### Linking Code

**Definition**: A unique, cryptographically random 10-character code used to securely connect a user's mobile Diary to a service. In clinical trial deployments, linking codes connect a user's device to their enrollment record at a trial site. In non-clinical-trial contexts, a similar mechanism could connect the Diary to a backup or data-sharing service.

**Format**: 10 characters, alphanumeric, case-insensitive

**Purpose**: Enables secure device connection without transmitting PII or creating accounts before the link is established.

**Usage Context**: Patient enrollment workflow (clinical trials), device provisioning.

**See**: REQ-p70007 (Linking Code Lifecycle Management), REQ-d00078 (Linking Code Validation)

### De-identified Data

**Definition**: Health data with all personally identifiable information (name, email, date of birth, account identifiers) removed, leaving only a participant ID and health observations.

**Purpose**: Enables research analysis and data sharing while protecting user privacy.

**Clinical Trial Context**: De-identified data can be shared with research partners; identified data requires explicit consent. Subject to GDPR and HIPAA requirements.

**See**: REQ-p00016 (Separation of Identity and Clinical Data)

---

## Architecture and Technical Terms

### Multi-Sponsor Isolation

**Definition**: The architectural pattern ensuring complete data separation between different organizations (sponsors) using the Diary Platform for clinical trials.

**Implementation**:
- Separate Cloud SQL database per sponsor
- Separate GCP project per sponsor
- Separate web portal per sponsor (sponsor-specific subdomain)
- Shared mobile Diary app with automatic sponsor detection

**Purpose**: Enables a single codebase to serve multiple sponsors while maintaining regulatory compliance and data privacy.

**Context**: This is a clinical trial feature. Personal health tracking deployments may not use multi-sponsor architecture.

**See**: REQ-p00001 (Complete Multi-Sponsor Data Separation), REQ-p00008 (Single Mobile App for All Sponsors), prd-architecture-multi-sponsor.md

### Offline-First

**Definition**: An architectural approach where the mobile Diary application functions fully without internet connection, storing data locally and synchronizing to the cloud when connectivity is available.

**Benefits**:
- Users can make diary entries anywhere, anytime
- No data loss if internet unavailable
- Reduces dependency on network reliability
- Improves user experience and app responsiveness

**Technical Implementation**: Local sembast NoSQL JSON database on device, background sync service.

**See**: REQ-p00006 (Offline-First Data Entry), REQ-p01001 (Offline Event Queue with Automatic Synchronization), dev-app.md

### Event Sourcing

**Definition**: An architectural pattern where all changes to application state are stored as a sequence of immutable events, rather than overwriting data in place.

**Benefits**:
- Complete history and timeline reconstruction
- No data loss
- Full audit trail for personal health records
- Supports clinical trial regulatory compliance (FDA 21 CFR Part 11) when needed

**Technical Details**: Every change (create, update, delete) appends an event to the Event Store. Current state is derived by replaying events.

**Usage Context**: Technical architecture and developer documentation.

**Note**: Event Sourcing provides value for both personal health tracking (complete history) and clinical trials (regulatory compliance).

**See**: REQ-p00004 (Immutable Audit Trail via Event Sourcing), REQ-p01000 (Event Sourcing Client Interface), prd-event-sourcing-system.md

### CQRS (Command Query Responsibility Segregation)

**Definition**: An architectural pattern separating write operations (commands that create events) from read operations (queries that read current state).

**Implementation in Diary Platform**:
- **Write side**: Diary entries create events in Event Store
- **Read side**: Portal queries read optimized Record State tables
- Event Store and Record State are separate but synchronized

**Benefits**: Optimizes audit trail integrity (write side) and query performance (read side).

**Usage Context**: Technical architecture documentation.

**See**: dev-database.md

### Row-Level Security (RLS)

**Definition**: Database-enforced access control that automatically filters data so users can only access records they are authorized to see, based on their role and sponsor/site assignment.

**Purpose**: Ensures data isolation and role-based access control at the database layer (defense-in-depth).

**Example**: An investigator at Site A cannot see diary entries from patients enrolled at Site B, even if both sites belong to the same sponsor — enforced by PostgreSQL RLS policies.

**Relationship to RBAC**: RBAC defines **what actions** users can perform; RLS defines **what data** users can access.

**Usage Context**: Security architecture, database design.

**See**: REQ-p00015 (Database-Level Access Enforcement), REQ-p00035 (Patient Data Isolation), prd-security-RLS.md

### RBAC (Role-Based Access Control)

**Definition**: Access control paradigm where permissions are assigned to roles (User, Investigator, Admin, etc.) rather than individual users.

**Roles**: User, Healthcare Provider, Caregiver, Investigator, Admin, Auditor, Analyst, Sponsor, Developer Admin

**Usage Context**: Security architecture, access control documentation.

**See**: REQ-p00005 (Role-Based Access Control), prd-security-RBAC.md

---

## Compliance and Regulatory Concepts

### ALCOA+ Principles

**Definition**: Data integrity standards for electronic health records, widely adopted in both clinical and non-clinical contexts.

**ALCOA+ Acronym**:
- **A**ttributable - Who created or modified the data
- **L**egible - Readable and understandable
- **C**ontemporaneous - Recorded at time of occurrence
- **O**riginal - First recording, or certified copy
- **A**ccurate - Correct and complete
- **+C**omplete - All required data present
- **+C**onsistent - Chronological order maintained
- **+E**nduring - Preserved throughout retention period
- **+A**vailable - Accessible for review and audit

**Diary Platform Implementation**: Event Sourcing architecture directly implements ALCOA+ principles:
- **Attributable**: Every event includes user ID and timestamp
- **Legible**: All data stored in readable formats
- **Contemporaneous**: Events recorded immediately
- **Original**: Events never modified (append-only)
- **Accurate**: Validation enforced at entry
- **Complete**: Full audit trail preserved
- **Consistent**: Event Sourcing ensures consistency
- **Enduring**: Retention policies enforced
- **Available**: Query interfaces provide access

**Clinical Trial Context**: Required by FDA and EMA for clinical trial records.

**Usage Context**: Compliance documentation, audit procedures, data integrity requirements.

**See**: REQ-p00011 (ALCOA+ Data Integrity Principles), prd-clinical-trials.md

### Electronic Signature

**Definition**: The automatic attribution of a data entry or change to a specific user account with timestamp and device information. In the Diary Platform, every diary entry and data modification is automatically signed with user account ID, timestamp (UTC), device information, and a cryptographic hash to prevent tampering.

**Usage Context**: All diary entries (personal health tracking and clinical trial) are automatically attributed to the user who created them.

**Clinical Trial Context**: Required by FDA 21 CFR Part 11. Electronic signatures are legally binding, equivalent to a handwritten signature. Users do not manually "sign" entries — the system automatically creates legally binding signatures.

**See**: REQ-p00010 (FDA 21 CFR Part 11 Compliance), prd-clinical-trials.md

### FDA 21 CFR Part 11

**Definition**: U.S. Food and Drug Administration regulation (Title 21 Code of Federal Regulations Part 11) establishing requirements for electronic records and electronic signatures to be considered trustworthy, reliable, and equivalent to paper records.

**Key Requirements**:
- Audit trails for all data changes
- Electronic signatures with cryptographic integrity
- Controlled system access
- Data validation and integrity checks
- Records retention for regulatory-mandated periods

**Diary Platform Context**: Core compliance framework for clinical trial features.

**Usage Context**: Regulatory submissions, compliance documentation.

**See**: REQ-p00010 (FDA 21 CFR Part 11 Compliance), prd-clinical-trials.md

---

## Acronym Reference

Concise definitions of acronyms used across the project, sorted alphabetically. For detailed narrative definitions of ALCOA+, Electronic Signature, and FDA 21 CFR Part 11, see the Compliance and Regulatory Concepts section above.

### AE / SAE (Adverse Event / Serious Adverse Event)

**AE**: Any undesirable medical event occurring in a patient during a clinical trial, whether or not related to the investigational treatment. **SAE**: A severe adverse event resulting in death, hospitalization, disability, or other serious outcomes. Formal AE/SAE reporting is handled through the sponsor's EDC system, not directly through the Diary Platform. SAEs require expedited reporting (typically within 24 hours).

### CDISC (Clinical Data Interchange Standards Consortium)

Organization developing international data standards for clinical trial data exchange. Key standards: **CDASH** (data collection), **SDTM** (data submission format), **ADaM** (analysis datasets). Diary ePRO data can be exported in CDISC-compliant formats for regulatory submission.

### CRA (Clinical Research Associate)

Staff employed by the sponsor or CRO who monitor trial sites to ensure compliance with GCP, the protocol, and regulatory requirements. CRAs perform source data verification (SDV). In the Portal, CRAs typically have **Auditor** role (read-only).

### CRF / eCRF (Case Report Form / Electronic Case Report Form)

The primary tool used by investigators or site staff to record clinical trial data about a patient. **Key distinction**: CRF/eCRF data is entered by clinical trial staff, not by patients. The Diary Platform does not implement traditional eCRFs. Patient diary entries (ePRO data) may be exported to feed into a sponsor's EDC system. **Avoid**: Do not use "eCRF" to refer to patient diary entries.

### CRO (Contract Research Organization)

Organization hired by a sponsor to manage aspects of a clinical trial. CRO staff typically have **Auditor** or **Analyst** roles in the Portal.

### CTMS (Clinical Trial Management System)

Software for managing operational aspects of a clinical trial. The Diary Platform is not a CTMS — it is specifically a health diary / ePRO data collection system. Sponsors typically use a separate CTMS alongside the Diary Platform.

### eCOA (Electronic Clinical Outcome Assessment)

Umbrella term for electronic capture of clinical outcomes: **ePRO** (patient reports), **ClinRO** (clinician assessment), **ObsRO** (observer/caregiver reports), **PerfO** (performance measurements). The Diary is specifically an ePRO tool.

### EDC (Electronic Data Capture)

Software systems used to collect, manage, and store clinical trial data electronically, typically including eCRFs. The Diary Platform is not a full EDC system — it provides ePRO data that may be exported to a sponsor's EDC system (e.g., Medidata Rave, Oracle InForm).

### EMA (European Medicines Agency)

European Union agency responsible for evaluating and supervising medicines. For EU clinical trials, the Diary Platform complies with EU Clinical Trial Regulation 536/2014 and EU GMP Annex 11.

### ePRO (Electronic Patient-Reported Outcomes)

Electronic collection of health information reported directly by the patient, without interpretation by clinicians. The Diary functions as an ePRO tool when used in clinical trials. **Important**: While technically accurate, avoid "ePRO" in user-facing communication. Use "Diary" instead. **See**: REQ-p00043 (Diary Mobile Application)

### ESS (Epistaxis Severity Score)

Standardized clinical assessment tool measuring the severity and impact of nosebleeds in HHT patients. Calculated from patient-reported diary data. Specific to HHT clinical trials.

### FDA (U.S. Food and Drug Administration)

United States federal agency responsible for regulating pharmaceuticals, medical devices, and clinical trials. **See**: REQ-p00010 (FDA 21 CFR Part 11 Compliance)

### GCP (Good Clinical Practice)

International ethical and scientific quality standards governing clinical trial conduct, including data collection, management, and participant protection. Primary guideline: ICH E6(R2). **Note**: "GCP" also stands for "Google Cloud Platform" — context determines meaning.

### GDPR (General Data Protection Regulation)

European Union regulation governing data protection and privacy for EU residents. EU users have GDPR rights (access, rectification, erasure, portability). Clinical trial participation may limit some rights for data integrity reasons. Applies based on **user location**, not sponsor location. **See**: REQ-p01061 (GDPR Compliance), REQ-p01062 (GDPR Data Portability)

### Google Cloud Platform (GCP)

Cloud infrastructure provider hosting the Diary Platform: Cloud SQL (PostgreSQL database), Identity Platform (authentication), Cloud Storage (backups), per-sponsor GCP projects for multi-sponsor isolation. **Note**: In clinical trial contexts, "GCP" typically refers to Good Clinical Practice.

### HHT (Hereditary Hemorrhagic Telangiectasia)

Genetic disorder causing abnormal blood vessel formation, leading to frequent nosebleeds and other complications. The Diary Platform was initially developed for HHT patients but supports any health tracking use case. Current sponsor: Cure HHT Foundation.

### HIPAA (Health Insurance Portability and Accountability Act)

United States federal law protecting the privacy and security of individuals' medical information. Key requirement: Business Associate Agreements (BAAs) with service providers. **See**: REQ-p01020 (Privacy Policy and Regulatory Compliance Documentation)

### ICF (Informed Consent Form)

Signed document where a patient agrees to participate in a clinical trial. Must include how the Diary will be used, what data will be shared, privacy protections, and right to withdraw. The Diary Platform supports electronic ICF signatures compliant with 21 CFR Part 11.

### ICH (International Council for Harmonisation)

Organization developing international standards for clinical trials. Key guidelines: **ICH E6(R2)** (Good Clinical Practice), **ICH E8** (General Considerations for Clinical Studies), plus Quality (Q), Safety (S), Efficacy (E), and Multidisciplinary (M) guidelines.

### ICH-GCP / ICH E6(R2)

The foundational international ethical and scientific quality standard for clinical trials involving human subjects. The 2016 revision emphasizes risk-based monitoring and data integrity. The Diary Platform follows ICH-GCP guidelines for data integrity (ALCOA+), audit trails, source data verification, and participant protection. **See**: REQ-p00011 (ALCOA+ Data Integrity Principles)

### IMP (Investigational Medicinal Product)

The drug, biological product, or device being tested in a clinical trial. Diary entries help assess the IMP's efficacy and potential side effects.

### IND / NDA (Investigational New Drug / New Drug Application)

**IND**: Application to the FDA to test a new drug in humans. **NDA**: Application for FDA approval to market a drug. Sponsors submit Diary ePRO data as part of IND (during trials) and NDA (for approval) submissions.

### IRB / IEC (Institutional Review Board / Independent Ethics Committee)

**IRB** (U.S.) / **IEC** (international): Independent ethics committee that reviews and approves clinical trial protocols, informed consent forms, and data privacy measures before a sponsor can use the Diary Platform at a trial site. Ongoing approval required for any changes to Diary data collection procedures.

### NOSE-HHT (Nasal Outcome Score for Epistaxis in HHT)

Validated patient-reported outcome measure for assessing nosebleed impact in HHT patients. May be collected as a questionnaire within the Diary app during clinical trials. Specific to HHT clinical trials.

### PHI (Protected Health Information)

Any individually identifiable health information protected under HIPAA (name, dates, contact information, medical record numbers, health data linked to an individual). PHI is encrypted at rest and in transit, subject to strict access controls via RBAC and RLS policies. **See**: REQ-p00016 (Separation of Identity and Clinical Data), prd-security-data-classification.md

### PI / Sub-I (Principal Investigator / Sub-Investigator)

**PI**: Lead physician at a clinical trial site. **Sub-I**: Physicians or staff assisting the PI. Both have **Investigator** role access in the Portal. **See**: REQ-p00036 (Investigator Site-Scoped Access)

### PII (Personally Identifiable Information)

Information that can identify, contact, or locate a specific individual, protected under GDPR and other privacy regulations. Overlap with PHI: all PHI is PII, but not all PII is PHI. **See**: prd-security-data-classification.md

### PRO (Patient-Reported Outcome)

Any report of a patient's health condition that comes directly from the patient, without interpretation by a clinician. Diary entries are PROs. When collected electronically via the Diary app, they become ePROs.

### SDV (Source Data Verification)

Process of verifying that data in the trial database matches original source documents. For the Diary Platform, diary entries **are** the source (eSource) — no paper transcription occurs. SDV focuses on verifying audit trails, timestamps, and data integrity.

### UTC (Coordinated Universal Time)

Primary time standard used worldwide, not affected by time zones or daylight saving time. All database and audit trail timestamps are stored in UTC (with the patient's timezone offset for ePROs). Displayed in the user's local time zone in the Diary app and Portal.

---

## Deprecated and Avoided Terms

### Avoid: "ePRO" (Electronic Patient-Reported Outcomes)

**Problem**: Technical jargon, not meaningful to users, commonly confused with eCRF, implies clinical trials are the primary purpose.

**Use Instead**: "Diary" (user-facing and formal documentation)

**Exception**: May be used in sponsor-specific external documentation (privacy policies, marketing) when required by sponsor for clinical trial context.

### Avoid: "eCRF" (Electronic Case Report Form)

**Problem**: In traditional clinical trials, eCRF refers to forms filled out by investigators, NOT patients. Using eCRF for patient diary entries creates confusion.

**Correct Distinction**:
- **Diary entries**: User-reported health observations
- **eCRF**: Investigator-completed case report forms (not implemented in current system)

**Use Instead**: "Diary entry", "Health observation"

### Avoid: "Subject"

**Problem**: Outdated, depersonalizing terminology from earlier clinical research practices.

**Use Instead**: "User" (general), "Patient" (health context), or "Study Participant" (clinical trial context)

### Avoid: "User" in clinical trial contexts (without qualifier)

**Problem**: In clinical trial contexts, "user" is ambiguous — could refer to patient, investigator, admin, auditor, or analyst.

**Use Instead**: Specific role name (Patient, Study Participant, Investigator, Admin, etc.)

**Note**: "User" is the standard term for individuals using the Diary for personal health tracking (non-clinical trial context).

### Avoid: "App" (without qualifier in formal docs)

**Problem**: Ambiguous — could refer to mobile Diary or web Portal.

**Use Instead**: "Diary" for the mobile application, "Portal" for web application.

**Exception**: "App" is acceptable in user-facing communication when context is clear (e.g., "Open the app").

---

## Sponsor-Specific Terminology

### Cure HHT Foundation Context

**Disease**: Hereditary Hemorrhagic Telangiectasia (HHT)

**Primary Health Observation**: Epistaxis events (nosebleeds)

**Sponsor-Specific Terms**:
- "Nosebleed Diary" - User-friendly name for the Diary
- "Epistaxis events" - Clinical term for nosebleeds
- "HHT-specific assessments" - Quality of life questionnaires, severity scores

**Note**: Terminology may vary for other sponsors. The core system uses generic terms (Diary, health observation) that adapt to sponsor-specific branding.

---

## Usage Guidelines by Audience

### User-Facing Communication

**Use**:
- Diary, the app
- Diary entry
- Your health observations
- Nosebleed (or other specific health event terms)
- Your doctor, your care team

**Avoid**:
- ePRO, eCRF, eSource
- Event Store, Record State
- Clinical trial jargon (unless user is in a trial)
- Technical jargon

### Healthcare Provider / Clinical Trial Staff

**Use**:
- Diary
- Portal
- Patient (healthcare context), study participant (clinical trial context)
- Investigator, site, sponsor (clinical trial context)
- Linking code
- Diary entry, health observation

**Avoid**:
- Technical architecture terms (Event Store, CQRS)
- Developer jargon

### Regulatory and Compliance Documentation

**Use**:
- Diary Platform, Diary System
- eSource (when emphasizing clinical trial regulatory context)
- Study participant (clinical trial context)
- Audit trail, electronic signature
- ALCOA+ principles
- FDA 21 CFR Part 11
- Event Store (when discussing technical compliance implementation)

**Avoid**:
- "Clinical Diary Platform" as primary name (clinical trials are a feature)
- Informal terms without context

### Developer and Technical Documentation

**Use**:
- All technical terms (Event Store, CQRS, RLS, offline-first, etc.)
- Mobile Diary, Portal, Database
- Precise architectural terminology

**Avoid**:
- Generic terms (app, user) without qualification
- Regulatory jargon without explanation

---

## Cross-References

**Related Documentation**:
- **prd-architecture-multi-sponsor.md** - System architecture and multi-sponsor isolation (clinical trial feature)
- **prd-diary-app.md** - Mobile Diary application features
- **prd-portal.md** - Sponsor Portal features
- **prd-database.md** - Database architecture, Event Sourcing, audit trails
- **prd-privacy-policy.md** - Privacy policy and regulatory compliance documentation (REQ-p01020)
- **prd-security.md** - Authentication, authorization, role definitions
- **prd-security-RBAC.md** - Role-based access control specifications
- **prd-security-RLS.md** - Row-level security policies
- **prd-security-data-classification.md** - Data classification and PHI/PII handling
- **prd-clinical-trials.md** - Regulatory compliance requirements (clinical trial feature)
- **prd-event-sourcing-system.md** - Event Sourcing architecture

---

## Document Control

**Version History**:
- Version 2.0 (2026-02-09) - Consistency rewrite: reframed definitions to lead with personal health diary context, consolidated duplicates, merged regulatory sections, standardized format with REQ cross-references, resolved TODOs, added personal health tracking roles (User, Healthcare Provider, Caregiver), moved REQ-p01020 to prd-privacy-policy.md
- Version 1.0 (2025-12-02) - Initial glossary creation

**Review Schedule**: Review quarterly and update when new terminology is introduced

**Approval**: This glossary establishes canonical terminology for all spec/ files and project documentation.
