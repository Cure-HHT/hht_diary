# REQ-p80001: FDA 21 CFR Part 11 Compliance

**Level**: PRD | **Status**: Draft | **Refines**: p00044-A

## Rationale

This is the top-level requirement establishing compliance obligations for electronic records, electronic signatures, and data integrity in clinical trial systems. It derives from FDA regulations, ICH guidelines, and related guidance documents governing the use of electronic systems in regulated environments.

## Assertions

A. The system SHALL comply with FDA 21 CFR Part 11 requirements for electronic records and electronic signatures.
   *Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf*

B. The system SHALL implement audit trail and data correction controls as specified in Good Clinical Practice consolidated requirements.
   *Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf*

C. The system SHALL satisfy the detailed audit trail and data correction requirements derived from ICH E6(R3), ISO 14155, EMA guidelines, and FDA guidance documents.
   *Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf*

D. The system SHALL conform to FDA guidance on use of electronic records, electronic signatures, and electronic systems in clinical investigations.
   *Source: 2024 10 FDA Guidance on electronic storage.pdf*

*End* *FDA 21 CFR Part 11 Compliance* | **Hash**: 54daf3d2
---

# REQ-p80002: 21 CFR Part 11 Compliance

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p80001-A

## Rationale

This requirement establishes compliance with FDA 21 CFR Part 11, the federal regulation governing electronic records and electronic signatures. Part 11 defines the criteria under which electronic records and signatures are considered trustworthy, reliable, and equivalent to paper records.

## Assertions

### Controls for Closed Systems (11.10)

A. The system SHALL generate accurate and complete copies of records in both human readable and electronic form suitable for inspection, review, and copying by the agency.
   *Reference: 21 CFR 11.10(b)*

B. The system SHALL protect records to enable their accurate and ready retrieval throughout the records retention period.
   *Reference: 21 CFR 11.10(c)*

C. The system SHALL limit system access to authorized individuals.
   *Reference: 21 CFR 11.10(d)*

D. The system SHALL use secure, computer-generated, time-stamped audit trails to independently record the date and time of operator entries and actions that create, modify, or delete electronic records.
   *Reference: 21 CFR 11.10(e)*

E. The system SHALL ensure that record changes do not obscure previously recorded information.
   *Reference: 21 CFR 11.10(e)*

F. The system SHALL retain audit trail documentation for a period at least as long as that required for the subject electronic records and make it available for agency review and copying.
   *Reference: 21 CFR 11.10(e)*

G. The system SHALL use operational system checks to enforce permitted sequencing of steps and events, as appropriate.
   *Reference: 21 CFR 11.10(f)*

H. The system SHALL use authority checks to ensure that only authorized individuals can use the system, electronically sign a record, access the operation or computer system input or output device, alter a record, or perform the operation at hand.
   *Reference: 21 CFR 11.10(g)*

I. The system SHALL use device checks to determine, as appropriate, the validity of the source of data input or operational instruction.
   *Reference: 21 CFR 11.10(h)*

J. The system SHALL implement adequate controls over the distribution of, access to, and use of documentation for system operation and maintenance.
   *Reference: 21 CFR 11.10(k)(1)*

K. The system SHALL implement revision and change control procedures to maintain an audit trail that documents time-sequenced development and modification of systems documentation.
   *Reference: 21 CFR 11.10(k)(2)*

### Signature Manifestations (11.50)

L. Signed electronic records SHALL contain information associated with the signing that clearly indicates the printed name of the signer.
   *Reference: 21 CFR 11.50(a)(1)*

M. Signed electronic records SHALL contain information associated with the signing that clearly indicates the date and time when the signature was executed.
   *Reference: 21 CFR 11.50(a)(2)*

N. Signed electronic records SHALL contain information associated with the signing that clearly indicates the meaning (such as review, approval, responsibility, or authorship) associated with the signature.
   *Reference: 21 CFR 11.50(a)(3)*

O. The signer name, signature date/time, and signature meaning SHALL be subject to the same controls as for electronic records and SHALL be included as part of any human readable form of the electronic record (such as electronic display or printout).
   *Reference: 21 CFR 11.50(b)*

### Signature/Record Linking (11.70)

P. Electronic signatures and handwritten signatures executed to electronic records SHALL be linked to their respective electronic records to ensure that the signatures cannot be excised, copied, or otherwise transferred to falsify an electronic record by ordinary means.
   *Reference: 21 CFR 11.70*

### Electronic Signature Uniqueness (11.100)

Q. Each electronic signature SHALL be unique to one individual and SHALL NOT be reused by, or reassigned to, anyone else.
   *Reference: 21 CFR 11.100(a)*

### Signature Components and Controls (11.200)

R. Electronic signatures that are not based upon biometrics SHALL employ at least two distinct identification components such as an identification code and password.
   *Reference: 21 CFR 11.200(a)(1)*

S. When an individual executes a series of signings during a single, continuous period of controlled system access, the first signing SHALL be executed using all electronic signature components; subsequent signings SHALL be executed using at least one electronic signature component that is only executable by, and designed to be used only by, the individual.
   *Reference: 21 CFR 11.200(a)(1)(i)*

T. When an individual executes one or more signings not performed during a single, continuous period of controlled system access, each signing SHALL be executed using all of the electronic signature components.
   *Reference: 21 CFR 11.200(a)(1)(ii)*

U. Electronic signatures SHALL be administered and executed to ensure that attempted use of an individual's electronic signature by anyone other than its genuine owner requires collaboration of two or more individuals.
   *Reference: 21 CFR 11.200(a)(3)*

V. Electronic signatures based upon biometrics SHALL be designed to ensure that they cannot be used by anyone other than their genuine owners.
   *Reference: 21 CFR 11.200(b)*

### Controls for Identification Codes/Passwords (11.300)

W. The system SHALL maintain the uniqueness of each combined identification code and password, such that no two individuals have the same combination of identification code and password.
   *Reference: 21 CFR 11.300(a)*

X. The system SHALL ensure that identification code and password issuances are periodically checked, recalled, or revised (e.g., to cover such events as password aging).
   *Reference: 21 CFR 11.300(b)*

