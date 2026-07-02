# DIARY-BASE-identity-clinical-separation: Separation of Identity and Clinical Data

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliance-data-integrity

## Overview

Privacy-by-design partitioning of the platform's data: real *Participant* identity lives only in the authentication system, while the clinical *Database* holds de-identified observations keyed by an opaque, randomly generated *Participant* identifier. The mapping between the two is isolated to the authentication system, so a breach of the clinical store alone cannot re-identify a *Participant*. This is a foundational privacy control and belongs under Compliance and Data Integrity.

## Assertions

A. The System SHALL store *Participant* identity information (names, contact details, and other direct identifiers) separately from clinical *Trial* data.

B. The clinical *Database* SHALL contain only de-identified *Participant* records and SHALL NOT contain direct identifiers.

C. Each *Participant* SHALL be represented in the clinical *Database* by an opaque identifier that is randomly generated and not derivable from personal information.

D. The mapping between a *Participant*'s real identity and their clinical identifier SHALL be isolated to the authentication system and reachable only through it.

E. The System SHALL enable authorized review and export of clinical data using clinical identifiers only, without exposing *Participant* identities.

F. A compromise of the clinical *Database* alone SHALL NOT be sufficient to re-identify a *Participant*.

## Rationale

Keeping identity out of the clinical store means the store that is most widely accessed for analysis carries the least re-identification risk, and a breach of it exposes patterns rather than people. An opaque, non-derivable identifier prevents inference attacks that a structured or personal-data-derived id would permit. Confining the identity-to-clinical mapping to the authentication system gives re-identification a single, tightly governed choke point, satisfying the minimum-necessary principle for everyday clinical review while preserving the ability to reach a *Participant* when a safety obligation requires it.

*End* *Separation of Identity and Clinical Data* | **Hash**: 63382a0b
