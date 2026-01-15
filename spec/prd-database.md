# Clinical Trial Database Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-02
**Status**: Draft

> **See**: prd-system.md for platform overview
> **See**: prd-event-sourcing-system.md for generic event sourcing architecture
> **See**: dev-database.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: prd-clinical-trials.md for compliance requirements

---

# REQ-p00046: Clinical Data Storage System

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

This requirement defines the foundational data persistence layer for all clinical trial information. FDA 21 CFR Part 11 mandates that electronic records used in clinical trials maintain complete, tamper-evident audit trails and secure access controls. Event sourcing architecture ensures all data modifications are captured as immutable events, enabling reconstruction of complete data history at any point in time. Sponsor isolation through separate database instances protects data integrity across independent trials and prevents unauthorized cross-sponsor data access. Long-term retention capabilities ensure compliance with regulatory requirements for preserving clinical trial records.

## Assertions

A. The system SHALL use event sourcing to store all clinical trial data changes as immutable events.
B. The system SHALL maintain a complete audit trail of all data modifications.
C. The system SHALL provide a separate database instance for each sponsor.
D. The system SHALL enforce sponsor isolation to prevent cross-sponsor data access.
E. The system SHALL implement row-level security for access control.
F. The system SHALL enable reconstruction of complete data history at any point in time from stored events.
G. The system SHALL retain clinical trial data for a minimum of seven years to meet regulatory requirements.
H. The system SHALL ensure all audit trails are tamper-evident in compliance with FDA 21 CFR Part 11.

*End* *Clinical Data Storage System* | **Hash**: 2e588136

---

## Overview

This document describes the diary-specific implementation and refinement of the event-sourcing system.

---

## Executive Summary

The database stores patient diary entries with complete history of all changes for regulatory compliance.
Each sponsor operates an independent database, ensuring complete data isolation between different clinical trials.
FDA compliant record keeping.

---

## What Data Is Stored

- Daily nosebleed reports
- Questionnaire responses

# REQ-p00013: Complete Data Change History

**Level**: PRD | **Status**: Draft | **Implements**: p00004, p00010, p00011

## Rationale

FDA 21 CFR Part 11 compliance requires complete, tamper-proof audit trails for all clinical data modifications in electronic records. This requirement ensures that original values are permanently preserved to prove data integrity and enable detection of improper modifications. The change history supports regulatory inspections by providing a complete timeline of who made what changes, when, why, and from which device. This implements the event sourcing architecture pattern where all changes are captured as immutable events rather than overwriting existing data.

## Assertions

A. The system SHALL preserve the complete history of all data modifications.
B. The system SHALL ensure original values are never overwritten or deleted.
C. The system SHALL store the original value when a record is first created.
D. The system SHALL store all subsequent modifications as new values.
E. The system SHALL record the identity of the person who made each change.
F. The system SHALL record the timestamp of each change.
G. The system SHALL record the reason for change when applicable.
H. The system SHALL record device information for each change.
I. The system SHALL record session information for each change.
J. The system SHALL store all modifications as separate historical records.
K. The system SHALL NOT allow alteration of change history records.
L. The system SHALL NOT allow deletion of change history records.
M. The system SHALL enable reconstruction of the complete timeline from history.
N. Change history records SHALL include who made the change.
O. Change history records SHALL include what was changed.
P. Change history records SHALL include when the change occurred.
Q. Change history records SHALL include why the change was made.

*End* *Complete Data Change History* | **Hash**: 173331a9

---

## Data Isolation Between Sponsors

# REQ-p00003: Separate Database Per Sponsor

**Level**: PRD | **Status**: Draft | **Implements**: p00011

## Rationale

This requirement extends the multi-sponsor isolation principle (REQ-p00001) to the database infrastructure layer. Physical database separation is necessary for regulatory compliance in independent clinical trials, ensuring that each pharmaceutical sponsor's trial data is completely isolated from other sponsors. This architecture eliminates any technical possibility of data cross-contamination, provides clear audit boundaries for FDA 21 CFR Part 11 compliance, and ensures that database-level operations (queries, backups, recovery) cannot accidentally or intentionally access another sponsor's data. The physical separation also provides independent operational control and supports sponsor-specific compliance requirements.

## Assertions

A. The platform SHALL provision each pharmaceutical sponsor with a dedicated database instance.
B. The system SHALL NOT share database tables between sponsor instances.
C. The system SHALL NOT share database connections between sponsor instances.
D. The system SHALL NOT share database infrastructure between sponsor instances.
E. Each sponsor's data SHALL be stored in physically separate database instances.
F. Database connection strings SHALL be unique per sponsor.
G. Database queries SHALL NOT access data across sponsor boundaries.
H. Database connections SHALL be scoped to a single sponsor.
I. The system SHALL NOT create foreign keys that reference across sponsor databases.
J. The system SHALL NOT create database references that span across sponsor databases.
K. Backup operations SHALL be scoped to a single sponsor database.
L. Restore operations SHALL be scoped to a single sponsor database.
M. Query execution SHALL NOT span multiple sponsor databases.

*End* *Separate Database Per Sponsor* | **Hash**: bfb45afa
---

## Event Sourcing Architecture