Y. The system SHALL follow loss management procedures to electronically deauthorize lost, stolen, missing, or otherwise potentially compromised tokens, cards, and other devices that bear or generate identification code or password information, and to issue temporary or permanent replacements using suitable, rigorous controls.
   *Reference: 21 CFR 11.300(c)*

Z. The system SHALL use transaction safeguards to prevent unauthorized use of passwords and/or identification codes, and to detect and report in an immediate and urgent manner any attempts at their unauthorized use to the system security unit, and, as appropriate, to organizational management.
   *Reference: 21 CFR 11.300(d)*

AA. The system SHALL support initial and periodic testing of devices, such as tokens or cards, that bear or generate identification code or password information to ensure that they function properly and have not been altered in an unauthorized manner.
    *Reference: 21 CFR 11.300(e)*

---

## Procedural Controls

> These requirements represent organizational, policy, or procedural obligations that cannot be verified through automated system testing.

PC-A. The organization SHALL ensure that persons who develop, maintain, or use electronic record/electronic signature systems have the education, training, and experience to perform their assigned tasks.
     *Reference: 21 CFR 11.10(i)*

PC-B. The organization SHALL establish and adhere to written policies that hold individuals accountable and responsible for actions initiated under their electronic signatures, in order to deter record and signature falsification.
     *Reference: 21 CFR 11.10(j)*

PC-C. The organization SHALL verify the identity of an individual before establishing, assigning, certifying, or otherwise sanctioning that individual's electronic signature, or any element of such electronic signature.
     *Reference: 21 CFR 11.100(b)*

PC-D. Persons using electronic signatures SHALL certify to the agency that the electronic signatures in their system are intended to be the legally binding equivalent of traditional handwritten signatures.
     *Reference: 21 CFR 11.100(c)*

PC-E. Electronic signatures SHALL be used only by their genuine owners.
     *Reference: 21 CFR 11.200(a)(2)*

PC-F. Computer systems (including hardware and software), controls, and attendant documentation maintained under this part SHALL be readily available for, and subject to, FDA inspection.
     *Reference: 21 CFR 11.1(e)*

PC-G. The system SHALL be validated to ensure accuracy, reliability, consistent intended performance, and the ability to discern invalid or altered records.
     *Reference: 21 CFR 11.10(a)*

---

*Source: 21 CFR Part 11 (up to date as of 1-22-2026).pdf*

*End* *21 CFR Part 11 Compliance* | **Hash**: a5d5da23

---

# REQ-p80003: FDA Guidance on Electronic Records in Clinical Investigations

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p80001-D

## Rationale

This requirement derives from FDA guidance (October 2024, Revision 1) on the use of electronic systems, electronic records, and electronic signatures in clinical investigations. The guidance provides recommendations for sponsors, clinical investigators, IRBs, and contract research organizations on using electronic systems in compliance with 21 CFR Part 11.

## Assertions

### Electronic Records Maintenance

A. The system SHALL maintain electronic records needed for FDA to reconstruct a clinical investigation in electronic form in place of paper form, or where the electronic record is relied on to perform regulated activities, in compliance with 21 CFR 11.1(b).
   *Reference: Section III.A, page 4*

B. The system SHALL support records submitted to FDA in electronic form under predicate rules, even if such records are not specifically identified in FDA regulations.
   *Reference: Section III.A, page 4; 21 CFR 11.1(b)*

C. The system SHALL enable sponsors to ensure the quality and integrity of data submitted in support of marketing applications and other submissions, regardless of how the data were originally generated, maintained, or retained.
   *Reference: Q1, page 4; 21 CFR 314.126*

D. For clinical investigations conducted at non-U.S. sites under an IND, IDE, or INAD, the system SHALL support records in electronic form that are required under predicate rules, including electronic records submitted to FDA in support of marketing applications.
   *Reference: Q2, page 5; 21 CFR 11.1(b), 314.50, 514.1, 601.2, 814.20*

### Certified Copies

E. When maintaining and retaining a copy of an electronic record in place of an original paper or electronic record, the system SHALL support certified copies that include the date and time when the copy was created.
   *Reference: Q3, page 5*

F. The system SHALL support certified copies that have been verified (by dated signature or by generation through a validated process) to have the same information, including data that describe the context, content, and structure, as the original.
   *Reference: Q3, page 5-6; ICH E6(R2) Glossary*

G. When providing certified electronic or paper copies of electronic records, the system SHALL include the associated metadata of the original record (e.g., the date and time stamp for when the original data were acquired, changes made to the data).
   *Reference: Q3, page 6*

### Record Retention and Recovery

H. The system SHALL ensure the authenticity, integrity, and confidentiality of the data when retaining electronic records.
   *Reference: Q5, page 6; 21 CFR 11.30*

I. Electronic records and all associated metadata SHALL be preserved in a secure and traceable manner.
   *Reference: Q5, page 6*

J. The system SHALL ensure that electronic records are maintained for the applicable retention period and are available for inspection in accordance with applicable requirements.
   *Reference: Q5, page 6; 21 CFR 56.115(b), 312.57(c), 312.62(c), 511.1(b)(7)(ii), 511.1(b)(8)(i), 812.140(d)*

K. When records exist only in electronic form, the system SHALL have sufficient backup and recovery procedures in place to protect against data loss, including regular backups stored in a secure electronic location separate from the original records.
   *Reference: Q5, page 6*

L. The system SHALL maintain backup and recovery logs to facilitate an assessment of the nature and scope of data loss resulting from a system failure.
   *Reference: Q5, page 6-7*

M. The system SHALL provide all records and data needed to reconstruct a clinical investigation, including associated metadata and audit trails, for FDA inspection upon request.
   *Reference: Q5, page 7; 21 CFR 312.58, 312.68, 511.1(b)(8)(i), 812.140, 812.145*

N. When systems are decommissioned or contracts with hosted systems end, the system SHALL ensure that metadata are obtained and retained and can be linked to each corresponding data element.
   *Reference: Q5, page 7*

### System Validation

O. Electronic systems deployed in clinical investigations SHALL be fit for purpose and implemented in a way that is proportionate to the risks to participant safety and the reliability of trial results.
   *Reference: Section III.B, page 7*

