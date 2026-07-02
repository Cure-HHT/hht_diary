<!-- markdownlint-disable MD050 -->
<!-- This file is the seed glossary. All defined terms use **term**
     emphasis; external standards are marked with the `: Reference`
     sentinel keyword (see governance/glossary-example.md). -->

# System Glossary

This file is the **System Glossary** — every domain-specific term used in
a normative requirement MUST appear here with a single, canonical
definition. Authors mark all defined terms in requirement text using
`**term**`. Terms whose authoritative definition lives in an external
standard are flagged inside the glossary entry with the `: Reference`
sentinel keyword, not a distinct emphasis form.

For order of precedence between this glossary and external Reference
Documents, see `governance/glossary-precedence.md`. For the syntax of an
individual glossary entry, see `governance/glossary-example.md`.
Authoring rules for glossary-term enforcement live in
`governance/style-guide.md` (REQ-DIARY-o00002 and REQ-DIARY-o00005-C).

## Conventions

- An assertion that uses a domain-specific term unbolded triggers an
  automated health-check failure (`governance/style-guide.md` REQ-DIARY-o00002-B).
- Any acronym used within a requirements document SHALL be a defined
  term in this glossary (`governance/style-guide.md` REQ-DIARY-o00005-C).
- Terms are listed alphabetically.
- A term that exists in a Reference Document SHALL be defined here as a
  Reference Term that points at the external source (see the
  `Email Address` example in `governance/glossary-example.md`).
- Entries that exist purely as reference material (project context,
  preferred-term guidance, deprecated-term notes) are flagged with
  `: Indexed: false` to keep the auto-generated term index focused on
  terms that appear in normative requirement text.
- Within a single entry, each `:` line is a separate paragraph of the
  definition body or a recognized metadata field (`Collection:`,
  `Indexed:`, `Reference`, `Title:`, `Version:`, `Effective Date:`,
  `URL:`, `Reference Term:`, `Reference Source:`). Inline labels such as
  `Usage Context:`, `See:`, and `Avoid:` are plain text in the
  definition body.

## Terms

ALCOA+ Principles
: Data integrity standards for electronic health records, widely adopted
  in both clinical and non-clinical contexts. The acronym expands to:
  Attributable, Legible, Contemporaneous, Original, Accurate, plus
  Complete, Consistent, Enduring, and Available.
: Diary Platform Implementation: Event Sourcing architecture directly
  implements ALCOA+ principles — every event includes user ID and
  timestamp (Attributable); data is stored in readable formats
  (Legible); events are recorded immediately (Contemporaneous); events
  are never modified (Original); validation is enforced at entry
  (Accurate); the full audit trail is preserved (Complete); Event
  Sourcing ensures chronological ordering (Consistent); retention
  policies are enforced (Enduring); query interfaces provide access
  (Available).
: Clinical Trial Context: Required by FDA and EMA for clinical trial
  records.
: See: ALCOA+ Data Integrity Principles,
  base-compliance-data-integrity.md.
: Indexed: false

AE / SAE (Adverse Event / Serious Adverse Event)
: AE: any undesirable medical event occurring in a patient during a
  clinical trial, whether or not related to the investigational
  treatment. SAE: a severe adverse event resulting in death,
  hospitalization, disability, or other serious outcomes. Formal AE/SAE
  reporting is handled through the sponsor's EDC system, not directly
  through the Diary Platform. SAEs require expedited reporting (typically
  within 24 hours).
: Indexed: false

Admin
: A staff member with privileges to create and manage User Accounts,
  configure sites, and manage system settings. In clinical trial
  deployments, the Admin is typically a sponsor employee scoped to one
  sponsor's data.
: Scope: sponsor-wide access (all sites within one sponsor) in clinical
  trial context; organization-wide in non-CT deployments.
: Avoid: "Sponsor admin" (redundant in CT context); "super admin" (no
  such role).
: See: Administrator Access with Audit Trail.
: Indexed: false

Analyst
: A researcher or data scientist with read-only access to data for
  analysis and reporting. Typically scoped to specific sites (may be
  sponsor-wide depending on assignment). Focused on data analysis, not
  compliance auditing.
