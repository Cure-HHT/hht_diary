# Diary Platform - Glossary

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-02
**Status**: Draft

> **Purpose**: Establishes canonical terminology for the Diary Platform across all documentation, requirements, and communication.

---

# REQ-p01020: Privacy Policy and Regulatory Compliance Documentation

**Level**: PRD | **Status**: Draft | **Implements**: p00010

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

This glossary defines the standard terminology used throughout the Diary Platform project. Consistent terminology ensures clear communication among patients, clinical trial staff, developers, and regulatory auditors.

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

### Diary / Mobile Diary

**Definition**: The iOS and Android smartphone application that individuals use to record daily health observations.

**Preferred Terms**:
- **"Diary"** - Primary term, patient-friendly, simple and clear
- **"Mobile Diary"** - When distinguishing from web portal
- **"Diary app"** - Informal, acceptable when context is clear

**Usage Context**:
- Patient-facing: "Diary" or "the app"
- Formal documentation: "Diary mobile application"
- Technical documentation: "Mobile Diary" or "Diary app"
- Clinical trial context: May use "Clinical Diary" when emphasizing regulatory compliance

**Avoid**:
- "ePRO application" (too technical, confusing to patients)
- "eCRF" (refers to different concept in clinical trials)
- "eSource" (refers to the complete platform, not just the mobile app)
- "Clinical Diary" as the primary name (clinical trials are a feature, not the identity)

**Examples**:
- ✓ "Open the Diary and tap the + button to record a nosebleed"
- ✓ "The Diary mobile application works offline"
- ✓ "When used in clinical trials, the Diary serves as an eSource"
- ✗ "Launch the ePRO app to enter your eCRF data"

### Sponsor Portal / Portal

**Definition**: The web-based application used by healthcare providers, investigators, admins, sponsors, auditors, and analysts to review patient data, manage users, and administer features.

**Preferred Terms**:
- **"Portal"** - Short form when context is clear
- **"Sponsor Portal"** - When distinguishing from mobile Diary
- **"Sponsor Portal"** - When emphasizing clinical trial features specifically

**Usage Context**: Use to distinguish from the mobile Diary application.

**Components**:
- Patient Data Review
- Investigator Dashboard (clinical trial feature)
- Admin Dashboard
- Auditor Dashboard (clinical trial feature)
- Analyst Dashboard
- Sponsor Configuration (clinical trial feature)