P. The system SHALL use a risk-based approach for validation based on a justified and documented risk assessment, considering: (1) the intended use of the system; (2) the purpose and importance of the data or records collected, generated, maintained, or retained in the system; and (3) the potential of the system to affect the rights, safety, and welfare of participants or the reliability of trial results.
   *Reference: Q7, page 7-8*

Q. Validation SHALL be applied to system functionality, configurations specific to the clinical trial protocol, customizations, data transfers, and interfaces between systems (e.g., interoperability and communication).
   *Reference: Q7, page 8*

R. Electronic systems SHALL be validated prior to use in an investigation using a risk-based approach.
   *Reference: Q7, page 8*

S. Changes to electronic systems (including software upgrades, security and performance patches, equipment or component replacements, and new instrumentation) SHALL be evaluated and validated throughout the life cycle of the system depending on risk.
   *Reference: Q7, page 8*

T. Changes to the system SHALL NOT adversely affect the traceability, authenticity, or integrity of new or existing data, and all changes to the system SHALL be documented.
   *Reference: Q7, page 8*

### Security Safeguards

U. The system SHALL ensure that procedures and processes are in place to safeguard the authenticity, integrity and, when appropriate, confidentiality of electronic records.
   *Reference: Q11, page 11; 21 CFR 11.10, 11.30*

V. The system SHALL implement logical and physical access controls to limit system access to authorized users, particularly for systems that provide access to multiple users or systems accessed through networks.
   *Reference: Q11, page 11-12; 21 CFR 11.10(d), 11.30*

W. The system SHALL maintain a record of all clinical trial personnel authorized to access the electronic system, including: the date when a user is added, the user's access rights and permissions, and any changes to rights and permissions.
   *Reference: Q11, page 12*

X. The system SHALL ensure that individuals work only under their own usernames and passwords or other access controls and do not share login information with others.
   *Reference: Q11, page 12*

Y. The system SHALL take steps to prevent unauthorized access to the system, including requiring individuals to log out when leaving their workstations and implementing automatic logout for idle periods.
   *Reference: Q11, page 12; 21 CFR 11.10(d)*

Z. The system SHALL be designed to limit the number of login attempts and to record unauthorized login attempts.
   *Reference: Q11, page 12*

AA. The system SHALL have processes in place to detect, document, report, and remedy security protocol breaches involving attempted and confirmed unauthorized access.
    *Reference: Q11, page 12*

AB. The system SHALL have security safeguards (e.g., firewalls; antivirus, anti-malware, and anti-spyware software) in place and updated to prevent, detect, and remedy the effects of computer viruses, worms, and other potentially harmful software.
    *Reference: Q11, page 12*

AC. The system SHALL maintain procedures and controls for system access, data creation, data modification, and data maintenance.
    *Reference: Q9, page 10-11; 21 CFR 11.10(d) and (k)*

### Audit Trail Requirements

AD. The system SHALL provide audit trails that capture electronic record activities including all changes made to the electronic record, the individuals making the changes, and the date and time of the changes.
    *Reference: Q12, page 13; 21 CFR 11.10(e), 11.30*

AE. The system SHALL ensure that record changes do not obscure previously recorded information.
    *Reference: Q12, page 13; 21 CFR 11.10(e), 11.30*

AF. Audit trails SHALL be protected from modification and from being disabled.
    *Reference: Q12, page 13*

AG. All audit trail documentation on the creation, modification, and deletion of electronic records SHALL be available for FDA inspection and retained for a period at least as long as the period required for the subject electronic records.
    *Reference: Q12, page 13; 21 CFR 11.10(e), 11.30*

AH. Audit trail components SHALL include: (1) the date and time the data element or information was entered or modified; (2) the individual making the change (e.g., user ID and user role); and (3) the old value and the new value.
    *Reference: Q12, page 13; 21 CFR 11.10(e)*

AI. The audit trail SHALL record deliberate actions that a user takes to create, modify, or delete electronic records (e.g., save or submit), and any edits to completed fields SHALL be captured in the audit trail.
    *Reference: Q13, page 14*

AJ. If an edit check exists for submitted data and prompts the user to make a correction, the audit trail SHALL include the original response, the fact that the edit check prompted a correction, and any change made in response.
    *Reference: Q13, page 14*

### Date and Time Controls

AK. The system SHALL have controls in place to ensure that the system's date and time are correct, and individuals with system administrator roles SHALL be notified if a system date or time discrepancy is detected.
    *Reference: Q14, page 14*

AL. The ability to change the date or time SHALL be limited to authorized individuals with system administrator roles, and any changes to date or time SHALL be documented.
    *Reference: Q14, page 14*

AM. For electronic systems used in clinical investigations that span different time zones, the system SHALL indicate the time zone that corresponds to the date and time stamp or indicate that times are recorded as Greenwich Mean Time (GMT).
    *Reference: Q14, page 14*

### DHT Data Originator Identification

AN. When using DHTs to record data in a clinical investigation, each electronic data element SHALL be associated with an authorized data originator as part of an audit trail.
    *Reference: Q20, page 18*

AO. If a participant manually enters data into the DHT, the system SHALL identify the participant as the data originator. If another individual enters data on behalf of the participant, the system SHALL identify that individual as the data originator and document the reason the participant is not the data originator.
    *Reference: Q20, page 18*

AP. If a DHT transmits data automatically to the durable electronic data repository without human intervention, the system SHALL identify the DHT as the data originator and create a data element identifier that automatically identifies the DHT as the originator.
    *Reference: Q20, page 18*

### DHT Security and Data Transmission

AQ. DHTs SHALL be designed to prevent unauthorized changes to the data stored on the DHT.
    *Reference: Q21, page 19*

AR. Access controls (e.g., personal identification numbers, biometrics, multi-factor authentication) SHALL be in place for a mobile application that relies on user entry of data to ensure that entries come from authorized individuals.
    *Reference: Q21, page 19; 21 CFR 11.10(d) and (g), 11.30*

AS. Data recorded by a DHT and any relevant associated metadata SHALL be transmitted by a validated process to a durable electronic data repository according to the sponsor's pre-specified plan.
    *Reference: Q22, page 19*

