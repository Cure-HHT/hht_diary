# REQ-p90001: Procedural Controls — 21 CFR Part 11

**Level**: PRD | **Status**: Draft | **Implements**: -

## Rationale

These are organizational, policy, and procedural obligations derived from FDA 21 CFR Part 11. They cannot be verified through automated system testing and are implemented through organizational policies, SOPs, training programs, and operational runbooks. Where obligations reference "persons using electronic signatures" (e.g., assertion D), these are customer-facing obligations that the organization enables through system design and documentation.

## Assertions

A. The organization SHALL ensure that persons who develop, maintain, or use electronic record/electronic signature systems have the education, training, and experience to perform their assigned tasks.
   *Source: 21 CFR 11.10(i), p. 4*

B. The organization SHALL establish and adhere to written policies that hold individuals accountable and responsible for actions initiated under their electronic signatures, in order to deter record and signature falsification.
   *Source: 21 CFR 11.10(j), p. 4*

C. The organization SHALL verify the identity of an individual before establishing, assigning, certifying, or otherwise sanctioning that individual's electronic signature, or any element of such electronic signature.
   *Source: 21 CFR 11.100(b), p. 5*

D. The organization SHALL provide documentation and procedures that enable customers to certify to regulatory agencies that electronic signatures are the legally binding equivalent of traditional handwritten signatures.
   *Source: 21 CFR 11.100(c), p. 5*

E. The organization SHALL ensure that electronic signatures are used only by their genuine owners.
   *Source: 21 CFR 11.200(a)(2), p. 6*

F. The organization SHALL ensure that computer systems (including hardware and software), controls, and attendant documentation maintained under this part are readily available for, and subject to, FDA inspection.
   *Source: 21 CFR 11.1(e), p. 2*

G. The organization SHALL validate the system to ensure accuracy, reliability, consistent intended performance, and the ability to discern invalid or altered records.
   *Source: 21 CFR 11.10(a), p. 4*

*End* *Procedural Controls — 21 CFR Part 11* | **Hash**: f7d1cba1

---

# REQ-p90002: Procedural Controls — FDA Guidance on Electronic Records

**Level**: PRD | **Status**: Draft | **Implements**: -

## Rationale

These are organizational, policy, and procedural obligations derived from FDA guidance (October 2024, Revision 1) on the use of electronic systems, electronic records, and electronic signatures in clinical investigations. They are implemented through organizational policies, SOPs, training programs, service agreements, and operational procedures. Obligations that fall on regulated entities or sponsors (e.g., IT service provider agreements, data originator lists) represent customer obligations that the organization enables through system capabilities and documentation. Obligations that apply to the organization as a software vendor are reframed accordingly.

## Assertions

A. The organization SHOULD assess compliance with 21 CFR Part 11 once electronic records from real-world data sources enter the sponsor's electronic data capture (EDC) system.
   *Source: Q1, page 4*

B. The organization SHOULD have written standard operating procedures (SOPs) to ensure consistency in the certification process.
   *Source: Q3, page 6*

C. The organization SHOULD ensure that the meaning of the record is preserved when retaining electronic records.
   *Source: Q5, page 6; 21 CFR 11.30*

D. The organization SHALL provide customers with the documentation, tools, and system information necessary for them to document the electronic systems used in their clinical investigations, including: (1) the electronic systems used to create, modify, maintain, archive, retrieve, or transmit pertinent electronic records; (2) the system requirements; and (3) a diagram that depicts the flow of data from data creation to final storage of data.
   *Source: Q8, page 9*

E. The organization SHOULD provide customers with documentation and system capabilities that enable them to maintain SOPs addressing: system setup, installation, and maintenance; system validation; user acceptance testing; change control procedures; system account setup and management including user access controls; data migration, retention, backup, recovery, and contingency plans; alternative data entry methods; audit trail and other information pertinent to use of the electronic system; support mechanisms including training and technical support; and roles and responsibilities of parties with respect to the use of electronic systems.
   *Source: Q8, page 9-10*

F. The organization SHALL maintain records related to staff training on the use of electronic systems.
   *Source: Q9, page 10; 21 CFR 11.10(i)*

G. The organization SHALL ensure that anyone who develops, maintains, or uses electronic systems subject to Part 11 has the education, training, and experience necessary to perform their assigned tasks.
   *Source: Q15, page 14; 21 CFR 11.10(i)*

H. The organization SHALL provide relevant training to individuals regarding the electronic systems they will use during the clinical investigation, conducted before an individual uses the system, during the study as needed, and when changes are made to the electronic system that impact the user.
   *Source: Q15, page 14*

I. The organization SHALL ensure that training covers processes and procedures to access the system, to complete clinical investigation documentation, and to detect and report incorrect data, and that training is documented.
   *Source: Q15, page 14*

J. The selection and application of access controls SHALL be based on an appropriately justified and documented risk assessment to protect the authenticity, integrity, and confidentiality of the data or information.
   *Source: Q11, page 12*

K. The organization SHOULD conduct a risk assessment to determine appropriate procedures and controls to secure records and data at rest and in transit to prevent access by intervening or malicious parties.
   *Source: Q11, page 12*

L. The organization SHOULD use encryption to ensure confidentiality of the data.
   *Source: Q11, page 12*

M. The organization SHALL address the continued validity of the source data in the case of security breaches to devices or systems, and SHALL provide customers with the information and support necessary for them to report security breaches impacting safety, privacy of participants, or validity of source data to the IRB and FDA in a timely manner.
   *Source: Q11, page 12-13*

