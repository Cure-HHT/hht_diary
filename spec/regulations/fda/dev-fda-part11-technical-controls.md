# REQ-d80011: ALCOA++ Data Integrity Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00010

## Rationale

ALCOA++ principles (Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available, Traceable) provide a comprehensive framework for data integrity. This requirement specifies the technical implementation of each principle.

## Assertions

A. The system SHALL record the identity of the person who created, modified, or deleted each data element.
   *Source: GCP Data - Consolidated Requirements, Req 3 (Attributable)*

B. The system SHALL store data in formats that are readable and interpretable throughout the retention period.
   *Source: GCP Data - Requirements, ALCOA++ Legible principle*

C. The system SHALL record the date and time of data capture at the point when the data is entered.
   *Source: GCP Data - Consolidated Requirements, Req 4 (Contemporaneous)*

D. The system SHALL preserve the original data as first captured and prevent unauthorized modification.
   *Source: GCP Data - Requirements, ALCOA++ Original principle*

E. The system SHALL implement validation checks to ensure data accuracy at the point of entry.
   *Source: GCP Data - Consolidated Requirements, Req 16 (Accurate)*

F. The system SHALL ensure all required data elements are captured and stored completely.
   *Source: GCP Data - Requirements, ALCOA++ Complete principle*

G. The system SHALL maintain data consistency across all views and reports of the same data.
   *Source: GCP Data - Requirements, ALCOA++ Consistent principle*

H. The system SHALL preserve data in a durable format for the required retention period.
   *Source: GCP Data - Requirements, ALCOA++ Enduring principle*

I. The system SHALL make data available and accessible to authorized users when needed.
   *Source: GCP Data - Requirements, ALCOA++ Available principle*

J. The system SHALL maintain traceability of data from source through all transformations and uses.
   *Source: GCP Data - Requirements, ALCOA++ Traceable principle*

*End* *ALCOA++ Data Integrity Implementation* | **Hash**: 9bbe74ec

---

# REQ-d80021: Electronic Signature Technical Controls

**Level**: Dev | **Status**: Draft | **Implements**: p00020

## Rationale

Electronic signatures require specific technical controls to ensure they are securely linked to records and cannot be repudiated. This requirement specifies the technical implementation of electronic signature controls.

## Assertions

A. The system SHALL ensure electronic signatures are linked to their respective electronic records to ensure signatures cannot be excised, copied, or otherwise transferred to falsify an electronic record.
   *Source: 21 CFR Part 11.70*

B. The system SHALL implement cryptographic binding between electronic signatures and signed records such that any alteration is detectable.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section III*

C. The system SHALL require re-authentication when an electronic signature is applied.
   *Source: 21 CFR Part 11.200(a)(1)(ii)*

D. The system SHALL ensure that when an identification code and password are used as signature components, the first signing in a continuous session requires both components.
   *Source: 21 CFR Part 11.200(a)(1)(i)*

E. The system SHALL ensure subsequent signings in the same continuous session require at least one signature component.
   *Source: 21 CFR Part 11.200(a)(1)(ii)*

F. The system SHALL time out inactive sessions and require re-authentication before additional signatures can be applied.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.200(a)(1)(ii)*

G. The system SHALL implement session timeout controls to ensure continuous system access does not extend beyond appropriate periods.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section III.5*

H. The system SHALL log all signature events including successful signatures, failed attempts, and signature component usage.
   *Source: 21 CFR Part 11.10(e)*

I. For biometric-based electronic signatures, the system SHALL be designed to ensure they cannot be used by anyone other than the genuine owner.
   *Source: 21 CFR Part 11.200(b)*

*End* *Electronic Signature Technical Controls* | **Hash**: dd16ae7a

---

# REQ-d80031: Audit Trail Technical Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p80030

## Rationale

Audit trails must be implemented with specific technical controls to ensure they are secure, immutable, and capture all required information. This requirement specifies the technical implementation details.

## Assertions

A. The system SHALL generate audit trail entries automatically without user intervention.
   *Source: 21 CFR Part 11.10(e) "computer-generated"*

B. The system SHALL timestamp audit trail entries using a reliable, synchronized time source.
   *Source: 21 CFR Part 11.10(e) "time-stamped"*

C. The system SHALL record the date and time of data entry contemporaneously with the action.
   *Source: GCP Data - Consolidated Requirements, Req 4*

D. The system SHALL capture the following for each audited event: user identity, action performed, affected record identifier, previous value (if applicable), new value (if applicable), timestamp, and reason for change (where required).
   *Source: GCP Data - Consolidated Requirements, Reqs 3-6*