AT. Transmission of DHT data SHALL occur contemporaneously or as soon as possible after data are recorded, and the date and time the data are transferred from the DHT to the electronic data repository SHALL be included in the audit trail.
    *Reference: Q22, page 19*

AU. Data stored in a durable electronic data repository MAY be moved to a different durable electronic data repository using a validated process.
    *Reference: Q22, page 19*

AV. For inspection purposes, electronic source data SHALL be considered located in the durable electronic data repository (e.g., EDC system, clinical investigation site database, cloud-based digital platform) into which the data recorded by the DHT are transmitted via direct, uninterruptable, and secure connection.
    *Reference: Q23, page 20*

### Electronic Signature Requirements

AW. Electronic signatures and their associated electronic records that meet all applicable requirements under Part 11 SHALL be considered equivalent to handwritten signatures.
    *Reference: Section III.E, page 20; 21 CFR 11.1(c)*

AX. Signed electronic records SHALL contain the printed name of the signer, the date and time when the signature was executed, and the meaning associated with the signature.
    *Reference: Section III.E, page 20; 21 CFR 11.50*

AY. When an individual executes a series of signings during a period of single, continuous controlled system access, the first signing SHALL be executed using all electronic signature components, but repeated signings MAY be executed using one electronic signature component that is only executable by and designed to be used only by the individual.
    *Reference: Section III.E, page 20; 21 CFR 11.200(a)(1)(i)*

AZ. Electronic signatures SHALL be linked to the respective electronic records to ensure that the signatures cannot be excised, copied, or otherwise transferred to falsify an electronic record by ordinary means.
    *Reference: Section III.E, page 20; 21 CFR 11.70*

BA. Any changes made to the record subsequent to the electronic signature SHALL be reflected in the audit trail.
    *Reference: Section III.E, page 21; 21 CFR 11.10(e), 11.30*

BB. Electronic signatures based on biometrics SHALL be designed to ensure that they cannot be used by anyone other than their genuine owners.
    *Reference: Q27, page 22; 21 CFR 11.200(b)*

BC. A handwritten signature executed to an electronic record (e.g., drawn with a finger or electronic stylus) SHALL be linked to its respective electronic record and placed on the electronic document just as it would appear on a printed document.
    *Reference: Q25, page 21; 21 CFR 11.70*

---

## Procedural Controls

> These requirements represent organizational, policy, or procedural obligations that cannot be verified through automated system testing.

### Compliance Assessment

PC-A. The system SHOULD assess compliance with 21 CFR Part 11 once electronic records from real-world data sources enter the sponsor's electronic data capture (EDC) system.
     *Reference: Q1, page 4*

### Standard Operating Procedures

PC-B. Regulated entities SHOULD have written standard operating procedures (SOPs) to ensure consistency in the certification process.
     *Reference: Q3, page 6*

PC-C. The system SHOULD ensure that the meaning of the record is preserved when retaining electronic records.
     *Reference: Q5, page 6; 21 CFR 11.30*

### System Documentation

PC-D. For each clinical investigation, the sponsor SHALL document: (1) the electronic systems used to create, modify, maintain, archive, retrieve, or transmit pertinent electronic records; (2) the system requirements; and (3) a diagram that depicts the flow of data from data creation to final storage of data.
     *Reference: Q8, page 9*

PC-E. The sponsor SHOULD maintain documentation or SOPs addressing: system setup, installation, and maintenance; system validation; user acceptance testing; change control procedures; system account setup and management including user access controls; data migration, retention, backup, recovery, and contingency plans; alternative data entry methods; audit trail and other information pertinent to use of the electronic system; support mechanisms including training and technical support; and roles and responsibilities of parties with respect to the use of electronic systems.
     *Reference: Q8, page 9-10*

### Training Requirements

PC-F. The system SHALL maintain records related to staff training on the use of electronic systems.
     *Reference: Q9, page 10; 21 CFR 11.10(i)*

PC-G. Anyone who develops, maintains, or uses electronic systems subject to Part 11 SHALL have the education, training, and experience necessary to perform their assigned tasks.
     *Reference: Q15, page 14; 21 CFR 11.10(i)*

PC-H. Relevant training SHALL be provided to individuals regarding the electronic systems they will use during the clinical investigation, conducted before an individual uses the system, during the study as needed, and when changes are made to the electronic system that impact the user.
     *Reference: Q15, page 14*

PC-I. Training SHALL cover processes and procedures to access the system, to complete clinical investigation documentation, and to detect and report incorrect data, and training SHALL be documented.
     *Reference: Q15, page 14*

### Security Risk Assessment

PC-J. The selection and application of access controls SHALL be based on an appropriately justified and documented risk assessment to protect the authenticity, integrity, and confidentiality of the data or information.
     *Reference: Q11, page 12*

PC-K. The system SHOULD conduct a risk assessment to determine appropriate procedures and controls to secure records and data at rest and in transit to prevent access by intervening or malicious parties.
     *Reference: Q11, page 12*

PC-L. The system SHOULD use encryption to ensure confidentiality of the data.
     *Reference: Q11, page 12*

### Security Breach Reporting

PC-M. In the case of security breaches to devices or systems, the system SHALL address the continued validity of the source data and report security breaches impacting safety, privacy of participants, or validity of source data to the IRB and FDA in a timely manner.
     *Reference: Q11, page 12-13*

### Audit Trail Recommendations

PC-N. The audit trail SHOULD include the reason for the change if applicable.
     *Reference: Q12, page 13; 21 CFR 11.10(e)*

PC-O. The system SHOULD retain audit trails in a format that is searchable and sortable. If not practical, audit trail files SHOULD be retained in a static format (e.g., PDFs) and clearly correspond to the respective data elements and/or records.
     *Reference: Q12, page 13*

### IT Service Provider Agreements

PC-P. When contracting with IT service providers, regulated entities SHALL ensure that electronic records meet applicable Part 11 requirements.
     *Reference: Section III.C, page 15*

PC-Q. Regulated entities SHOULD have a written agreement (e.g., master service agreement with associated service level agreement or quality agreement) with IT service providers that describes how the IT services will meet the regulated entities' requirements.
     *Reference: Q17, page 16*

