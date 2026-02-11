# REQ-p80010: Electronic Records Controls

**Level**: PRD | **Status**: Draft | **Implements**: p00002, p00003, p00004

## Rationale

Electronic records used in clinical investigations must be trustworthy, reliable, and equivalent to paper records. This requirement establishes the controls necessary for electronic records to satisfy regulatory expectations for data integrity throughout the record lifecycle.

## Assertions

A. The system SHALL ensure electronic records are attributable, legible, contemporaneous, original, and accurate (ALCOA principles).
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, p.1 (ALCOA++ principles)*

B. The system SHALL protect records to enable their accurate and ready retrieval throughout the records retention period.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(c)*

C. The system SHALL maintain electronic records in accordance with FDA guidance on electronic systems in clinical investigations.
   *Source: 2024 10 FDA Guidance on electronic storaage 0 58358119fnl.pdf, Q&A Section II*

D. The system SHALL generate accurate and complete copies of records in both human-readable and electronic form suitable for inspection.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(b)*

*End* *Electronic Records Controls* | **Hash**: 6d82267c

---

# REQ-p80020: Electronic Signatures

**Level**: PRD | **Status**: Draft | **Implements**: p00002, p00003

## Rationale

Electronic signatures must provide the same level of accountability and non-repudiation as handwritten signatures. This requirement establishes controls for electronic signature components, uniqueness, and verification.

## Assertions

A. The system SHALL ensure electronic signatures are unique to one individual and not reused by, or reassigned to, anyone else.
   *Source: 21 CFR Part 11.100(a)*

B. The system SHALL verify the identity of an individual before establishing, assigning, certifying, or sanctioning their electronic signature.
   *Source: 21 CFR Part 11.100(b)*

C. The system SHALL ensure electronic signatures include the printed name of the signer, date and time of signing, and meaning of the signature (such as review, approval, responsibility, or authorship).
   *Source: 21 CFR Part 11.50(a)*

D. The system SHALL ensure electronic signatures are linked to their respective electronic records to ensure signatures cannot be excised, copied, or otherwise transferred to falsify an electronic record.
   *Source: 21 CFR Part 11.70*

E. The system SHALL employ electronic signatures based upon at least two distinct identification components such as an identification code and password.
   *Source: 21 CFR Part 11.200(a)(1)*

*End* *Electronic Signatures* | **Hash**: 5eb03a00

---

# REQ-p80030: Audit Trail Requirements

**Level**: PRD | **Status**: Draft | **Implements**: p00002, p00003, p00004, p00005

## Rationale

Audit trails are essential for demonstrating data integrity and regulatory compliance. They must capture who made changes, what was changed, when changes occurred, and why changes were made. This requirement establishes comprehensive audit trail controls derived from multiple regulatory sources.

## Assertions

A. The system SHALL use secure, computer-generated, time-stamped audit trails to independently record the date and time of operator entries and actions that create, modify, or delete electronic records.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(e)*

B. The system SHALL maintain audit trail documentation for a period at least as long as required for the subject electronic records.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(e)*

C. The system SHALL make audit trail documentation available for agency review and copying.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf, 11.10(e)*

D. The system SHALL capture the reason for data changes when changes are made to source data.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 6*

E. The system SHALL document the reason for any change or correction to trial-related records.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3) 4.9.3*

F. The system SHALL not obscure previous entries when making corrections to source data.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 5*

G. The system SHALL ensure audit trails cannot be disabled, overwritten, or altered by users.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, EMA Guideline Section 8.1*

*End* *Audit Trail Requirements* | **Hash**: 2070327e

---

# REQ-p80040: Data Correction Controls

**Level**: PRD | **Status**: Draft | **Implements**: p00004, p00005

## Rationale

Data corrections in clinical trial systems must preserve the integrity of the original data while allowing legitimate corrections. This requirement establishes controls for how corrections are made, documented, and preserved.

## Assertions

A. The system SHALL ensure corrections to data entries do not obscure or delete the original entry.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 5*

B. The system SHALL ensure any alteration to a trial-related record does not obscure the original entry.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3) 4.9.3*

C. The system SHALL require a reason to be provided when corrections or changes are made to source data.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 6*

D. The system SHALL maintain clear attribution of who made each data correction.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 3*

E. The system SHALL ensure data is attributable to the person who generated it.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ALCOA++ Attributable principle*

F. The system SHALL record the date and time of each data correction.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, Req 4*

G. The system SHALL ensure documentation of any change or correction includes the date of the change.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, ICH E6(R3) 4.9.3*

H. The system SHALL preserve the ability to view both the original value and the corrected value.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf, EMA Guideline Section 7.1*

*End* *Data Correction Controls* | **Hash**: a4ce844c

---

# REQ-p80050: System Access and Security Controls

**Level**: PRD | **Status**: Draft | **Implements**: p00002, p00003

## Rationale

Electronic systems must implement appropriate access controls and security measures to ensure only authorized individuals can access, modify, or sign records. This requirement establishes controls for user authentication, authorization, and system security.

## Assertions

A. The system SHALL employ procedures and controls designed to ensure the authenticity, integrity, and confidentiality of electronic records.
   *Source: 21 CFR Part 11.10(a)*

B. The system SHALL use operational system checks to enforce permitted sequencing of steps and events.
   *Source: 21 CFR Part 11.10(f)*

C. The system SHALL use authority checks to ensure only authorized individuals can use the system, electronically sign records, access operations, or input device.
   *Source: 21 CFR Part 11.10(g)*

D. The system SHALL use device checks to determine the validity of the source of data input or operational instruction.
   *Source: 21 CFR Part 11.10(h)*

E. The system SHALL control access by requiring unique identification codes and passwords for each user.
   *Source: 21 CFR Part 11.300(a)*

F. The system SHALL ensure identification codes and passwords are periodically checked, recalled, or revised.
   *Source: 21 CFR Part 11.300(b)*

G. The system SHALL implement procedures for electronically deauthorizing lost, stolen, missing, or potentially compromised tokens, cards, or other devices that bear or generate identification codes or passwords.
   *Source: 21 CFR Part 11.300(c)*

*End* *System Access and Security Controls* | **Hash**: c9937e50

---

# REQ-p80060: Closed and Open System Controls

**Level**: PRD | **Status**: Draft | **Implements**: p00002, p00003

## Rationale

Systems are categorized as closed or open based on who controls access. Closed systems are controlled by the persons responsible for the content of electronic records. Open systems require additional controls to ensure record authenticity, integrity, and confidentiality.

## Assertions

A. For closed systems, the system SHALL employ procedures and controls designed to ensure the authenticity, integrity, and confidentiality of electronic records from the point of their creation to receipt.
   *Source: 21 CFR Part 11.10*

B. For open systems, the system SHALL employ procedures and controls designed to ensure the authenticity, integrity, and confidentiality of electronic records from the point of their creation to receipt.
   *Source: 21 CFR Part 11.30*

C. For open systems, the system SHALL employ additional measures such as document encryption and use of appropriate digital signature standards.
   *Source: 21 CFR Part 11.30*

D. The system SHALL use appropriate controls over systems documentation including distribution of, access to, and use of documentation for system operation and maintenance.
   *Source: 21 CFR Part 11.10(k)*

*End* *Closed and Open System Controls* | **Hash**: 20d10fe8