E. The system SHALL store audit trail data in a manner that prevents modification, deletion, or disabling by any user including administrators.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, EMA Guideline Section 8.1*

F. The system SHALL maintain audit trail data separately from operational data to ensure independence.
   *Source: 21 CFR Part 11.10(e) "independently record"*

G. The system SHALL provide the capability to export audit trail data in human-readable and electronic formats for regulatory inspection.
   *Source: 21 CFR Part 11.10(e) "available for agency review and copying"*

H. The system SHALL audit all access to audit trail data itself.
   *Source: GCP Data - Consolidated Requirements, Req 23*

*End* *Audit Trail Technical Implementation* | **Hash**: 5e69b0c1

---

# REQ-d80041: Data Correction Technical Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00040

## Rationale

Data corrections must be implemented to preserve original values while allowing legitimate corrections. This requirement specifies the technical approach to data correction handling.

## Assertions

A. The system SHALL implement a version control mechanism that preserves all previous values of corrected data.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 5*

B. The system SHALL ensure any change or correction to a trial-related record does not obscure the original entry.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3) 4.9.3*

C. The system SHALL require entry of a reason code or free-text reason before accepting a data correction.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 6*

D. The system SHALL associate each correction with the authenticated identity of the user making the correction.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 3*

E. The system SHALL display the correction history including original value, all intermediate values, and current value.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, EMA Guideline Section 7.1*

F. The system SHALL prevent direct modification of data in the database; all changes must go through the application layer with audit trail capture.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 22*

G. The system SHALL differentiate between initial data entry and subsequent corrections in the audit trail.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3) 4.9.3*

*End* *Data Correction Technical Implementation* | **Hash**: 78ef7572

---

# REQ-d80051: Authentication and Authorization Controls

**Level**: Dev | **Status**: Draft | **Implements**: p00050

## Rationale

Authentication and authorization controls are fundamental to system security and data integrity. This requirement specifies the technical implementation of user authentication and access control mechanisms.

## Assertions

A. The system SHALL employ electronic signatures based on at least two distinct identification components such as an identification code and password.
   *Source: 21 CFR Part 11.200(a)(1)*

B. The system SHALL support contemporary authentication methods including multi-factor authentication.
   *Source: 2024 10 FDA Guidance Q&A Section III.4*

C. The system SHALL ensure identification codes and passwords are periodically checked, recalled, or revised.
   *Source: 21 CFR Part 11.300(b)*

D. The system SHALL lock accounts after a configurable number of failed authentication attempts.
   *Source: 21 CFR Part 11.300*

E. The system SHALL implement controls to prevent unauthorized system access attempts.
   *Source: GCP Data - Consolidated Requirements, Req 20*

F. The system SHALL enforce password expiration and prevent reuse of recent passwords.
   *Source: 21 CFR Part 11.300(b)*

G. The system SHALL limit system access to authorized individuals.
   *Source: 21 CFR Part 11.10(d)*

H. The system SHALL use authority checks to ensure only authorized individuals can use the system, electronically sign records, access operations, or input device.
   *Source: 21 CFR Part 11.10(g)*

I. The system SHALL implement role-based access control limiting user privileges to those required for their role.
   *Source: GCP Data - Consolidated Requirements, Req 19*

J. The system SHALL use secure, computer-generated, time-stamped audit trails to independently record the date and time of operator entries and actions.
   *Source: 21 CFR Part 11.10(e)*

K. The system SHALL log all authentication events including successful logins, failed attempts, and logouts.
   *Source: GCP Data - Consolidated Requirements, Req 24*

L. The system SHALL ensure all signings during a continuous period of controlled system access use at least one electronic signature component.
   *Source: 21 CFR Part 11.200(a)(1)(ii)*

M. The system SHALL terminate inactive sessions after a configurable timeout period.
   *Source: 2024 10 FDA Guidance Q&A Section III.5*

N. The system SHALL verify the identity of an individual before establishing, assigning, certifying, or sanctioning their electronic signature.
   *Source: 21 CFR Part 11.100(b)*

*End* *Authentication and Authorization Controls* | **Hash**: a72beb36

---

# REQ-d80052: User Account Management

**Level**: Dev | **Status**: Draft | **Implements**: p00050

## Rationale

User account management procedures ensure that access is properly provisioned, maintained, and revoked. This requirement specifies controls for the user account lifecycle.

## Assertions

A. The system SHALL limit system access to authorized individuals.
   *Source: 21 CFR Part 11.10(d)*

B. The system SHALL implement controls to ensure only authorized users can access the system.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 19*

C. The system SHALL ensure identification codes and passwords are not used by anyone other than their genuine owners.
   *Source: 21 CFR Part 11.300(a)*