PC-R. Agreements with IT service providers SHALL address: the scope of the work and IT service being provided; the roles and responsibilities of the regulated entity and the IT service provider including those related to quality management; and a plan that ensures the sponsor will have access to data throughout the regulatory retention period.
     *Reference: Q17, page 16*

PC-S. Regulated entities that outsource IT services SHALL make available for FDA upon request: any agreements that define the sponsor's expectations of the IT service provider; and documentation of quality management activities related to the IT service including documentation of the regulated entity's oversight of IT services throughout the conduct of the trial.
     *Reference: Q18, page 16*

PC-T. The sponsor SHALL have access to all study-related records maintained by IT service providers because those records may be reviewed during a sponsor inspection.
     *Reference: Q19, page 17; 21 CFR 312.57*

### DHT Data Originator Documentation

PC-U. The sponsor SHALL develop and maintain a list of authorized data originators, which SHALL be available during an FDA inspection.
     *Reference: Q20, page 18*

### Electronic Signature Legal Binding

PC-V. In situations where electronic signatures cannot be placed in a specified signature block, an electronic testament (e.g., "I approved the contents of this document") SHOULD be placed elsewhere in the document linking the signature to the electronic record.
     *Reference: Section III.E, page 21*

PC-W. Before or at the same time a person uses an electronic signature in an electronic record required by FDA, users of electronic signatures SHALL submit a letter of non-repudiation to FDA to certify that the electronic signature is intended to be the legally binding equivalent of a traditional handwritten signature.
     *Reference: Q29, page 22; 21 CFR 11.100(c)*

---

*Source: 2024 10 FDA Guidance on electronic storage.pdf*

*End* *FDA Guidance on Electronic Records in Clinical Investigations* | **Hash**: 7330eda3
---

# REQ-p80004: GCP Data Requirements for Audit Trails and Data Corrections

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p80001-C

## Rationale

This requirement establishes detailed audit trail and data correction requirements derived from ICH E6(R3), ISO 14155, EMA guidelines, and FDA guidance documents. These represent the comprehensive set of requirements for maintaining data integrity in clinical trial systems.

## Assertions

### ICH E6(R3) - Core Audit Trail Requirements

A. The system SHALL ensure that changes to source records are traceable, do not obscure the original entry, and are explained if necessary via an audit trail.
   *Reference: ICH E6(R3) Section 2.12.2*

B. The system SHALL ensure that changes or corrections in reported data are traceable, explained (if necessary), and do not obscure the original entry.
   *Reference: ICH E6(R3) Section 2.12.6*

C. The system SHALL ensure that corrections, additions, or deletions to source records and/or data acquisition tools are dated, explained (if necessary), and that approval of the change is properly documented.
   *Reference: ICH E6(R3) Section 3.11.4.5.1(c)*

D. The system SHALL allow correction of errors to data, including data entered by participants, where requested by investigators/participants, with such corrections justified and supported by source records around the time of original entry.
   *Reference: ICH E6(R3) Section 3.16.1(j)*

### ICH E6(R3) - System Logging Requirements

E. The system SHALL maintain logs of user account creation, changes to user roles and permissions, and user access.
   *Reference: ICH E6(R3) Section 4.2.2(a)(i)*

F. The system SHALL be designed to permit data changes in such a way that the initial data entry and any subsequent changes or deletions are documented, including, where appropriate, the reason for the change.
   *Reference: ICH E6(R3) Section 4.2.2(a)(ii)*

G. The system SHALL record and maintain workflow actions in addition to direct data entry/changes into the system.
   *Reference: ICH E6(R3) Section 4.2.2(a)(iii)*