**Note**: Portal serves both personal health tracking use cases (e.g., healthcare provider reviewing patient's diary) and clinical trial use cases (investigator monitoring trial participants)

**Avoid**: "Admin app", "web app" (too generic), "Clinical Trial Portal" as primary name

### Database

**Definition**: The PostgreSQL database (hosted on Cloud SQL) that stores all diary entries, audit trails, user accounts, and configuration.

**Architecture**:
- Event Store (immutable audit trail)
- Record State (current values, derived from events)
- Row-Level Security policies for access control

**Usage Context**: Use when discussing data storage, schema, or database architecture.

**Clinical Trial Context**: May be referred to as "Clinical Trial Database" when emphasizing regulatory compliance features

**See**: prd-database.md for complete database architecture

### eSource

**Definition**: The Diary Platform as a whole, when used as the original electronic source of patient-reported data in a clinical trial (as opposed to transcribing from paper diaries).

**Usage Context**: Regulatory submissions, protocol documentation, when emphasizing the system is the primary data source in a clinical trial context.

**Important**:
- "eSource" is a regulatory/clinical trial term, not the system's primary identity
- Refers to the complete platform (Diary + Database + Portal), not just the mobile app
- Use only when discussing clinical trial regulatory compliance

**See**: FDA guidance on electronic source documentation

---

## Roles and Users

### Patient / User / Study Participant

**Definition**: An individual who uses the mobile Diary to record personal health observations.

**Preferred Terms**:
- **"Patient"** - When emphasizing health tracking context (most empathetic)
- **"User"** - When emphasizing the individual's relationship to the app (generic but acceptable)
- **"Study Participant"** - When the individual is enrolled in a clinical trial (formal clinical trial context)

**Usage Context**:
- Personal health tracking: "Patient" or "User"
- Clinical trial context: "Study Participant" or "Patient"
- Formal regulatory submissions: "Study Participant" (when required by convention)

**Key Distinction**: Not all Diary users are in clinical trials. Many use it purely for personal health tracking or to share with their healthcare providers.

**Avoid**: "Subject" (outdated, depersonalizing)

### Investigator

**Definition**: A licensed clinical researcher responsible for enrolling patients, managing a clinical trial site, and ensuring protocol compliance.

**Responsibilities**:
- Enroll patients using linking codes
- Monitor patient engagement and data quality
- Send questionnaires and reminders to patients
- Review patient diary data for protocol compliance

**Access**: Site-specific data only (via Row-Level Security)

**Avoid**: "Site staff", "clinical user", "researcher" (be specific)

### Site

**Definition**: A physical location (hospital, clinic, research center) where clinical trial activities are conducted. Each site has one or more investigators.

**Usage Context**: Sites are organizational units within a sponsor's clinical trial. Patients are enrolled at a specific site by an investigator at that site.

### Sponsor

**Definition**: An organization (pharmaceutical company, foundation, research institution) that uses the Diary Platform to support a clinical trial.

**Multi-Sponsor Context**: The Diary Platform supports multiple sponsors simultaneously, with complete data isolation between sponsors (separate databases, portals, and configurations).

**Examples**: Cure HHT Foundation (current), pharmaceutical companies developing HHT treatments

**Key Distinction**: Sponsors are organizations using the clinical trial features of the Diary Platform. Not all Diary Platform deployments involve sponsors—some may be purely personal health tracking.

**See**: prd-architecture-multi-sponsor.md for isolation architecture

### Admin / Administrator

**Definition**: A sponsor employee with privileges to create and manage user accounts, configure sites, and manage system settings for their sponsor.

**Scope**: Sponsor-wide access (all sites within one sponsor)

**Avoid**: "Sponsor admin" (redundant), "super admin" (no such role)

### Auditor

**Definition**: An independent compliance reviewer with read-only access to all clinical trial data and audit trails for regulatory compliance verification.

**Access**: Full read-only access across all sites within a sponsor

**Key Distinction**: Auditors can view but NEVER modify data

### Analyst / Data Analyst

**Definition**: A researcher or data scientist with read-only access to clinical trial data for analysis and reporting.

**Access**: Typically scoped to specific sites (may be sponsor-wide depending on assignment)

**Key Distinction**: Focused on data analysis, not compliance auditing

### Developer Admin

**Definition**: A system administrator with infrastructure-level access for deployment, monitoring, and maintenance.

**Scope**: Cross-sponsor system administration (database backups, infrastructure monitoring)

**Context**: Internal operations only, not accessible to sponsors or clinical trial users

**See**: ops-security.md for developer admin procedures

TODO - does the developer admin have access to patient data?

---

## Data and Records

### Diary Entry / Health Observation

**Definition**: A single patient-reported record of a health event (e.g., nosebleed episode) including time, severity, duration, and other protocol-specified details.

**Preferred Terms**:
- **"Diary Entry"** - Standard term
- **"Health Observation"** - More formal/clinical context
- **"Entry"** - Short form when context is clear

**Avoid**: "Event" (too generic), "Record" (too technical), "Data point" (depersonalizing)

**Usage Context**: Use "diary entry" in patient-facing communication and general documentation.

### Event Store

**Definition**: The immutable audit trail of all changes to diary entries and system data, implementing the Event Sourcing architectural pattern.

**Technical Details**:
- Every create, update, delete operation is stored as an event
- Events are never modified or deleted (append-only)
- Current state is derived by replaying events
- Provides complete change history for regulatory compliance

**Usage Context**: Developer and architecture documentation

**See**: prd-database.md, dev-database.md, prd-event-sourcing-system.md for Event Sourcing implementation

### Audit Trail

**Definition**: The complete, tamper-evident record of all changes to clinical trial data, showing who made each change, when, why, and from what device.

**Regulatory Context**: Required by FDA 21 CFR Part 11, EU Annex 11, and ICH-GCP guidelines

**Implementation**: Implemented using the Event Store architecture (technical term) to create an Audit Trail (regulatory term)

**Key Attributes**:
- Who: User identification
- What: Change description
- When: Timestamp (UTC)
- Why: Reason for change (if applicable)
- Where: Device/platform information

**Usage Context**: Regulatory and compliance documentation

**See**: prd-clinical-trials.md for audit requirements

### Record State / Current Values

**Definition**: The current values of diary entries and other data, derived from the Event Store by replaying all events.

**Technical Context**: In Event Sourcing architecture, this is the "read model" optimized for queries

**Usage Context**: Developer and technical architecture documentation

**Contrast**: "Event Store" contains the history; "Record State" contains current values

TODO - perhaps "Materialized View" should be mentioned here.

**See** prd-event-sourcing-system.md

### Linking Code

**Definition**: A unique, cryptographically random 10-character code used to securely connect a patient's mobile Diary to their clinical trial enrollment record.

TODO - It's it linking the patient id (or "participant Id" below) with the enrollment code?

**Format**: 10 characters, alphanumeric, case-insensitive

**Purpose**: Enables patient enrollment without transmitting PHI or creating accounts before enrollment

**Usage Context**: Patient enrollment workflow, investigator instructions

**See**: prd-portal.md (REQ-p70007) for lifecycle rules, dev-portal.md (REQ-d00038) for implementation

### De-identified Data

**Definition**: Clinical trial data with all personally identifiable information (name, email, date of birth, account identifiers) removed, leaving only the study participant ID and health observations.

**Purpose**: Enables research analysis and data sharing while protecting patient privacy

**Regulatory Context**: GDPR, HIPAA requirements for data sharing and research

**Key Distinction**: De-identified data can be shared with research partners; identified data requires explicit consent

---

## Compliance and Regulatory Terms

### ALCOA+ Principles

**Definition**: Data integrity standards required by FDA for electronic records in clinical trials.

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

**Usage Context**: Compliance documentation, audit procedures, data integrity requirements

**See**: prd-clinical-trials.md for ALCOA+ implementation requirements

### Electronic Signature

**Definition**: The automatic attribution of a data entry or change to a specific user account with timestamp and device information, providing legally binding identification equivalent to a handwritten signature.

**Regulatory Basis**: FDA 21 CFR Part 11

**Technical Implementation**: Every diary entry and data modification is automatically signed with:
- User account ID
- Timestamp (UTC, cryptographically verified)
- Device information (platform, app version, device uuid)
- Cryptographic hash to prevent tampering

**Usage Context**: Clinical trial data submissions, regulatory compliance

**Important**: Users do not manually "sign" entries—the system automatically creates legally binding signatures

**See**: prd-clinical-trials.md (REQ-p00101) for electronic signature requirements

### FDA 21 CFR Part 11

**Definition**: U.S. Food and Drug Administration regulation establishing requirements for electronic records and electronic signatures in clinical trials.

**Key Requirements**:
- Audit trails for all data changes
- Electronic signatures with cryptographic integrity
- Controlled system access
- Data validation and integrity checks
- Records retention for regulatory-mandated periods

**Usage Context**: Regulatory submissions, compliance documentation

**See**: prd-clinical-trials.md for Part 11 compliance requirements

### Row-Level Security (RLS)

**Definition**: Database-enforced access control that automatically filters data so users can only access records they are authorized to see, based on their role and sponsor/site assignment.

**Purpose**: Ensures multi-sponsor data isolation and role-based access control at the database layer (defense-in-depth)

**Example**: An investigator at Site A cannot see diary entries from patients enrolled at Site B, even if both sites belong to the same sponsor—enforced by PostgreSQL RLS policies.

**Usage Context**: Security architecture, database design

**See**: prd-security-RLS.md for RLS policy specifications

---

## Architecture and Technical Terms

### Multi-Sponsor Isolation

**Definition**: The architectural pattern ensuring complete data separation between different organizations (sponsors) using the Diary Platform for clinical trials.

**Implementation**:
- Separate Cloud SQL database per sponsor
- Separate GCP project per sponsor
- Separate web portal per sponsor (sponsor-specific subdomain)
- Shared mobile Diary app with automatic sponsor detection

**Purpose**: Enables a single codebase to serve multiple sponsors while maintaining regulatory compliance and data privacy

**Context**: This is a clinical trial feature. Personal health tracking deployments may not use multi-sponsor architecture.

**See**: prd-architecture-multi-sponsor.md for complete architecture

### Offline-First

**Definition**: An architectural approach where the mobile Diary application functions fully without internet connection, storing data locally and synchronizing to the cloud when connectivity is available.

**Benefits**:
- Patients can make diary entries anywhere, anytime
- No data loss if internet unavailable
- Reduces dependency on network reliability
- Improves user experience and app responsiveness

**Technical Implementation**: Local sembast NoSql json database on device, background sync service

**See**: dev-app.md for offline-first implementation

### Event Sourcing

**Definition**: An architectural pattern where all changes to application state are stored as a sequence of immutable events, rather than overwriting data in place.

**Benefits**:
- Complete history and timeline reconstruction
- No data loss—ever
- Full audit trail for personal health records
- Supports clinical trial regulatory compliance (FDA 21 CFR Part 11) when needed

**Technical Details**: Every change (create, update, delete) appends an event to the Event Store. Current state is derived by replaying events.

**Usage Context**: Technical architecture and developer documentation

**Note**: Event Sourcing provides value for both personal health tracking (complete history) and clinical trials (regulatory compliance)

**See**: prd-database.md, dev-database.md, prd-event-sourcing-system.md for Event Sourcing implementation

### CQRS (Command Query Responsibility Segregation)

**Definition**: An architectural pattern separating write operations (commands that create events) from read operations (queries that read current state).

**Implementation in Diary Platform**:
- **Write side**: Diary entries create events in Event Store
- **Read side**: Portal queries read optimized Record State tables
- Event Store and Record State are separate but synchronized

**Benefits**: Optimizes audit trail integrity (write side) and query performance (read side)

**Usage Context**: Technical architecture documentation

**See**: dev-database.md for CQRS implementation

---

## Deprecated and Avoided Terms

### Avoid: "ePRO" (Electronic Patient-Reported Outcomes)

**Problem**: Technical jargon, not meaningful to patients, commonly confused with eCRF, implies clinical trials are the primary purpose

**Use Instead**: "Diary" (patient-facing and formal documentation)

**Exception**: May be used in sponsor-specific external documentation (privacy policies, marketing) when required by sponsor for clinical trial context

### Avoid: "eCRF" (Electronic Case Report Form)

**Problem**: In traditional clinical trials, eCRF refers to forms filled out by investigators, NOT patients. Using eCRF for patient diary entries creates confusion.

**Correct Distinction**:
- **Diary entries**: Patient-reported health observations
- **eCRF**: Investigator-completed case report forms (not implemented in current system)

**Use Instead**: "Diary entry", "Health observation"

### Avoid: "Subject"

**Problem**: Outdated, depersonalizing terminology from earlier clinical research practices

**Use Instead**: "Patient" or "Study Participant"

TODO - how about another name for the user not in a study?  They aren't their doctor's patient, yeah?  

### Avoid: "User" in clinical trial contexts (without qualifier)

**Problem**: In clinical trial contexts, "user" is ambiguous—could refer to patient, investigator, admin, auditor, or analyst

**Use Instead**: Specific role name (Patient, Study Participant, Investigator, Admin, etc.)

**Note**: "User" is acceptable when referring to individuals using the Diary for personal health tracking (non-clinical trial context)

TODO - is there a good generic name for a portal user? "Portal User"?

### Avoid: "App" (without qualifier in formal docs)

**Problem**: Ambiguous—could refer to mobile Diary or web Portal

**Use Instead**: "Diary" for the mobile application, "Portal" for web application

**Exception**: "App" is acceptable in patient-facing communication when context is clear (e.g., "Open the app")

---

## Clinical Trial and Medical Acronyms

### CRF (Case Report Form) / eCRF (Electronic Case Report Form)

**Definition**: The primary tool used by investigators or site staff to record clinical trial data about a patient, including clinical assessments, adverse events, concomitant medications, lab results, and protocol-specific measurements. The **eCRF** is the electronic version within an EDC (Electronic Data Capture) system.

**Key Distinction**: CRF/eCRF data is entered by **clinical trial staff** (investigators, study coordinators), not by patients.

**Diary Platform Context**: The Diary Platform does **not** implement traditional eCRFs. Investigators use the Portal to review patient-entered diary data, but they do not fill out separate case report forms about patients. The patient's Diary entries (ePRO data) serve as the primary data source and may be referenced or exported to feed into a sponsor's EDC system where eCRFs exist.

**Important Terminology Note**: The exact same data element (e.g., "nosebleed frequency") would be:
- **ePRO** if the patient enters it themselves in the Diary
- **eCRF** if an investigator enters it based on patient interview or medical records

**Avoid**: Do not use "eCRF" to refer to patient diary entries—this creates confusion with traditional clinical trial terminology.

### ePRO (Electronic Patient-Reported Outcomes)

**Definition**: Electronic collection of health information reported directly by the patient, without interpretation by clinicians.

**Key Distinction**: ePRO data is entered by **patients themselves**, reporting their own symptoms, experiences, and health observations.

**Diary Platform Context**: The Diary application functions as an ePRO tool when used in clinical trials—patients directly report their health observations (nosebleeds, symptoms, quality of life) via the mobile app.

**Important**: While "ePRO" is technically accurate for the Diary's clinical trial function, we avoid using this jargon in patient-facing communication. Use "Diary" instead.

**Usage**:
- Internal/regulatory: "The Diary serves as an ePRO system for collecting patient-reported outcomes"
- Patient-facing: "Use the Diary to record your daily nosebleeds"

### PRO (Patient-Reported Outcome)

**Definition**: Any report of a patient's health condition that comes directly from the patient, without interpretation by a clinician.

**Diary Platform Context**: Diary entries are PROs—direct reports from patients about their health. When collected electronically via the Diary app, they become ePROs.

**Contrast**: A doctor's assessment of the patient's condition would **not** be a PRO.

### eCOA (Electronic Clinical Outcome Assessment)

**Definition**: An umbrella term for electronic capture of clinical outcomes, including four types:
- **ePRO**: Electronic Patient-Reported Outcome (patient reports)
- **ClinRO**: Clinician-Reported Outcome (clinician assessment)
- **ObsRO**: Observer-Reported Outcome (caregiver/observer reports)
- **PerfO**: Performance Outcome (objective measurements like walk tests)

**Diary Platform Context**: The Diary is specifically an **ePRO** tool (patient-reported outcomes). It does not collect ClinRO, ObsRO, or PerfO data—those would be entered by clinical staff through other systems.

**Usage**: In regulatory submissions, the Diary may be referred to as "an eCOA system for capturing ePRO data."

### PHI (Protected Health Information)

**Definition**: Any individually identifiable health information protected under HIPAA, including name, dates, contact information, medical record numbers, and health data that can be linked to an individual.

**Diary Platform Context**:
- **PHI examples**: Patient name, email, date of birth
- **Not PHI**: De-identified study participant ID, aggregate statistics, diary entries with all identifiers removed

**Security**: PHI is encrypted at rest and in transit, subject to strict access controls via RBAC and RLS policies.

**See**: prd-security-data-classification.md for PHI handling requirements

### PII (Personally Identifiable Information)

**Definition**: Information that can be used to identify, contact, or locate a specific individual, protected under GDPR and other privacy regulations.

**Diary Platform Context**:
- **PII examples**: Name, email address, IP address (in some contexts), device identifiers
- **Not PII**: De-identified study participant ID, anonymized usage statistics

**Overlap with PHI**: All PHI is PII, but not all PII is PHI. For example, email address is PII but only becomes PHI when linked to health data.

**See**: prd-security-data-classification.md for PII handling requirements

### ESS (Epistaxis Severity Score)

**Definition**: A standardized clinical assessment tool measuring the severity and impact of nosebleeds in patients with Hereditary Hemorrhagic Telangiectasia (HHT).

**Diary Platform Context**: ESS is calculated from patient-reported diary data (frequency, duration, intensity of nosebleeds). When used in clinical trials, ESS serves as a primary or secondary endpoint.

**Usage**: Specific to HHT clinical trials; other sponsors may use different outcome measures.

### NOSE-HHT (Nasal Outcome Score for Epistaxis in HHT)

**Definition**: A validated patient-reported outcome measure specifically designed for assessing nosebleed impact in HHT patients.

**Diary Platform Context**: May be collected as a questionnaire within the Diary app during clinical trials.

**Usage**: Specific to HHT clinical trials.

### HHT (Hereditary Hemorrhagic Telangiectasia)

**Definition**: A genetic disorder causing abnormal blood vessel formation, leading to frequent nosebleeds and other complications.

**Diary Platform Context**: The Diary Platform was initially developed for HHT patients to track epistaxis events, but the platform architecture supports any health tracking use case.

**Current Sponsor**: Cure HHT Foundation

### RLS (Row-Level Security)

**Definition**: Database-enforced access control that automatically filters query results so users can only access rows (records) they are authorized to see.

**Diary Platform Context**: PostgreSQL RLS policies ensure multi-sponsor data isolation and role-based access. For example, an investigator at Site A cannot query diary entries from Site B, even though both sites' data exists in the same database.

**Technical Implementation**: RLS policies check user role and sponsor/site assignment on every database query.

**See**: prd-security-RLS.md, ops-security-RLS.md for policy specifications

### RBAC (Role-Based Access Control)

**Definition**: Access control paradigm where permissions are assigned to roles (Patient, Investigator, Admin, etc.) rather than individual users.

**Diary Platform Context**: The system defines specific roles with predefined permissions. Users are assigned one or more roles, inheriting those permissions.

**Roles**: Patient, Investigator, Admin, Auditor, Analyst, Sponsor, Developer Admin

**Relationship to RLS**: RBAC defines **what actions** users can perform; RLS defines **what data** users can access.

**See**: prd-security-RBAC.md for role definitions and permissions

### EDC (Electronic Data Capture)

**Definition**: Software systems used to collect, manage, and store clinical trial data electronically, typically including eCRFs for investigator data entry.

**Diary Platform Context**: The Diary Platform is **not** a full EDC system—it is specifically an ePRO (patient data) system. Sponsors may integrate Diary data into their existing EDC systems (e.g., Medidata Rave, Oracle InForm) for comprehensive trial data management.

**Relationship**: The Diary provides **ePRO data** that may be exported to a sponsor's **EDC system** containing eCRFs and other trial data.

### eSource

**Definition**: Electronic records that serve as the original source of clinical data, as opposed to transcribing from paper records.

**Diary Platform Context**: The Diary Platform functions as an eSource system—patient diary entries are the original electronic records, not transcriptions from paper diaries.

**Regulatory Importance**: eSource systems must comply with FDA 21 CFR Part 11 and maintain complete audit trails.

**Note**: Previously defined in "System Components" section; included here for completeness.

### GCP (Good Clinical Practice)

**Definition**: The international ethical and scientific quality standards that govern how clinical trials must be conducted, including data collection, management, and participant protection.

**Regulatory Framework**: ICH E6(R2) is the primary GCP guideline.

**Diary Platform Context**: The Diary Platform's clinical trial features comply with GCP requirements, including:
- Informed consent processes
- Audit trails for data integrity
- Participant privacy protection
- Data quality controls

**See Also**: ICH-GCP in Regulatory Acronyms section

**Note**: GCP also stands for "Google Cloud Platform"—context determines meaning. In clinical trial documentation, GCP means Good Clinical Practice.

### Google Cloud Platform (GCP)

**Definition**: Cloud infrastructure provider hosting the Diary Platform's database, authentication, and supporting services.

**Diary Platform Context**:
- Cloud SQL (PostgreSQL database)
- Identity Platform (authentication)
- Cloud Storage (backups)
- Per-sponsor GCP projects for multi-sponsor isolation

**Alternative**: Some documentation references "Google Cloud" instead of "GCP"—both are acceptable.

**Note**: In clinical trial contexts, "GCP" typically refers to "Good Clinical Practice," not Google Cloud Platform.

### UTC (Coordinated Universal Time)

**Definition**: Primary time standard used worldwide, not affected by time zones or daylight saving time.  Equivalent to "Greenwich Mean Time"

**Diary Platform Context**: All timestamps in the database and audit trail are stored in UTC (with the patient's timezone offset for ePROs) to ensure consistency across geographic regions and to support clinical trials with international sites.

**Display**: Timestamps are converted to user's local time zone for display in mobile app and Portal.

**Why UTC**: Eliminates ambiguity when patients travel, when daylight saving time changes occur, or when comparing data across time zones.

---

## Regulatory and Compliance Acronyms

### FDA (U.S. Food and Drug Administration)

**Definition**: United States federal agency responsible for protecting public health by regulating pharmaceuticals, medical devices, and clinical trials.

**Diary Platform Context**: When used in U.S. clinical trials, the Diary Platform must comply with FDA 21 CFR Part 11 requirements for electronic records and electronic signatures.

### 21 CFR Part 11

**Full Name**: Title 21 Code of Federal Regulations Part 11

**Definition**: FDA regulation establishing requirements for electronic records and electronic signatures in clinical trials to be considered trustworthy, reliable, and equivalent to paper records.

**Diary Platform Context**: Core compliance framework for clinical trial features. Requires audit trails, electronic signatures, validation, and access controls.

**See**: prd-clinical-trials.md (REQ-p00010) for compliance requirements

### EMA (European Medicines Agency)

**Definition**: European Union agency responsible for evaluating and supervising medicines, including clinical trial oversight.

**Diary Platform Context**: For EU clinical trials, the Diary Platform complies with EU Clinical Trial Regulation 536/2014 and EU GMP Annex 11.

### ICH (International Council for Harmonisation)

**Definition**: An organization that develops and promotes international standards for clinical trials to ensure consistent quality, safety, and efficacy of medicines worldwide.

**Key Guidelines**:
- **ICH E6(R2)**: Good Clinical Practice (GCP) - ethical and scientific quality standards
- **ICH E8**: General Considerations for Clinical Studies
- **Others**: Quality (Q), Safety (S), Efficacy (E), Multidisciplinary (M) guidelines

**Diary Platform Context**: The Diary Platform follows ICH guidelines, particularly E6(R2) for GCP compliance.

### ICH-GCP / ICH E6(R2) (Good Clinical Practice)

**Definition**: The foundational international ethical and scientific quality standard for designing, conducting, recording, and reporting clinical trials involving human subjects. ICH E6(R2) is the 2016 revision emphasizing risk-based monitoring and data integrity.

**Diary Platform Context**: The Diary Platform follows ICH-GCP guidelines, particularly for:
- Data integrity (ALCOA+ principles)
- Audit trails and traceability
- Source data verification
- Participant protection and informed consent

### HIPAA (Health Insurance Portability and Accountability Act)

**Definition**: United States federal law protecting the privacy and security of individuals' medical information.

**Diary Platform Context**: When U.S. patients use the Diary, PHI is protected according to HIPAA standards. Cure HHT Foundation (or other sponsors) acts as the covered entity.

**Key Requirement**: Business Associate Agreements (BAAs) with service providers (cloud hosting, etc.)

### GDPR (General Data Protection Regulation)

**Definition**: European Union regulation governing data protection and privacy for EU residents.

**Diary Platform Context**: EU patients have GDPR rights (access, rectification, erasure, portability) for their personal data. Clinical trial participation may limit some rights (e.g., right to erasure) for data integrity reasons.

**Key Distinction**: GDPR applies based on **patient location** (EU residents), not sponsor location.

### ALCOA+ Principles

**Full Name**: Attributable, Legible, Contemporaneous, Original, Accurate + Complete, Consistent, Enduring, Available

**Definition**: Data integrity principles required by regulatory authorities (FDA, EMA) for clinical trial records.

**Diary Platform Context**: Event Sourcing architecture directly implements ALCOA+ principles:
- **Attributable**: Every event includes user ID and timestamp
- **Legible**: All data stored in readable formats
- **Contemporaneous**: Events recorded immediately
- **Original**: Events never modified (append-only)
- **Accurate**: Validation enforced at entry
- **Complete**: Full audit trail preserved
- **Consistent**: Event Sourcing ensures consistency
- **Enduring**: Retention policies enforced
- **Available**: Query interfaces provide access

**See**: prd-clinical-trials.md (REQ-p00011) for ALCOA+ implementation

### AE (Adverse Event) / SAE (Serious Adverse Event)

**Definition**:
- **AE**: Any undesirable medical event occurring in a patient during a clinical trial, whether or not related to the investigational treatment
- **SAE**: A severe adverse event resulting in death, hospitalization, disability, or other serious outcomes

**Diary Platform Context**: While patients may note health changes in their diary entries, formal AE/SAE reporting is handled through the sponsor's EDC system and clinical trial protocols, not directly through the Diary Platform. Investigators may review diary entries for potential AEs during safety monitoring.

**Regulatory Requirement**: SAEs require expedited reporting (typically within 24 hours).

### IND (Investigational New Drug) / NDA (New Drug Application)

**Definition**:
- **IND**: Application to the FDA requesting permission to test a new drug in humans (before Phase I trials)
- **NDA**: Formal application to the FDA for approval to market a drug (after successful Phase III trials)

**Diary Platform Context**: Sponsors using the Diary for clinical trials submit ePRO data collected through the Diary as part of their IND (during trials) and NDA (for approval) submissions.

### IMP (Investigational Medicinal Product)

**Definition**: The drug, biological product, or device being tested in the clinical trial.

**Diary Platform Context**: Patients using the Diary may be taking an IMP as part of a clinical trial. Diary entries help assess the IMP's efficacy (e.g., reduced nosebleed frequency) and potential side effects.

### PI (Principal Investigator) / Sub-I (Sub-Investigator)

**Definition**:
- **PI**: The lead physician at a clinical trial site responsible for the conduct of the trial
- **Sub-I**: Physicians or other qualified staff assisting the PI at the site

**Diary Platform Context**: PIs and Sub-Is have **Investigator** role access in the Portal, allowing them to enroll patients, monitor diary entry compliance, and review patient data for their assigned sites.

**See**: prd-security-RBAC.md for Investigator role permissions

### CRO (Contract Research Organization)

**Definition**: An organization hired by a sponsor to manage aspects of a clinical trial, including site monitoring, data management, and regulatory compliance.

**Diary Platform Context**: A CRO may be granted access to the sponsor's Portal to monitor trial progress, review patient diary data, and ensure site compliance. CRO staff would typically have **Auditor** or **Analyst** roles.

### CRA (Clinical Research Associate)

**Definition**: Staff employed by the sponsor or CRO who monitor trial sites to ensure compliance with GCP, the protocol, and regulatory requirements. CRAs perform source data verification (SDV).

**Diary Platform Context**: CRAs may use the Portal to verify that patient diary entries (ePRO data) are consistent with source documentation and that sites are following proper enrollment and monitoring procedures.

**Portal Access**: CRAs typically have **Auditor** role (read-only) to review data without modifying it.

### SDV (Source Data Verification)

**Definition**: The process of verifying that data in the trial database (EDC/eCRF) matches the original source documents to ensure accuracy and integrity.

**Diary Platform Context**: In traditional trials, CRAs perform SDV by comparing eCRF data to paper source documents. For the Diary Platform:
- The Diary entries **are** the source (eSource)—no paper transcription occurs
- SDV focuses on verifying audit trails, timestamps, and data integrity
- CRAs verify that the electronic records meet regulatory standards (21 CFR Part 11)

### IRB (Institutional Review Board) / IEC (Independent Ethics Committee)

**Definition**:
- **IRB**: U.S. independent ethics committee that reviews and approves clinical trial protocols and informed consent forms
- **IEC**: International equivalent of IRB

**Diary Platform Context**: Before a sponsor can use the Diary Platform at a clinical trial site, the IRB/IEC must review and approve:
- The study protocol (including ePRO data collection via the Diary)
- Informed consent forms explaining Diary usage
- Data privacy and security measures

**Ongoing Oversight**: IRB/IEC must approve any changes to Diary data collection procedures.

### ICF (Informed Consent Form)

**Definition**: The signed document where a patient agrees to participate in a clinical trial after understanding the risks, benefits, data usage, and privacy implications.

**Diary Platform Context**: Patients must sign an ICF that includes:
- How the Diary will be used to collect ePRO data
- What data will be shared with the sponsor
- Privacy protections and data retention
- Right to withdraw (with limitations for data already collected)

**Electronic Signatures**: The Diary Platform supports electronic ICF signatures compliant with 21 CFR Part 11.

### CDISC (Clinical Data Interchange Standards Consortium)

**Definition**: An organization that develops international data standards to facilitate exchange and submission of clinical trial data.

**Key Standards**:
- **CDASH**: Clinical Data Acquisition Standards Harmonization (data collection)
- **SDTM**: Study Data Tabulation Model (data submission format)
- **ADaM**: Analysis Data Model (analysis datasets)

**Diary Platform Context**: ePRO data collected through the Diary can be exported in CDISC-compliant formats (e.g., SDTM) for regulatory submission or integration with sponsor EDC systems.

**Future Enhancement**: The Diary Platform roadmap includes native CDISC CDASH mapping for common ePRO data elements.

### CTMS (Clinical Trial Management System)

**Definition**: Software used to manage the operational aspects of a clinical trial, including site management, patient recruitment tracking, document management, and regulatory compliance.

**Diary Platform Context**: The Diary Platform is **not** a CTMS—it is specifically an ePRO data collection system. Sponsors typically use a separate CTMS (e.g., Veeva CTMS, Oracle Siebel CTMS) alongside the Diary Platform.

**Integration Potential**: Future versions may integrate with CTMS systems to sync patient enrollment and site information.

---

## Sponsor-Specific Terminology

### Cure HHT Foundation Context

**Disease**: Hereditary Hemorrhagic Telangiectasia (HHT)

**Primary Health Observation**: Epistaxis events (nosebleeds)

**Sponsor-Specific Terms**:
- "Nosebleed Diary" - Patient-friendly name for the Diary
- "Epistaxis events" - Clinical term for nosebleeds
- "HHT-specific assessments" - Quality of life questionnaires, severity scores

**Note**: Terminology may vary for other sponsors. The core system uses generic terms (Diary, health observation) that adapt to sponsor-specific branding.

---

## Usage Guidelines by Audience

### Patient-Facing Communication

**Use**:
- Diary, the app
- Diary entry
- Your health observations
- Nosebleed (or other specific health event terms)
- Your doctor, your care team

**Avoid**:
- ePRO, eCRF, eSource
- Event Store, Record State
- Clinical trial jargon (unless patient is in a trial)
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
- **prd-security.md** - Authentication, authorization, role definitions
- **prd-security-RBAC.md** - Role-based access control specifications
- **prd-security-RLS.md** - Row-level security policies
- **prd-clinical-trials.md** - Regulatory compliance requirements (clinical trial feature)

---

## Document Control

**Version History**:
- Version 1.0 (2025-12-02) - Initial glossary creation

**Review Schedule**: Review quarterly and update when new terminology is introduced

**Approval**: This glossary establishes canonical terminology for all spec/ files and project documentation.