D. The system SHALL ensure electronic signatures are unique to one individual and not reused by or reassigned to anyone else.
   *Source: 21 CFR Part 11.100(a)*

E. The system SHALL maintain a record of all user accounts, their assigned roles, and access privileges.
   *Source: 21 CFR Part 11.10(k)*

F. The system SHALL implement procedures for electronically deauthorizing lost, stolen, missing, or potentially compromised tokens, cards, or other devices.
   *Source: 21 CFR Part 11.300(c)*

G. The system SHALL provide the capability to immediately disable user accounts in response to security incidents.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 25*

H. The system SHALL retain user account information and associated audit trails even after account deactivation.
   *Source: 21 CFR Part 11.10(e)*

I. The system SHALL enforce separation of duties between user account administration and clinical data access.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 21*

*End* *User Account Management* | **Hash**: 95f45277

---

# REQ-d80061: System Validation Controls

**Level**: Dev | **Status**: Draft | **Implements**: p80060

## Rationale

Electronic systems used for regulated activities must be validated to ensure they perform as intended. This requirement specifies validation controls per FDA and GCP expectations.

## Assertions

A. The system SHALL be validated to ensure accuracy, reliability, consistent intended performance, and the ability to discern invalid or altered records.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(a)*

B. The system SHALL maintain validation documentation including test plans, test results, and validation conclusions.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(a)*

C. The system SHALL be validated before use to ensure it meets regulatory and user requirements.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 28*

D. The system SHALL implement change control procedures to evaluate and document the impact of changes on validated state.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 29*

E. The system SHALL undergo revalidation or qualification when changes are made that could affect system performance or data integrity.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(a)*

F. The system SHALL be validated to demonstrate fitness for intended use in the clinical investigation context.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Section II*

G. The system SHALL maintain validation documentation for the lifetime of the system plus the required record retention period.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(k)*

*End* *System Validation Controls* | **Hash**: 08ae9589

---

# REQ-d80062: IT Service Provider and Cloud System Controls

**Level**: Dev | **Status**: Draft | **Implements**: p80060

## Rationale

When electronic systems are hosted or managed by third-party IT service providers or cloud platforms, additional controls are required to ensure regulatory compliance. This requirement addresses controls for outsourced system components.

## Assertions

A. The system SHALL maintain documented agreements with IT service providers that define data integrity, security, and compliance responsibilities.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II.2*

B. The system SHALL ensure IT service providers implement controls equivalent to those required for in-house systems.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II.3*

C. The system SHALL ensure IT service provider agreements address data integrity and regulatory compliance.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 30*

D. The system SHALL provide the sponsor with the ability to audit IT service provider facilities, procedures, and records.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II.2*

E. The system SHALL ensure sponsor audit rights for IT service providers as required by GCP.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3)*

F. The system SHALL ensure data remains accessible and retrievable even upon termination of service provider agreements.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II.4*

G. The system SHALL maintain data sovereignty and ensure data processing locations comply with applicable regulatory requirements.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II.5*

H. The system SHALL implement data backup and disaster recovery procedures that ensure recovery point objectives (RPO) and recovery time objectives (RTO) meet regulatory retention and accessibility requirements.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 27*

*End* *IT Service Provider and Cloud System Controls* | **Hash**: e5b6cafb

---

# REQ-d80063: Digital Health Technology Data Capture

**Level**: Dev | **Status**: Draft | **Implements**: p00010, p00030

## Rationale

Digital health technologies (DHTs) such as wearables, mobile apps, and sensors generate clinical trial data that must meet the same integrity standards as traditional data sources. This requirement addresses DHT-specific considerations.

## Assertions

A. The system SHALL capture data from digital health technologies with metadata including device identifier, subject identifier, timestamp, and data collection context.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section IV*

B. The system SHALL maintain the audit trail for DHT-captured data from the point of capture through all transformations and transfers.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 9*

C. The system SHALL maintain complete audit trail from the point of data capture for electronically sourced data.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, FDA eSource guidance*

D. The system SHALL validate DHT data upon receipt to detect transmission errors or data corruption.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 16*

E. The system SHALL preserve the original DHT data in its native format or a certified copy.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section IV*

F. The system SHALL ensure eSource data is captured and retained in a manner that preserves the original data.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, FDA eSource guidance*

G. The system SHALL synchronize DHT timestamps with a reliable time source to ensure temporal accuracy.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 4*

H. The system SHALL document the algorithm or method used to process or derive values from raw DHT data.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section IV.2*

*End* *Digital Health Technology Data Capture* | **Hash**: 151b3a71