H. The system SHALL ensure that audit trails, reports, and logs are not disabled, and that audit trails are not modified except in rare circumstances (e.g., when a participant's personal information is inadvertently included) and only if a log of such action and justification is maintained.
   *Reference: ICH E6(R3) Section 4.2.2(b)*

I. The system SHALL ensure that audit trails and logs are interpretable and can support review.
   *Reference: ICH E6(R3) Section 4.2.2(c)*

J. The system SHALL ensure that automatic capture of date and time of data entries or transfers are unambiguous (e.g., coordinated universal time (UTC)).
   *Reference: ICH E6(R3) Section 4.2.2(d)*

### ICH E6(R3) - Data Correction Attribution

K. The system SHALL attribute data corrections to the person or computerised system making the correction, with corrections justified and supported by source records around the time of original entry and performed in a timely manner.
   *Reference: ICH E6(R3) Section 4.2.4*

L. The system SHALL ensure that data changes made after trial unblinding are clearly documented, justified, authorized by the investigator, and reflected in an audit trail.
   *Reference: ICH E6(R3) Section 3.16.2(e)*

M. The audit trail SHALL show activities, initial entry, and changes to data fields or records, by whom, when, and where applicable, why; in computerised systems, the audit trail SHALL be secure, computer-generated, and time stamped.
   *Reference: ICH E6(R3) Glossary - Audit Trail*

### ISO 14155 - CRF Audit Trail Requirements

N. The system SHALL maintain an audit trail for any change or correction to data reported on a CRF, which shall be dated, initialled, and explained if necessary, and shall not obscure the original entry; this applies to both written and electronic changes or corrections.
   *Reference: ISO 14155 Section 7.8.2*

O. The system SHALL ensure that data changes are documented and that there is no deletion of entered data, maintaining an audit trail, data trail, and edit trail.
   *Reference: ISO 14155 Section 7.8.3(f)*

P. The system SHALL ensure that corrections, additions, or deletions made to CRFs are dated, explained if necessary, and initialled by the principal investigator or authorized designee; monitors shall not make corrections, additions, or deletions to the CRFs.
   *Reference: ISO 14155 Section 9.2.4.5(i)*

### EMA Guideline - Core Audit Trail Definition

Q. The system SHALL provide a secure, computer-generated, time-stamped electronic audit trail that allows reconstruction of events relating to the creation, modification, or deletion of an electronic record.
   *Reference: EMA Guideline Section Glossary - Audit Trail*

### EMA Guideline - ALCOA++ Data Integrity

R. The system SHALL ensure that data are collected, accessed, and maintained in a secure manner to fulfill the ALCOA++ principles (attributable, legible, contemporaneous, original, accurate, complete, consistent, enduring, available when needed, and traceable).
   *Reference: EMA Guideline Section 4.1*

### EMA Guideline - Timestamp and Traceability

S. The system SHALL capture the time point of observation and the time point of storage as part of metadata, including the audit trail, with accurate date and time information automatically captured and linked to an external standard.
   *Reference: EMA Guideline Section 4.5 - Contemporaneous*

T. The system SHALL ensure that any changes to data or context/metadata are traceable, do not obscure the original information, and are explained if necessary, with changes documented as part of the metadata (e.g., audit trail).
   *Reference: EMA Guideline Section 4.5 - Traceable*

### EMA Guideline - Audit Trail Protection and Storage

U. The system SHALL enable audit trails for the original creation and subsequent modification of all electronic data, with audit trails being robust such that normal users cannot deactivate them; if admin users can deactivate audit trails, this SHALL automatically create an entry into a log file.
   *Reference: EMA Guideline Section 6.2.1*

V. The system SHALL protect audit trail entries against change, deletion, and access modification (e.g., edit rights, visibility rights), and store the audit trail within the system itself.
   *Reference: EMA Guideline Section 6.2.1*

### EMA Guideline - Audit Trail Content and Export

W. The audit trail SHALL be visible at data-point level in the live system, and it SHALL be possible to export the entire audit trail as a dynamic data file to allow identification of systematic patterns or concerns in data across trial participants, sites, etc.
   *Reference: EMA Guideline Section 6.2.1*

X. The audit trail SHALL show the initial entry and the changes (value - previous and current) specifying what was changed (field, data identifiers), by whom (username, role, organisation), when (date/timestamp), and where applicable, why (reason for change).
   *Reference: EMA Guideline Section 6.2.1*

Y. The system SHALL record all changes made as a result of data queries or a clarification process in the audit trail; changes to data shall only be performed when justified, and justification shall be documented.
   *Reference: EMA Guideline Section 6.2.1*

Z. The system SHALL capture changes in data entry per field and not per page (e.g., eCRF page).
   *Reference: EMA Guideline Section 6.2.1*

AA. The system SHALL record the timestamp of data entry in the capture tool and timestamp of data saved to a hard drive as part of metadata, with the duration between initial capture and upload to a central server being short and traceable.
    *Reference: EMA Guideline Section 6.2.1*

### EMA Guideline - Access and Inspection

AB. The system SHALL ensure that electronic source data, including the audit trail, is directly accessible by investigators, monitors, auditors, and inspectors without compromising the confidentiality of participants' identities.
    *Reference: EMA Guideline Section 6*

AC. The system SHALL provide monitors, auditors, and inspectors access to trial participants (including potential participants screened but not enrolled) with access to audit trails.
    *Reference: EMA Guideline Section A6.8*

### EMA Guideline - Data Migration and Decommissioning

AD. The system SHALL ensure that data, contextual information, and the audit trail are not separated during data migration; arrangements shall ensure that the link between data and metadata can be established.
    *Reference: EMA Guideline Section 6.10*

AE. The system SHALL ensure that upon database decommissioning, archived formats provide the possibility to restore the database(s), including the restoration of dynamic functionality and all relevant metadata (audit trail, event logs, implemented edit checks, queries, user logs, etc.).
    *Reference: EMA Guideline Section 6.12*

### EMA Guideline - Blinding Protection

AF. The system SHALL ensure that care is taken so that information jeopardizing the blinding does not appear in the audit trail accessible to blinded users.
    *Reference: EMA Guideline Section 6.2.1*

AG. The system SHALL ensure access logs, including username and user role, are available, particularly for systems that contain critical unblinded data.
    *Reference: EMA Guideline Section 6.2.1*

### EMA Guideline - ePRO and eConsent Specific

AH. For ePRO systems designed to allow data correction, the system SHALL document data corrections and the audit trail SHALL record if data saved on the device are changed before the data are submitted.
    *Reference: EMA Guideline Section A5.1.1.2*

AI. For electronic informed consent, the system SHALL use timestamps for the audit trail for signing actions by trial participants and investigators, which cannot be manipulated by system settings; any alterations to the document shall invalidate the electronic signature.
    *Reference: EMA Guideline Section A5.3.2*

### FDA Electronic Source Data (2013)

AJ. The system SHALL ensure that modified and/or corrected data elements have data element identifiers that reflect the date, time, originator, and reason for the change, and must not obscure previous entries.
    *Reference: FDA Electronic Source Data Guidance Section III.A.4, referencing 21 CFR 11.10(e)*

AK. The system SHALL provide a field allowing originators to describe the reason for the change (e.g., transcription error); automatic transmissions shall have traceability and controls via the audit trail to reflect the reason for the change.
    *Reference: FDA Electronic Source Data Guidance Section III.A.4*

AL. The system SHALL ensure that if changes are made to the eCRF after the clinical investigator has already signed, the changes are reviewed and electronically signed by the clinical investigator.
    *Reference: FDA Electronic Source Data Guidance Section III.B.2*

### FDA Q&A Guidance (2024)

AM. The system SHALL ensure that all records and data needed to reconstruct a clinical investigation, including associated metadata and audit trails, are available for FDA inspection.
    *Reference: FDA Q&A Guidance Q5*

AN. The system SHALL provide copies of records (e.g., screenshots or paper printouts) and data in a human-readable form that include metadata and audit trail information.
    *Reference: FDA Q&A Guidance Q5*

AO. The system SHALL ensure that audit trails capture electronic record activities including all changes made to the electronic record, the individuals making the changes, the date and time of the changes, and should include the reasons for the changes.
    *Reference: FDA Q&A Guidance Q12*

AP. The system SHALL protect audit trails from modification and from being disabled.
    *Reference: FDA Q&A Guidance Q12*

AQ. The system SHALL ensure that record changes do not obscure previously recorded information.
    *Reference: FDA Q&A Guidance Q12*

AR. Audit trail components SHALL include: (1) the date and time the data element or information was entered or modified, (2) the individual making the change (e.g., user ID and user role), and (3) the old value and the new value.
    *Reference: FDA Q&A Guidance Q12*

AS. The system SHALL record deliberate actions that a user takes to create, modify, or delete electronic records (e.g., save or submit) in the audit trail; any edits to completed fields shall be captured in the audit trail.
    *Reference: FDA Q&A Guidance Q13*

AT. The system SHALL ensure that if an edit check exists for submitted data and prompts the user to make a correction, the audit trail includes the original response, the fact that the edit check prompted a correction, and any change made in response.
    *Reference: FDA Q&A Guidance Q13*

AU. The system SHALL ensure that any changes made to the record, including those subsequent to the electronic signature, are reflected in the audit trail.
    *Reference: FDA Q&A Guidance Section E*

### FDA Q&A Guidance - DHT Requirements

AV. The system SHALL associate each electronic data element with an authorized data originator as part of an audit trail; the data originator may be a person, a computer system, a DHT, or an EHR authorized to enter, change, or transmit data elements.
    *Reference: FDA Q&A Guidance Q20*

AW. The system SHALL include the date and time data are transferred from a DHT to the electronic data repository in the audit trail.
    *Reference: FDA Q&A Guidance Q22*

### FDA PRO Guidance (2009)

AX. The system SHALL NOT permit direct PRO data transmission from the PRO data collection device to the sponsor, clinical investigator, or other third party without an electronic audit trail that documents all changes to the data after it leaves the PRO data collection device.
    *Reference: FDA PRO Guidance Section F*

AY. The system SHALL maintain an audit trail to capture any changes made to electronic PRO data at any point in time after it leaves the patient's electronic device, enabling the clinical investigator to maintain and confirm electronic PRO data accuracy.
    *Reference: FDA PRO Guidance Section F*

---

## Procedural Controls

> These requirements represent organizational, policy, or procedural obligations that cannot be verified through automated system testing.

### Written Procedures

PC-A. The sponsor SHALL have written procedures to ensure that changes or corrections in CRFs are documented, are necessary, are legible and traceable, and are endorsed by the principal investigator or authorized designee; records of the changes and corrections shall be maintained.
     *Reference: ISO 14155 Section 7.8.2(a)*

### Audit Trail Retention Format

PC-B. The system SHOULD retain the audit trail in a format that is searchable and sortable; if not practical, audit trail files should be retained in a static format (e.g., PDFs) and clearly correspond to the respective data elements and/or records.
     *Reference: FDA Q&A Guidance Q12*

---

*Source: GCP Data - Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf*

*End* *GCP Data Requirements for Audit Trails and Data Corrections* | **Hash**: 52eb4a31

---

# REQ-p80005: GCP Consolidated Requirements for Audit Trails and Data Corrections

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p80001-B

## Rationale

This requirement derives from the Good Clinical Practice consolidated requirements document, which synthesizes audit trail and data correction requirements across multiple regulatory frameworks (ICH E6 (R3) GCP, ISO 14155, EMA/INS/GCP/112288/2023, eSource Data, eSys/eRec/eSig in Clinical Investigations, and PRO Guidance) into a unified set of controls. These requirements represent harmonized expectations for audit trails and data corrections in clinical trial computerized systems.

## Assertions

### ALCOA+ Principles and Data Integrity

A. The system SHALL ensure that source records, including audit trails, follow ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available).
   *Reference: Consolidated Requirement 1; ICH E6 (R3) 2.12.2; ISO 14155 7.8.2 a), 10.6 j); EMA/INS/GCP/112288/2023 4.1, 4.4, 4.5*