: See: Analyst Read-Only Access.
: Indexed: false

Audit Trail
: A computer-generated, time-stamped record that captures the who, what,
  when, and why of every modification to an Electronic Record, satisfying
  21 CFR Part 11 §11.10(e).
: Attributes: who (user identification), what (change description), when
  (timestamp in UTC), why (reason for change, if applicable), where
  (device/platform information).
: Usage Context: compliance documentation, audit procedures, data
  integrity requirements.
: Clinical Trial Context: required by FDA 21 CFR Part 11, EU Annex 11,
  and ICH-GCP guidelines for regulatory compliance. Implemented using
  the Event Store architecture (technical term) to create an Audit Trail
  (regulatory term).
: See: Immutable Audit Trail via Event Sourcing, Comprehensive Audit Trail, base-compliance-data-integrity.md.

Auditor
: An independent compliance reviewer with read-only access to all data
  and audit trails for regulatory compliance verification. Has full
  read-only access across all sites within a sponsor. Auditors can view
  but NEVER modify data.
: See: Auditor Compliance Access.
: Indexed: false

Caregiver
: A family member or trusted individual who has been granted delegated
  access to view or assist with a user's diary entries. Caregivers act
  on behalf of the user and are subject to the same privacy protections.
: Usage Context: personal health tracking context where the user shares
  diary access with someone who helps manage their health.
: Indexed: false

CDISC (Clinical Data Interchange Standards Consortium)
: Organization developing international data standards for clinical trial
  data exchange. Key standards: CDASH (data collection), SDTM (data
  submission format), ADaM (analysis datasets). Diary ePRO data can be
  exported in CDISC-compliant formats for regulatory submission.
: Indexed: false

CDISC Glossary
: Reference
: Title: Clinical Data Interchange Standards Consortium — Glossary
: URL: <https://www.cdisc.org/standards/glossary>

CQRS (Command Query Responsibility Segregation)
: An architectural pattern separating write operations (commands that
  create events) from read operations (queries that read current state).
: Implementation in Diary Platform: the write side creates events in the
  Event Store; the read side reads optimized Record State tables; Event
  Store and Record State are separate but synchronized.
: Benefits: optimizes audit trail integrity (write side) and query
  performance (read side).
: Usage Context: technical architecture documentation.
: See: base-audit-trail.md.
: Indexed: false

CRA (Clinical Research Associate)
: Staff employed by the sponsor or CRO who monitor trial sites to ensure
  compliance with GCP, the protocol, and regulatory requirements. CRAs
  perform source data verification (SDV). In the Portal, CRAs typically
  have the Auditor role (read-only).
: Indexed: false

CRF / eCRF (Case Report Form / Electronic Case Report Form)
: The primary tool used by investigators or site staff to record clinical
  trial data about a patient. Key distinction: CRF/eCRF data is entered
  by clinical trial staff, not by patients. The Diary Platform does not
  implement traditional eCRFs. Patient diary entries (ePRO data) may be
  exported to feed into a sponsor's EDC system.
: Avoid: do not use "eCRF" to refer to patient diary entries.
: Indexed: false

CRO (Contract Research Organization)
: Organization hired by a sponsor to manage aspects of a clinical trial.
  CRO staff typically have Auditor or Analyst roles in the Portal.
: Indexed: false

CTMS (Clinical Trial Management System)
: Software for managing operational aspects of a clinical trial. The
  Diary Platform is not a CTMS — it is specifically a health diary /
  ePRO data collection system. Sponsors typically use a separate CTMS
  alongside the Diary Platform.
: Indexed: false

Database
: The PostgreSQL database (hosted on Cloud SQL) that stores all diary
  entries, audit trails, User Accounts, and configuration.
: Architecture: Event Store (immutable audit trail); Record State
  (current values, derived from events); Row-Level Security policies for
  access control.
: Usage Context: use when discussing data storage, schema, or database
  architecture.
: Clinical Trial Context: may be referred to as "Clinical Trial
  Database" when emphasizing regulatory compliance features.