N. The audit trail SHOULD include the reason for the change if applicable.
   *Source: Q12, page 13; 21 CFR 11.10(e)*

O. The organization SHOULD retain audit trails in a format that is searchable and sortable. If not practical, audit trail files SHOULD be retained in a static format (e.g., PDFs) and clearly correspond to the respective data elements and/or records.
   *Source: Q12, page 13*

P. When contracting with IT service providers, the organization SHALL ensure that electronic records meet applicable Part 11 requirements.
   *Source: Section III.C, page 15*

Q. The organization SHOULD have a written agreement (e.g., master service agreement with associated service level agreement or quality agreement) with IT service providers that describes how the IT services will meet the regulated entities' requirements.
   *Source: Q17, page 16*

R. Agreements with IT service providers SHALL address: the scope of the work and IT service being provided; the roles and responsibilities of the regulated entity and the IT service provider including those related to quality management; and a plan that ensures the customer will have access to data throughout the regulatory retention period.
   *Source: Q17, page 16*

S. The organization SHALL make available for FDA upon request: any agreements that define the sponsor's expectations of the IT service provider; and documentation of quality management activities related to the IT service including documentation of the regulated entity's oversight of IT services throughout the conduct of the trial.
   *Source: Q18, page 16*

T. The organization SHALL ensure that customers have access to all study-related records maintained by IT service providers, as those records may be reviewed during a sponsor inspection.
   *Source: Q19, page 17; 21 CFR 312.57*

U. The system SHALL provide capabilities that enable customers to develop and maintain a list of authorized data originators, which can be made available during an FDA inspection.
   *Source: Q20, page 18*

V. In situations where electronic signatures cannot be placed in a specified signature block, an electronic testament (e.g., "I approved the contents of this document") SHOULD be placed elsewhere in the document linking the signature to the electronic record.
   *Source: Section III.E, page 21*

W. The organization SHALL provide documentation and procedures that enable customers to submit a letter of non-repudiation to FDA, before or at the same time a person uses an electronic signature in an electronic record required by FDA, certifying that the electronic signature is intended to be the legally binding equivalent of a traditional handwritten signature.
   *Source: Q29, page 22; 21 CFR 11.100(c)*

*End* *Procedural Controls — FDA Guidance on Electronic Records* | **Hash**: 040a9870

---

# REQ-p90003: Procedural Controls — GCP Data Requirements

**Level**: PRD | **Status**: Draft | **Implements**: -

## Rationale

These are organizational, policy, and procedural obligations derived from the GCP Data Requirements for Audit Trails and Data Corrections document (ICH E6(R3), ISO 14155, EMA guidelines, and FDA guidance). They are implemented through organizational policies, SOPs, and operational procedures rather than automated system testing.

## Assertions

A. The organization SHALL provide system capabilities and documentation that enable customers to establish written procedures ensuring that changes or corrections in CRFs are documented, are necessary, are legible and traceable, and are endorsed by the principal investigator or authorized designee; and that records of the changes and corrections are maintained.
   *Source: ISO 14155 Section 7.8.2(a), p. 4*

B. The organization SHOULD retain the audit trail in a format that is searchable and sortable; if not practical, audit trail files should be retained in a static format (e.g., PDFs) and clearly correspond to the respective data elements and/or records.
   *Source: FDA Q&A Guidance Q12, pp. 15-16*

*End* *Procedural Controls — GCP Data Requirements* | **Hash**: 104f4dd0

---

# REQ-p90004: Procedural Controls — GCP Consolidated Requirements

**Level**: PRD | **Status**: Draft | **Implements**: -

## Rationale

These are organizational, policy, and procedural obligations derived from the GCP Consolidated Requirements for Audit Trails and Data Corrections document. They synthesize procedural controls across ICH E6(R3), ISO 14155, EMA guidelines, and FDA guidance into unified organizational obligations. They are implemented through organizational policies, SOPs, training programs, and governance processes rather than automated system testing.

## Assertions

A. The organization SHALL assess the system for appropriate "fit for purpose" before use in clinical trials, including validation of audit trail functionality.
   *Source: Consolidated Requirement 8, p. 1; ICH E6 (R3) 3.16.1(vi), 3.16.1(viii); ISO 14155 7.8.3; EMA/INS/GCP/112288/2023 4.4, A6.1-2; eSys/eRec/eSig B-Q8*

B. The organization SHALL maintain documented procedures for the data correction process, including training requirements.
   *Source: Consolidated Requirement 19, p. 2; ISO 14155 J.2; EMA/INS/GCP/112288/2023 A5.1.1.4; eSys/eRec/eSig B-Q15*

C. The organization SHALL support audits that evaluate the data correction process.
   *Source: Consolidated Requirement 20, p. 2; ISO 14155 J.3*

D. The organization SHALL determine which audit trails and metadata require review and retention.
   *Source: Consolidated Requirement 14, p. 2; ICH E6 (R3) 4.2.2(e); eSys/eRec/eSig B-Q12*

E. The organization SHALL establish planned, risk-based review of audit trails procedures.
   *Source: Consolidated Requirement 15, p. 2; ICH E6 (R3) 4.2.3; EMA/INS/GCP/112288/2023 6.2.2; eSys/eRec/eSig B-Q8, B-Q12*

F. The organization SHOULD foster a working environment that encourages reporting of omissions and erroneous results through data governance systems.
   *Source: Consolidated Requirement 22, p. 2; EMA/INS/GCP/112288/2023 4.1*

*End* *Procedural Controls — GCP Consolidated Requirements* | **Hash**: 591b974f