B. The system SHALL ensure that relevant metadata, including audit trails, supplies identification of and context to data and is considered as part of the original record.
   *Reference: Consolidated Requirement 10; ICH E6 (R3) 4.2.2; EMA/INS/GCP/112288/2023 4.3, 4.4, 4.5; eSource Data III-A-4; eSys/eRec/eSig B-Q5*

### Change Traceability and Attribution

C. The system SHALL ensure that all changes to data are traceable to the individual making the change.
   *Reference: Consolidated Requirement 2; ICH E6 (R3) 2.12.2, 12.2.6; EMA/INS/GCP/112288/2023 4.1, 4.5, 6.2.1; eSource Data III-A-4, III-B-2; eSys/eRec/eSig B-Q12*

D. The system SHALL ensure that changes do not obscure original data or previous entries, maintaining visibility of the complete data history.
   *Reference: Consolidated Requirement 3; ICH E6 (R3) 2.12.2, 2.12.6, 4.2.2(a)(ii); ISO 14155 7.8.2; EMA/INS/GCP/112288/2023 6.2.1; eSource Data III-A-4, III-B-2; eSys/eRec/eSig B-Q12*

E. The system SHALL capture the reason for the change when changes are made to data, where necessary or required.
   *Reference: Consolidated Requirement 4; ICH E6 (R3) 2.12.2, 2.12.6, 4.2.2(a)(ii); ISO 14155 7.8.2; EMA/INS/GCP/112288/2023 6.2.1; eSource Data III-A-4, III-B-2; eSys/eRec/eSig B-Q12*

### Data Corrections Process

F. The system SHALL ensure that corrections, additions, or deletions to source data are dated and explained when necessary.
   *Reference: Consolidated Requirement 5; ICH E6 (R3) 3.11.4.5.1(c), 3.16.1(i); EMA/INS/GCP/112288/2023 4.4, 6.2.1; eSource Data III-A-4, III-B-2; eSys/eRec/eSig B-Q12; PRO Guidance F*

G. The system SHALL properly document approval of data changes, including investigator sign-off of data where required.
   *Reference: Consolidated Requirement 6; ICH E6 (R3) 3.11.4.5.1; EMA/INS/GCP/112288/2023 6.3; eSource Data III-B-2*

H. The system SHALL ensure that data corrections are attributable, justified, and supported by source records.
   *Reference: Consolidated Requirement 16; ICH E6 (R3) 4.2.4; ISO 14155 7.8.2*

### Audit Trail Functionality and Security

I. The system SHALL implement appropriate audit trail functionality requirements for computerized systems.
   *Reference: Consolidated Requirement 7; ICH E6 (R3) 3.16.1(ii); ISO 14155 7.8.3; PRO Guidance F*