: See: Clinical Data Storage System, Separate
  Database Per Sponsor, base-compliant-diary-platform.md.

De-identified Data
: Health data with all personally identifiable information (name, email,
  date of birth, account identifiers) removed, leaving only a
  participant ID and health observations.
: Purpose: enables research analysis and data sharing while protecting
  user privacy.
: Clinical Trial Context: de-identified data can be shared with research
  partners; identified data requires explicit consent. Subject to GDPR
  and HIPAA requirements.
: See: Separation of Identity and Clinical Data.

Developer Admin
: A system administrator with infrastructure-level access for deployment,
  monitoring, and maintenance. Scope is cross-sponsor system
  administration (database backups, infrastructure monitoring).
: Data Access: Developer Admins have NO routine access to patient data.
  A documented break-glass procedure exists for emergency situations
  only, with full audit trail logging of all access.
: Context: internal operations only, not accessible to sponsors or
  clinical trial users.
: See: docs/security-secret-management.md for developer admin procedures.
: Indexed: false

Diary
: The iOS and Android smartphone application that individuals use to
  record daily health observations. The primary user-facing term for the
  mobile application.
: Preferred Terms: "Diary" (primary term, patient-friendly, simple and
  clear); "Mobile Diary" (when distinguishing from the web Portal);
  "Diary app" (informal, acceptable when context is clear).
: Usage Context: user-facing — "Diary" or "the app"; formal
  documentation — "Diary mobile application"; technical documentation —
  "Mobile Diary" or "Diary app".
: Clinical Trial Context: may use "Clinical Diary" when emphasizing
  regulatory compliance.
: Avoid: "ePRO application" (too technical, confusing to users); "eCRF"
  (refers to a different concept in clinical trials); "eSource" (refers
  to the complete platform, not just the mobile app); "Clinical Diary"
  as the primary name (clinical trials are a feature, not the identity).
: See: Diary Mobile Application, prd-mobile-app.md.

Diary Entry
: A single user-reported record of a health event (e.g., nosebleed
  episode) including time, severity, duration, and other relevant
  details.
: Preferred Terms: "Diary Entry" (standard term); "Health Observation"
  (more formal context); "Entry" (short form when context is clear).
: Usage Context: use "diary entry" in user-facing communication and
  general documentation.
: Clinical Trial Context: when used in clinical trials, diary entries
  may capture protocol-specified data elements and serve as ePRO data.
: Avoid: "Event" (too generic); "Record" (too technical); "Data point"
  (depersonalizing).
: See: HHT Epistaxis Data Capture Standard.

Diary Platform
: The complete system comprising all software, infrastructure, and data
  storage components that enable individuals to record and manage
  personal health observations, with optional clinical trial support
  features.
: Components: Diary (mobile application); Sponsor Portal; Database;
  supporting infrastructure and APIs.
: Primary Purpose: personal health diary for tracking daily health
  observations.
: Secondary Features: clinical trial support, data sharing with
  healthcare providers, research contribution.
: Usage Context: use when referring to the entire system architecture or
  in formal documentation.
: Avoid: "Clinical Diary Platform" (implies clinical trials are
  primary); "eSource system"; "ePRO platform" (use only in
  sponsor-specific external documentation).
: See: Clinical Trial Compliant Diary Platform.

eCOA (Electronic Clinical Outcome Assessment)
: Umbrella term for electronic capture of clinical outcomes: ePRO
  (patient reports), ClinRO (clinician assessment), ObsRO
  (observer/caregiver reports), PerfO (performance measurements). The
  Diary is specifically an ePRO tool.
: Indexed: false

EDC (Electronic Data Capture)
: Software systems used to collect, manage, and store clinical trial
  data electronically, typically including eCRFs. The Diary Platform is
  not a full EDC system — it provides ePRO data that may be exported to
  a sponsor's EDC system (e.g., Medidata Rave, Oracle InForm).
: Indexed: false

Electronic Record
: Any combination of text, graphics, data, or other digital information
  created, modified, maintained, or distributed by the platform that is
  subject to 21 CFR Part 11.