# REQ-p00004: Immutable Audit Trail via Event Sourcing

**Level**: PRD | **Status**: Draft | **Implements**: p00011

## Rationale

FDA 21 CFR Part 11 requires complete audit trails for electronic records in clinical trials. Event sourcing is the architectural approach that makes audit trails automatic and tamper-proof by design - it is impossible to modify data without creating an event, and events cannot be altered after creation. This directly supports ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate) by ensuring every data change is recorded with full context. Unlike traditional database updates that overwrite values and lose history, event sourcing preserves the complete chronological sequence of all changes, enabling time-travel queries to reconstruct data state at any point and providing tamper evidence through the immutable event log.

## Assertions

A. The system SHALL store all clinical trial data changes as immutable events.
B. The system SHALL record every data change as a separate, append-only event.
C. The system SHALL NOT allow modification of events after creation.
D. The system SHALL NOT allow deletion of events after creation.
E. The system SHALL preserve the complete chronological history of all data changes.
F. Each event SHALL include a timestamp indicating when the change occurred.
G. Each event SHALL include the user ID of the person who made the change.
H. Each event SHALL include the action type performed.
I. Each event SHALL include the data values that were changed.
J. Each event SHALL include the reason for the change.
K. The system SHALL derive current data state by replaying events from the event store.
L. The system SHALL NOT use direct UPDATE operations to modify clinical trial data.
M. The system SHALL NOT use direct DELETE operations to remove clinical trial data.
N. The system SHALL enable reconstruction of data state at any point in time by replaying events up to that point.
O. The system SHALL prevent tampering with events through database constraints.
P. The event store SHALL use append-only storage that grows over time.
Q. The system SHALL maintain a current view of data that is automatically calculated from events.
R. The system SHALL update the current view automatically when new events are created.

*End* *Immutable Audit Trail via Event Sourcing* | **Hash**: 3be570a3

---

## Multi-Device Synchronization

Patients may use multiple devices (phone and tablet):

**Automatic Handling**:
- Each device stores data locally
- Changes sync to server when online
- System detects conflicts automatically
- Conflicts resolved intelligently

**Example Scenario**:
1. Patient makes entry on phone (offline)
2. Patient also makes entry on tablet (offline)
3. Both devices come online
4. System detects both entries
5. Most recent change wins (or patient chooses)

TODO - this is needs details.  When does the patient choose? 
This may be in a separate document that needs referencing - prd-event-sourcing-system.md?

---

## Access Control

**Patient Level**: Patients can only see their own data

**Site Level**: Study staff can only access patients at their assigned clinical sites

**Sponsor Level**: Sponsor administrators can see aggregate data across all sites (de-identified)

**Database Enforcement**: Access rules enforced by database itself, not just application. Cannot be bypassed even by programming errors.

---

## Data Integrity Guarantees

**Immutable Records**: Once written, records cannot be changed or deleted. New events are added instead.

**Cryptographic Verification**: Mathematical signatures detect any tampering

**Automatic Validation**: Database checks data format and required fields

**Referential Integrity**: Ensures all data relationships remain consistent

---

## Compliance and Validation

### FDA 21 CFR Part 11 Compliance

**Audit Trail**: Complete history automatically maintained via event sourcing

**Electronic Signatures**: Every action linked to user identity

**System Validation**: Database behavior is tested and documented

**Data Integrity**: ALCOA+ principles enforced

**ALCOA+ Compliance Through Event Sourcing**:

**Attributable**: Each event records who made the change

**Legible**: Events stored in readable format

**Contemporaneous**: Events timestamped when they occur

**Original**: Original data preserved in first event

**Accurate**: Events reflect actual changes made

**Complete**: Every change captured as event

**Consistent**: Same format for all events

**Enduring**: Events preserved permanently

**Available**: History accessible for review

### Long-Term Retention

**Regulatory Requirement**: Clinical trial data retained for 7+ years

**Our Approach**:
- Standard database formats ensure long-term accessibility
- Export tools for archival
- Data remains readable decades later

### Common Questions

**Q: Doesn't this use a lot of storage?**
A: Storage is inexpensive. Regulatory compliance and data integrity are priceless.

**Q: Is it slower than traditional databases?**
A: For daily use, no - queries use the current view which is optimized for speed. Historical queries take longer but are rare.

**Q: What if we need to correct a mistake?**
A: Create a new correction event. The mistake and correction are both visible in the audit trail, which is what regulators want to see.

**Q: Can data ever be deleted?**
A: Not removed, but can be marked as deleted. The deletion is recorded as an event, so you can see what was deleted, when, and by whom.

---

## Benefits

**For Regulators**:
- Complete audit trail available for inspection
- Confidence in data integrity
- Evidence of proper controls
- Time-travel capability for verification

**For Sponsors**:
- Reduced risk of study rejection
- Simplified regulatory submission
- Protection against compliance violations
- Automated compliance reduces manual oversight

**For Patients**:
- Data never lost
- Privacy protected
- Full transparency of who accessed their records
- Confidence data handled properly

---

## References

- **Implementation**: dev-database.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md
- **Compliance**: prd-clinical-trials.md
- **Pattern Documentation**: docs/adr/ADR-001-event-sourcing-pattern.md