J. The system SHALL ensure that audit trails, reports, and logs are not disabled and are not capable of being deactivated by normal users.
   *Reference: Consolidated Requirement 11; ICH E6 (R3) 4.2.2(b); EMA/INS/GCP/112288/2023 6.2.1, A3.3; eSys/eRec/eSig B-Q12*

K. The system SHALL ensure that audit trails and logs are interpretable and reviewable, including by monitors.
   *Reference: Consolidated Requirement 12; ICH E6 (R3) 4.2.2(c); ISO 14155 9.2.4.5; PRO Guidance F*

L. The system SHALL enable reconstruction of the sequence of events through the audit trail.
   *Reference: Consolidated Requirement 17; ISO 14155 3.4; eSys/eRec/eSig B-Q5*

M. The system SHALL ensure no deletion of entered data and that audit trails are secure.
   *Reference: Consolidated Requirement 18; ISO 14155 7.8.3 f); EMA/INS/GCP/112288/2023 4.1*

N. The system SHALL store audit trails within the computer system.
   *Reference: Consolidated Requirement 24; EMA/INS/GCP/112288/2023 6.2.1*

### Date/Time and Automatic Capture

O. The system SHALL automatically capture the date and time of data entries, data transfers, and electronic signatures in an unambiguous format.
   *Reference: Consolidated Requirement 13; ICH E6 (R3) 4.2.2(d); EMA/INS/GCP/112288/2023 4.5, 6.2.1, A5.3.2; eSys/eRec/eSig D-Q22, E, Glossary; PRO Guidance F*

### Access and Review

P. The system SHALL provide direct access to source records, including audit trails, as agreed to and required for sponsor access.
   *Reference: Consolidated Requirement 9; ICH E6 (R3) 3.16.4; EMA/INS/GCP/112288/2023 6, 6.1.2, 6.6, A6.8*

### Data Governance

Q. The system SHALL support data governance that includes control over intentional and unintentional changes to data.
   *Reference: Consolidated Requirement 21; EMA/INS/GCP/112288/2023 4.1*

### Data Transfers

R. The system SHALL ensure that data transfers are pre-planned, validated, include audit trails, and are conducted in such a way that data is continuously accessible.
   *Reference: Consolidated Requirement 23; EMA/INS/GCP/112288/2023 6.1.2, 6.10; eSys/eRec/eSig D-Q20, D-Q22; PRO Guidance F*

### Blinding Protection

S. The system SHALL prevent access to audit trail information that might unblind the data for blinded users, ensuring access controls prevent unblinding.
   *Reference: Consolidated Requirement 25; EMA/INS/GCP/112288/2023 6.2.1*

T. The system SHALL retain individual system access information (audit trails) throughout the study for systems containing unblinding information.
   *Reference: Consolidated Requirement 30; eSys/eRec/eSig B-Q12*

### Retention and Decommissioning

U. The system SHALL allow for retention of data, including audit trails and metadata, for the required retention period during decommissioning of systems and databases.
   *Reference: Consolidated Requirement 26; EMA/INS/GCP/112288/2023 6.12; eSys/eRec/eSig B-Q5*

V. The system SHALL retain data, including audit trails, in a manner that allows for inspection and the generation of copies for regulatory agencies.
   *Reference: Consolidated Requirement 29; eSys/eRec/eSig B-Q5, B-Q12; PRO Guidance F*

### ePRO and eCRF Specific Requirements

W. The system SHALL capture changes to saved ePRO data prior to data submission in an audit trail, if such changes are permitted.
   *Reference: Consolidated Requirement 27; EMA/INS/GCP/112288/2023 A5.1.1.2, A5.1.1.4*

X. The system SHALL limit the ability to change eCRF data to the investigator or delegated clinical study staff only.
   *Reference: Consolidated Requirement 28; eSource Data III-A-4*

### Edit Check Audit Trailing

Y. The system SHOULD capture edit checks which prompt a data correction by the user in the audit trail, applied on a risk basis.
   *Reference: Consolidated Requirement 31; eSys/eRec/eSig B-Q13*

---

## Procedural Controls

> These requirements represent organizational, policy, or procedural obligations that cannot be verified through automated system testing. They establish constraints that must be true and enforced through organizational controls, documentation, and governance processes.

### Validation and Fit-for-Purpose

PC-A. The system SHALL be assessed for appropriate "fit for purpose" before use in clinical trials, including validation of audit trail functionality.
     *Reference: Consolidated Requirement 8; ICH E6 (R3) 3.16.1(vi), 3.16.1(viii); ISO 14155 7.8.3; EMA/INS/GCP/112288/2023 4.4, A6.1-2; eSys/eRec/eSig B-Q8*
     *Note: Validation is a documented process assessment, not an automated test.*

### Documented Procedures

PC-B. The system SHALL support documented procedures for the data correction process, including training requirements.
     *Reference: Consolidated Requirement 19; ISO 14155 J.2; EMA/INS/GCP/112288/2023 A5.1.1.4; eSys/eRec/eSig B-Q15*

### Audit Evaluation

PC-C. The system SHALL support audits that evaluate the data correction process.
     *Reference: Consolidated Requirement 20; ISO 14155 J.3*

### Audit Trail Review Planning

PC-D. The system SHALL support determination of which audit trails and metadata require review and retention.
     *Reference: Consolidated Requirement 14; ICH E6 (R3) 4.2.2(e); eSys/eRec/eSig B-Q12*

PC-E. The system SHALL support planned, risk-based review of audit trails procedures.
     *Reference: Consolidated Requirement 15; ICH E6 (R3) 4.2.3; EMA/INS/GCP/112288/2023 6.2.2; eSys/eRec/eSig B-Q8, B-Q12*

### Working Environment

PC-F. The system SHOULD support a working environment that encourages reporting of omissions and erroneous results through data governance systems.
     *Reference: Consolidated Requirement 22; EMA/INS/GCP/112288/2023 4.1*

---

*Source: GCP Data - Consolidated Requirements for Audit Trails & Data Corrections - 02Sept2025.pdf*

*End* *GCP Consolidated Requirements for Audit Trails and Data Corrections* | **Hash**: 70cb1b59