Electronic Signature
: A computer-implemented signing event that, under 21 CFR Part 11 §11.50,
  is legally equivalent to a handwritten signature.
: Diary Platform Implementation: the automatic attribution of a data
  entry or change to a specific User Account with timestamp and device
  information. Every diary entry and data modification is automatically
  signed with user account ID, timestamp (UTC), device information, and
  a cryptographic hash to prevent tampering. Users do not manually
  "sign" entries — the system automatically creates legally binding
  signatures.
: Usage Context: all diary entries (personal health tracking and
  clinical trial) are automatically attributed to the user who created
  them.
: See: FDA 21 CFR Part 11 Compliance,
  base-compliance-data-integrity.md.

EMA (European Medicines Agency)
: European Union agency responsible for evaluating and supervising
  medicines. For EU clinical trials, the Diary Platform complies with EU
  Clinical Trial Regulation 536/2014 and EU GMP Annex 11.
: Indexed: false

ePRO (Electronic Patient-Reported Outcomes)
: Electronic collection of health information reported directly by the
  patient, without interpretation by clinicians. The Diary functions as
  an ePRO tool when used in clinical trials.
: Avoid: while technically accurate, avoid "ePRO" in user-facing
  communication. Use "Diary" instead.
: See: Diary Mobile Application.
: Indexed: false

eSource
: The Diary Platform as a whole, when used as the original electronic
  source of patient-reported data in a clinical trial (as opposed to
  transcribing from paper diaries).
: Usage Context: regulatory submissions, protocol documentation, when
  emphasizing the system is the primary data source in a clinical trial
  context.
: Notes: "eSource" is a regulatory/clinical trial term, not the system's
  primary identity. Refers to the complete platform (Diary + Database +
  Portal), not just the mobile app. Use only when discussing clinical
  trial regulatory compliance.
: Regulatory Basis: FDA guidance on electronic source documentation.
: See: FDA 21 CFR Part 11 Compliance.

ESS (Epistaxis Severity Score)
: Standardized clinical assessment tool measuring the severity and
  impact of nosebleeds in HHT patients. Calculated from patient-reported
  diary data. Specific to HHT clinical trials.
: Indexed: false

Event Sourcing
: An architectural pattern where all changes to application state are
  stored as a sequence of immutable events, rather than overwriting data
  in place.
: Benefits: complete history and timeline reconstruction; no data loss;
  full audit trail for personal health records; supports clinical trial
  regulatory compliance (FDA 21 CFR Part 11) when needed.
: Technical Details: every change (create, update, delete) appends an
  event to the Event Store. Current state is derived by replaying
  events.
: Usage Context: technical architecture and developer documentation.
: See: Immutable Audit Trail via Event Sourcing, Event Sourcing Client Interface, base-audit-trail.md.

Event Store
: The immutable log of all changes to diary entries and system data,
  implementing the Event Sourcing architectural pattern. Every create,
  update, or delete operation is stored as an event that is never
  modified or deleted (append-only). Current state is derived by
  replaying events, providing a complete change history.
: Usage Context: developer and architecture documentation.
: Clinical Trial Context: the Event Store implements the Audit Trail
  required by FDA 21 CFR Part 11 and other regulations.
: See: Immutable Audit Trail via Event Sourcing, Event Sourcing Client Interface, base-audit-trail.md.

FDA (U.S. Food and Drug Administration)
: United States federal agency responsible for regulating
  pharmaceuticals, medical devices, and clinical trials.
: See: FDA 21 CFR Part 11 Compliance.
: Indexed: false

FDA 21 CFR Part 11
: U.S. Food and Drug Administration regulation (Title 21 Code of Federal
  Regulations Part 11) establishing requirements for electronic records
  and electronic signatures to be considered trustworthy, reliable, and
  equivalent to paper records.
: Key Requirements: audit trails for all data changes; electronic
  signatures with cryptographic integrity; controlled system access;
  data validation and integrity checks; records retention for
  regulatory-mandated periods.
: Diary Platform Context: core compliance framework for clinical trial
  features.
: Usage Context: regulatory submissions, compliance documentation.
: See: FDA 21 CFR Part 11 Compliance,
  base-compliance-data-integrity.md.

