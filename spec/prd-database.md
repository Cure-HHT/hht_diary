# Clinical Trial Database Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-event-sourcing-system.md for generic event sourcing architecture
> **See**: dev-database.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: prd-clinical-trials.md for compliance requirements

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

**Level**: PRD | **Implements**: p00004, p00010, p00011 | **Status**: Active

The system SHALL preserve the complete history of all data modifications, ensuring original values are never overwritten or deleted.

Change history SHALL include:
- Original value when record first created
- All subsequent modifications (new values only)
- Identity of person who made each change
- Timestamp of each change
- Reason for change (when applicable)
- Device and session information for change

**Rationale**: Regulatory compliance (p00010, p00011) requires complete, tamper-proof history of all clinical data changes. Preserving original values proves data integrity and enables detection of improper modifications. Supports event sourcing architecture (p00004).

**Acceptance Criteria**:
- Original record values preserved permanently
- All modifications stored as separate historical records
- Change history cannot be altered or deleted
- Complete timeline reconstructable from history
- History includes who, what, when, why for every change

### Study Organization

**Clinical Sites**: Information about hospitals and research centers participating in the trial

**User Roles**: Which staff members can access which patient data

**Study Configuration**: Trial-specific settings and questionnaires

*End* *Complete Data Change History* | **Hash**: ab598860

---

## Data Isolation Between Sponsors

# REQ-p00003: Separate Database Per Sponsor

**Level**: PRD | **Implements**: p00001 | **Status**: Active

Each pharmaceutical sponsor SHALL operate an independent database instance with no shared tables, connections, or infrastructure with other sponsors.

Database isolation SHALL ensure:
- Each sponsor's data stored in physically separate database instances
- No database queries can access data across sponsor boundaries
- Database connections scoped to single sponsor
- Independent backup and recovery per sponsor

**Rationale**: Extends multi-sponsor isolation (p00001) to the database layer. Physical database separation ensures regulatory compliance for independent clinical trials and eliminates any technical possibility of data cross-contamination.

**Acceptance Criteria**:
- Each sponsor provisioned with dedicated database instance
- Database connection strings unique per sponsor
- No foreign keys or references across sponsor databases
- Backup/restore operations scoped to single sponsor
- Query execution cannot span multiple sponsor databases

*End* *Separate Database Per Sponsor* | **Hash**: 6a207b1a
---

## Event Sourcing Architecture

# REQ-p00004: Immutable Audit Trail via Event Sourcing

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL store all clinical trial data changes as immutable events, ensuring a complete and tamper-proof audit trail of every data modification.

Event storage SHALL ensure:
- Every data change recorded as separate, append-only event
- Events never modified or deleted after creation
- Complete chronological history preserved
- Each event includes: timestamp, user ID, action type, data values, reason for change
- Current data state derived by replaying events

**Rationale**: FDA 21 CFR Part 11 requires complete audit trails for electronic records. Event sourcing makes audit trails automatic and tamper-proof by design - you cannot modify data without creating an event, and events cannot be altered after creation.

**Acceptance Criteria**:
- All data changes stored as events, never direct updates
- Events are append-only (no UPDATE or DELETE operations)
- Event log includes who, what, when, why for every change
- System can reconstruct data state at any point in time
- Tampering with events is technically prevented by database constraints

### Why Event Sourcing?

Event Sourcing is the architectural approach used to store clinical trial data. Instead of saving only the current value of data, the system saves every change as a separate event. This creates an automatic, complete audit trail required for FDA compliance.

**Simple Analogy**: Like a bank statement that shows every transaction rather than just your current balance. You can see the full history and verify everything adds up correctly.

**Traditional Database Problem**:
1. Patient enters "pain level: 5"
2. System saves: `pain_level = 5`
3. Patient corrects to "pain level: 7"
4. System overwrites: `pain_level = 7`
5. Original value (5) is gone forever

**Problem**: No audit trail. No way to prove data wasn't tampered with.

**Event Sourcing Solution**:
1. Patient enters "pain level: 5"
2. System saves: `Event #1: set pain_level to 5`
3. Patient corrects to "pain level: 7"
4. System saves: `Event #2: set pain_level to 7`
5. Both events preserved forever

**Benefit**: Complete history. Can prove exactly what happened and when.

### Real-World Example: Patient Diary Entry

**Monday Morning** - Patient creates entry:
- Event: "Created diary entry, pain level 5"
- Stored with: timestamp, patient ID, "created"

**Monday Afternoon** - Patient realizes mistake:
- Event: "Updated diary entry, pain level 7"
- Stored with: timestamp, patient ID, "updated", reason: "corrected error"

**Tuesday** - Investigator adds note:
- Event: "Added annotation: followed up with patient"
- Stored with: timestamp, investigator ID, "annotation"

**Result**: Complete timeline of what happened. Auditors can see:
- Original entry was 5
- Patient corrected it to 7 (with reason)
- Investigator followed up
- Who did what and when

### Key Benefits

**1. Automatic Audit Trail**

**FDA Requirement**: Must track all data changes

**How Event Sourcing Helps**: Audit trail is automatic. Every change is an event, so you can't make a change without creating audit records.

**Traditional Systems**: Must remember to log changes. Easy to miss or bypass.

**Our System**: Impossible to change data without creating audit trail.

**2. Time Travel**

**Capability**: Can reconstruct data as it appeared at any point in time

**Use Cases**:
- "Show me this patient's data as it was on October 15"
- "What did the investigator see when they made that decision?"
- "Verify data hasn't been changed after study lock"

**Why This Matters**: Regulators can verify data integrity by checking historical states.

**3. Tamper Evidence**

**Protection**: Any attempt to alter historical events is detectable

**How**: Mathematical signatures on each event

**Result**: Can prove to regulators that data hasn't been tampered with

**4. Complete Transparency**

**For Patients**: Can see full history of their data and who accessed it

**For Investigators**: Can see when and why data changed

**For Auditors**: Complete visibility into all data changes

### How It Works (Simple Explanation)

**Event Store** (The Complete History):
- Every change stored as separate event
- Events never modified or deleted
- Grows larger over time
- Used for audit and compliance

**Current View** (What You See Now):
- Shows current state of data
- Automatically calculated from events
- Fast to query
- Used for daily operations

**When Patient Enters Data**:
1. New event created and stored
2. Current view updated automatically
3. Patient sees updated display

**When Staff Views Data**:
1. Query the current view (fast)
2. See latest values
3. Can click to see full history if needed

*End* *Immutable Audit Trail via Event Sourcing* | **Hash**: 0c0b0807

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
