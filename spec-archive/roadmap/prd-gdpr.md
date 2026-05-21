# EU GDPR Compliance

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2026-03-14
**Status**: Draft

> **See**: prd-clinical-trials.md for clinical trial requirements
> **See**: prd-security.md for security architecture

## REQ-p01061: EU GDPR

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p00045-B

**Refines**: p00045-B

## Assertions

A. The system SHALL comply with the EU General Data Protection Regulation (GDPR) for processing personal data of EU clinical trial participants.

B. The system SHALL establish and document a lawful basis for processing personal data, either explicit consent or legitimate interest for clinical trials.

C. The system SHALL implement a workflow to fulfill data subject access requests.

D. The system SHALL implement a workflow to fulfill data subject rectification requests.

E. The system SHALL implement a workflow to fulfill data subject erasure requests where applicable under GDPR.

F. The system SHALL implement a workflow to fulfill data subject portability requests.

G. The system SHALL collect only personal data that is necessary for trial purposes.

H. The system SHALL incorporate privacy protections into its architecture by design.

I. The platform SHALL maintain Data Processing Agreements with all third-party data processors.

J. The system SHALL support breach notification to the supervisory authority within 72 hours of breach detection.

K. The privacy policy SHALL document the GDPR lawful basis for processing personal data.

L. Data subject request workflows SHALL be documented.

M. Data Processing Agreements SHALL be in place with all third-party processors before processing begins.

N. The breach notification procedure SHALL be documented.

O. The breach notification procedure SHALL be tested.

P. A Data Protection Impact Assessment SHALL be completed for clinical trial data processing activities.

Q. The system SHALL implement exceptions to these rules as applicable to GCP and FDA data retention requirements.

## Rationale

Clinical trials conducted in the EU or involving EU residents must comply with the General Data Protection Regulation (GDPR). This regulation mandates specific protections for personal data of trial participants, including establishing lawful bases for processing, honoring data subject rights, implementing privacy-by-design principles, and ensuring timely breach notifications. Non-compliance poses significant risks including regulatory fines up to €20M or 4% of global turnover, potential invalidation of trial data for regulatory submissions, and erosion of participant trust. The requirement ensures the platform embeds GDPR compliance into its core architecture and operational procedures, enabling sponsors to conduct legally compliant clinical trials involving EU residents.

*End* *EU GDPR* | **Hash**: ab40debd
---

## REQ-p01062: GDPR Data Portability

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01061-F

**Refines**: p01061-F

## Assertions

A. The system SHALL enable patients to export their personal clinical diary data in a machine-readable format.

B. The system SHALL provide patient-initiated export of all diary entries and health records belonging to that patient.

C. Exported data SHALL be formatted as JSON.

D. The export SHALL include complete data comprising timestamps, values, and metadata.

E. The export functionality SHALL be accessible through the mobile app.

F. The export functionality SHALL NOT require sponsor assistance.

G. The system SHALL provide import capability to restore previously exported data.

H. The import functionality SHALL support restoration on the same device from which data was exported.

I. The import functionality SHALL support restoration on a different device than the one from which data was exported.

J. The export SHALL include all user-generated content.

K. The export SHALL include all timestamps associated with diary entries.

L. The export and import functionality SHALL operate without requiring network connectivity.

M. The export SHALL NOT include system internals such as sync state.

N. The export SHALL NOT include system internals such as device IDs.

## Rationale

GDPR Article 20 grants EU data subjects the right to receive their personal data in a structured, commonly used, machine-readable format. This requirement ensures clinical trial participants can exercise their data portability rights by obtaining their own health diary data for personal records or transfer to another system. The export functionality must be self-service to avoid dependency on sponsor resources while maintaining data completeness and usability across devices.

*End* *GDPR Data Portability* | **Hash**: 8cd1f69a
---