FDA 21 CFR Part 11 (Regulation)
: Reference
: Title: Electronic Records; Electronic Signatures
: Version: 21 CFR Part 11 (current Code of Federal Regulations)
: URL: <https://www.fda.gov/regulatory-information/search-fda-guidance-documents/electronic-records-electronic-signatures-scope-and-application>

GCP (Good Clinical Practice)
: International ethical and scientific quality standards governing
  clinical trial conduct, including data collection, management, and
  participant protection. Primary guideline: ICH E6(R2).
: Note: "GCP" also stands for "Google Cloud Platform" — context
  determines meaning.
: Indexed: false

GDPR (General Data Protection Regulation)
: European Union regulation governing data protection and privacy for EU
  residents. EU users have GDPR rights (access, rectification, erasure,
  portability). Clinical trial participation may limit some rights for
  data integrity reasons. Applies based on user location, not sponsor
  location.
: See: GDPR Compliance, GDPR Data Portability.
: Indexed: false

Google Cloud Platform (GCP)
: Cloud infrastructure provider hosting the Diary Platform: Cloud SQL
  (PostgreSQL database), Identity Platform (authentication), Cloud
  Storage (backups), per-sponsor GCP projects for multi-sponsor
  isolation.
: Note: in clinical trial contexts, "GCP" typically refers to Good
  Clinical Practice.
: Indexed: false

Healthcare Provider
: A licensed healthcare professional (physician, nurse, specialist) who
  reviews a user's diary data to support clinical care. The healthcare
  provider typically accesses data through the Portal with the user's
  consent.
: Usage Context: personal health tracking context where the Diary data
  is shared with a care team.
: Distinction from Investigator: a Healthcare Provider reviews diary
  data for clinical care purposes. An Investigator reviews diary data as
  part of a clinical trial protocol.
: See: Sponsor Portal Application.
: Indexed: false

HHT (Hereditary Hemorrhagic Telangiectasia)
: Genetic disorder causing abnormal blood vessel formation, leading to
  frequent nosebleeds and other complications. The Diary Platform was
  initially developed for HHT patients but supports any health tracking
  use case. Current sponsor: Cure HHT Foundation.
: Indexed: false

HIPAA (Health Insurance Portability and Accountability Act)
: United States federal law protecting the privacy and security of
  individuals' medical information. Key requirement: Business Associate
  Agreements (BAAs) with service providers.
: See: Privacy Policy and Regulatory Compliance
  Documentation.
: Indexed: false

ICF (Informed Consent Form)
: Signed document where a patient agrees to participate in a clinical
  trial. Must include how the Diary will be used, what data will be
  shared, privacy protections, and right to withdraw. The Diary Platform
  supports electronic ICF signatures compliant with 21 CFR Part 11.
: Indexed: false

ICH (International Council for Harmonisation)
: Organization developing international standards for clinical trials.
  Key guidelines: ICH E6(R2) (Good Clinical Practice), ICH E8 (General
  Considerations for Clinical Studies), plus Quality (Q), Safety (S),
  Efficacy (E), and Multidisciplinary (M) guidelines.
: Indexed: false

ICH-GCP / ICH E6(R2)
: The foundational international ethical and scientific quality standard
  for clinical trials involving human subjects. The 2016 revision
  emphasizes risk-based monitoring and data integrity. The Diary
  Platform follows ICH-GCP guidelines for data integrity (ALCOA+), audit
  trails, source data verification, and participant protection.
: See: ALCOA+ Data Integrity Principles.
: Indexed: false

ICH E6(R2) (Guideline)
: Reference
: Title: Integrated Addendum to ICH E6(R1) — Guideline for Good Clinical Practice
: Version: ICH E6(R2), Step 4, 2016-11-09
: URL: <https://www.ich.org/page/efficacy-guidelines>

ISO/IEC 24760-1
: Reference
: Title: IT Security and Privacy — A framework for identity management
: Version: ISO/IEC 24760-1:2019
: URL: <https://www.iso.org/standard/77582.html>

IMP (Investigational Medicinal Product)
: The drug, biological product, or device being tested in a clinical
  trial. Diary entries help assess the IMP's efficacy and potential side
  effects.
: Indexed: false

IND / NDA (Investigational New Drug / New Drug Application)
: IND: Application to the FDA to test a new drug in humans. NDA:
  Application for FDA approval to market a drug. Sponsors submit Diary
  ePRO data as part of IND (during trials) and NDA (for approval)
  submissions.
: Indexed: false

Investigator
: A clinical-trial role authorized by the Sponsor to view patient data,
  review safety triggers, and unlock individual questionnaires within
  the Investigator's assigned site. A licensed clinical researcher
  responsible for enrolling patients, managing a clinical trial site,
  and ensuring protocol compliance.
: Responsibilities: enroll patients using linking codes; monitor patient
  engagement and data quality; send questionnaires and reminders to
  patients; review patient diary data for protocol compliance.
: Access: site-specific data only (via Row-Level Security).
: Avoid: "Site staff"; "clinical user"; "researcher" (be specific).
: See: Investigator Site-Scoped Access, Investigator Annotation Restrictions.

IRB / IEC (Institutional Review Board / Independent Ethics Committee)
: IRB (U.S.) / IEC (international): independent ethics committee that
  reviews and approves clinical trial protocols, informed consent forms,
  and data privacy measures before a sponsor can use the Diary Platform
  at a trial site. Ongoing approval is required for any changes to Diary
  data collection procedures.
: Indexed: false

Linking Code
: A unique, cryptographically random 10-character code used to securely
  connect a user's mobile Diary to a service. In clinical trial
  deployments, linking codes connect a user's device to their enrollment
  record at a trial site. In non-clinical-trial contexts, a similar
  mechanism could connect the Diary to a backup or data-sharing service.
: Format: 10 characters, alphanumeric, case-insensitive.
: Purpose: enables secure device connection without transmitting PII or
  creating accounts before the link is established.
: Usage Context: patient enrollment workflow (clinical trials), device
  provisioning.
: See: Linking Code Lifecycle Management, Linking Code Validation.

Multi-Sponsor Isolation
: The architectural pattern ensuring complete data separation between
  different organizations (sponsors) using the Diary Platform for
  clinical trials.
: Implementation: separate Cloud SQL database per sponsor; separate GCP
  project per sponsor; separate web portal per sponsor (sponsor-specific
  subdomain); shared mobile Diary app with automatic sponsor detection.
: Purpose: enables a single codebase to serve multiple sponsors while
  maintaining regulatory compliance and data privacy.
: Context: this is a clinical trial feature. Personal health tracking
  deployments may not use multi-sponsor architecture.
: See: Complete Multi-Sponsor Data Separation, Single Mobile App for All Sponsors,
  prd-architecture-multi-sponsor.md.

NIST SP 800-63
: Reference
: Title: Digital Identity Guidelines
: Version: NIST Special Publication 800-63-3 (with revisions 800-63A/B/C)
: URL: <https://pages.nist.gov/800-63-3/>

NOSE-HHT (Nasal Outcome Score for Epistaxis in HHT)
: Validated patient-reported outcome measure for assessing nosebleed
  impact in HHT patients. May be collected as a questionnaire within the
  Diary app during clinical trials. Specific to HHT clinical trials.
: Indexed: false

Offline-First
: An architectural approach where the mobile Diary application functions
  fully without internet connection, storing data locally and
  synchronizing to the cloud when connectivity is available.
: Benefits: users can make diary entries anywhere, anytime; no data loss
  if internet unavailable; reduces dependency on network reliability;
  improves user experience and app responsiveness.
: Technical Implementation: local sembast NoSQL JSON database on device,
  background sync service.
: See: Offline-First Data Entry, Offline Event
  Queue with Automatic Synchronization, dev-app.md.

Patient
: A human subject enrolled in a clinical trial who interacts with the
  platform via the diary application to record protocol-defined
  Electronic Records.
: Preferred Terms: "Patient" (when emphasizing health-tracking context —
  empathetic, widely understood); "Study Participant" (when the
  individual is enrolled in a clinical trial — formal clinical trial
  context).
: Usage Context: personal health tracking — "User" or "Patient";
  clinical trial context — "Study Participant" or "Patient"; formal
  regulatory submissions — "Study Participant" (when required by
  convention).
: Key Distinction: not all Diary users are in clinical trials. Many use
  it purely for personal health tracking or to share with their
  healthcare providers.
: Avoid: "Subject" (outdated, depersonalizing).

PHI (Protected Health Information)
: Any individually identifiable health information protected under HIPAA
  (name, dates, contact information, medical record numbers, health data
  linked to an individual). PHI is encrypted at rest and in transit,
  subject to strict access controls via RBAC and RLS policies.
: See: Separation of Identity and Clinical Data,
  prd-security-data-classification.md.
: Indexed: false

PI / Sub-I (Principal Investigator / Sub-Investigator)
: PI: lead physician at a clinical trial site. Sub-I: physicians or
  staff assisting the PI. Both have Investigator role access in the
  Portal.
: See: Investigator Site-Scoped Access.
: Indexed: false

PII (Personally Identifiable Information)
: Information that can identify, contact, or locate a specific
  individual, protected under GDPR and other privacy regulations.
  Overlap with PHI: all PHI is PII, but not all PII is PHI.
: See: prd-security-data-classification.md.
: Indexed: false

PRO (Patient-Reported Outcome)
: Any report of a patient's health condition that comes directly from
  the patient, without interpretation by a clinician. Diary entries are
  PROs. When collected electronically via the Diary app, they become
  ePROs.
: Indexed: false

RBAC (Role-Based Access Control)
: Access control paradigm where permissions are assigned to roles (User,
  Investigator, Admin, etc.) rather than individual users.
: Roles: User, Healthcare Provider, Caregiver, Investigator, Admin,
  Auditor, Analyst, Sponsor, Developer Admin.
: Usage Context: security architecture, access control documentation.
: See: Role-Based Access Control, prd-rbac.md.

Record State
: The current values of diary entries and other data, derived from the
  Event Store by replaying all events. In Event Sourcing architecture,
  this is the "read model" (also known as a Materialized View in
  database terminology) optimized for queries.
: Usage Context: developer and technical architecture documentation.
: Contrast: "Event Store" contains the history; "Record State" contains
  current values.
: See: Type-Safe Materialized View Queries,
  base-audit-trail.md.

Role
: A named set of authorities granted to a User Account that determines
  which Electronic Records the account may read, write, or modify.
: Diary Platform Roles: User, Healthcare Provider, Caregiver,
  Investigator, Admin, Auditor, Analyst, Sponsor, Developer Admin.
: See: Role-Based Access Control, prd-rbac.md.

SDV (Source Data Verification)
: Process of verifying that data in the trial database matches original
  source documents. For the Diary Platform, diary entries are the source
  (eSource) — no paper transcription occurs. SDV focuses on verifying
  audit trails, timestamps, and data integrity.
: Indexed: false

Site
: A physical location (hospital, clinic, research center) where clinical
  trial activities are conducted. Each site has one or more
  investigators. This is a clinical-trial-specific concept.
: Usage Context: sites are organizational units within a sponsor's
  clinical trial. Patients are enrolled at a specific site by an
  investigator at that site.
: See: Multi-Site Support Per Sponsor.

Sponsor
: The regulated entity that holds the IND or IDE and contracts the
  vendor to operate the platform for a specific clinical trial. An
  organization (pharmaceutical company, foundation, research
  institution) that uses the Diary Platform to support a clinical trial.
: Multi-Sponsor Context: the Diary Platform supports multiple sponsors
  simultaneously, with complete data isolation between sponsors
  (separate databases, portals, and configurations).
: Examples: Cure HHT Foundation (current), pharmaceutical companies
  developing HHT treatments.
: Key Distinction: sponsors are organizations using the clinical trial
  features of the Diary Platform. Not all Diary Platform deployments
  involve sponsors — some may be purely personal health tracking.
: See: Complete Multi-Sponsor Data Separation,
  prd-architecture-multi-sponsor.md.

Sponsor Portal
: The web application used by Investigators and Sponsor staff to
  administer trials, review patient data, and manage User Accounts. The
  web-based application used by healthcare providers, administrators,
  and (in clinical trial contexts) investigators, sponsors, auditors,
  and analysts to review user data, manage accounts, and administer
  features.
: Preferred Terms: "Sponsor Portal" (primary term, used when
  distinguishing from mobile Diary); "Portal" (short form when context
  is clear).
: Usage Context: use to distinguish from the mobile Diary application.
: Components: User Data Review; Admin Dashboard; Healthcare Provider
  Dashboard; Investigator Dashboard (clinical trial feature); Auditor
  Dashboard (clinical trial feature); Analyst Dashboard; Sponsor
  Configuration (clinical trial feature).
: Note: Portal serves both personal health tracking use cases (e.g.,
  healthcare provider reviewing a user's diary) and clinical trial use
  cases (investigator monitoring trial participants).
: Avoid: "Admin app"; "web app" (too generic); "Clinical Trial Portal"
  as the primary name.
: See: Sponsor Portal Application, prd-portal-auth.md.

User
: Any individual who uses the Diary Platform. The default term for
  someone using the Diary for personal health tracking outside of a
  clinical trial.
: Usage Context: personal health tracking — "User" is the standard term;
  clinical trial contexts — use specific role names instead (Study
  Participant, Investigator, etc.) since "User" is ambiguous when
  multiple roles exist; technical documentation — acceptable as a
  generic term when role is irrelevant.
: Note: "User" is acceptable in general documentation. In clinical trial
  contexts, always prefer specific role names to avoid ambiguity.

User Account
: The platform's representation of an individual authorized to interact
  with the system, identified by a unique Email Address and bound to one
  or more Roles.

UTC (Coordinated Universal Time)
: Primary time standard used worldwide, not affected by time zones or
  daylight saving time. All database and audit trail timestamps are
  stored in UTC (with the patient's timezone offset for ePROs).
  Displayed in the user's local time zone in the Diary app and Portal.
: Indexed: false

## External References

The Reference Documents whose definitions an entry in this glossary may
cite (via the `: Reference Source:` field) and the precedence rules that
resolve conflicts between definitions are listed in
`governance/glossary-precedence.md`. Individual reference entries (with
title, version, effective date, and URL) follow the format demonstrated
in `governance/glossary-example.md`.

## Deprecated and Avoided Terms

These terms are NOT canonical and SHOULD NOT appear in normative
requirement text. They are listed here so reviewers know to flag them
and so authors know the preferred replacement.

- "ePRO" — technical jargon; use **Diary**. May be retained in
  sponsor-specific external documentation when required for clinical
  trial context.
- "eCRF" — in traditional clinical trials, eCRF refers to forms filled
  out by investigators, NOT patients. Using eCRF for patient diary
  entries creates confusion. Use **Diary Entry** or **Health
  Observation**.
- "Subject" — outdated, depersonalizing terminology from earlier
  clinical research practices. Use **User** (general), **Patient**
  (health context), or **Study Participant** (clinical trial context).
- "User" in clinical trial contexts (without qualifier) — ambiguous;
  could refer to patient, investigator, admin, auditor, or analyst. Use
  a specific role name.
- "App" without qualifier in formal docs — ambiguous; could refer to
  mobile Diary or web Portal. Use **Diary** for the mobile application,
  **Portal** for the web application.

## Sponsor-Specific Terminology

Sponsor deployments may layer their own preferred terminology on top of
the canonical terms above. Authors of sponsor-specific spec content
SHOULD document those deltas in the deployment's own spec directory and
SHOULD NOT alter the canonical entries here.

### Cure HHT Foundation Context

- Disease: Hereditary Hemorrhagic Telangiectasia (HHT)
- Primary Health Observation: Epistaxis events (nosebleeds)
- Sponsor-Specific Terms: "Nosebleed Diary" (user-friendly name for the
  Diary), "Epistaxis events" (clinical term for nosebleeds),
  "HHT-specific assessments" (quality-of-life questionnaires, severity
  scores).
