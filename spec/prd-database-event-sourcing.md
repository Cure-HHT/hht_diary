# Event Sourcing Architecture Pattern

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: dev-database.md for implementation details
> **See**: prd-database.md for complete database architecture
> **See**: prd-clinical-trials.md for compliance requirements

---

## Executive Summary

Event Sourcing is the architectural approach used to store clinical trial data. Instead of saving only the current value of data, the system saves every change as a separate event. This creates an automatic, complete audit trail required for FDA compliance.

**Simple Analogy**: Like a bank statement that shows every transaction rather than just your current balance. You can see the full history and verify everything adds up correctly.

---

## Why Event Sourcing?

### Traditional Database Problem

Most systems work like this:
1. Patient enters "pain level: 5"
2. System saves: `pain_level = 5`
3. Patient corrects to "pain level: 7"
4. System overwrites: `pain_level = 7`
5. Original value (5) is gone forever

**Problem**: No audit trail. No way to prove data wasn't tampered with.

### Event Sourcing Solution

Our system works like this:
1. Patient enters "pain level: 5"
2. System saves: `Event #1: set pain_level to 5`
3. Patient corrects to "pain level: 7"
4. System saves: `Event #2: set pain_level to 7`
5. Both events preserved forever

**Benefit**: Complete history. Can prove exactly what happened and when.

---

## Real-World Example

### Scenario: Patient Diary Entry

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

---

## Key Benefits

### REQ-p00004: Immutable Audit Trail via Event Sourcing

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

---

### 1. Automatic Audit Trail

**FDA Requirement**: Must track all data changes

**How Event Sourcing Helps**: Audit trail is automatic. Every change is an event, so you can't make a change without creating audit records.

**Traditional Systems**: Must remember to log changes. Easy to miss or bypass.

**Our System**: Impossible to change data without creating audit trail.

### 2. Time Travel

**Capability**: Can reconstruct data as it appeared at any point in time

**Use Cases**:
- "Show me this patient's data as it was on October 15"
- "What did the investigator see when they made that decision?"
- "Verify data hasn't been changed after study lock"

**Why This Matters**: Regulators can verify data integrity by checking historical states.

### 3. Tamper Evidence

**Protection**: Any attempt to alter historical events is detectable

**How**: Mathematical signatures on each event

**Result**: Can prove to regulators that data hasn't been tampered with

### 4. Complete Transparency

**For Patients**: Can see full history of their data and who accessed it

**For Investigators**: Can see when and why data changed

**For Auditors**: Complete visibility into all data changes

---

## How It Works (Simple Explanation)

### Two Parts

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

### Everyday Use

**When Patient Enters Data**:
1. New event created and stored
2. Current view updated automatically
3. Patient sees updated display

**When Staff Views Data**:
1. Query the current view (fast)
2. See latest values
3. Can click to see full history if needed

---

## Compliance Benefits

### FDA 21 CFR Part 11

**Requirement**: "Audit trails must be secure, computer-generated, and time-stamped"

**Our Compliance**: Events are automatically generated, include timestamps, and cannot be altered.

### ALCOA+ Principles

**Attributable**: Each event records who made the change

**Legible**: Events stored in readable format

**Contemporaneous**: Events timestamped when they occur

**Original**: Original data preserved in first event

**Accurate**: Events reflect actual changes made

**Complete**: Every change captured as event

**Consistent**: Same format for all events

**Enduring**: Events preserved permanently

**Available**: History accessible for review

---

## Common Questions

**Q: Doesn't this use a lot of storage?**
A: Storage is inexpensive. Regulatory compliance and data integrity are priceless.

**Q: Is it slower than traditional databases?**
A: For daily use, no - queries use the current view which is optimized for speed. Historical queries take longer but are rare.

**Q: What if we need to correct a mistake?**
A: Create a new correction event. The mistake and correction are both visible in the audit trail, which is what regulators want to see.

**Q: Can data ever be deleted?**
A: Not removed, but can be marked as deleted. The deletion is recorded as an event, so you can see what was deleted, when, and by whom.

---

## Business Value

**Risk Reduction**:
- Lower chance of regulatory rejection
- Protection against compliance violations
- Defense against data integrity challenges

**Efficiency**:
- Automated compliance reduces manual oversight
- Built-in audit trails eliminate separate logging
- Faster regulatory review process

**Trust**:
- Patients confident data handled properly
- Sponsors confident in data quality
- Regulators confident in data integrity

---

## References

- **Implementation Details**: dev-database.md
- **Database Architecture**: prd-database.md
- **Compliance Requirements**: prd-clinical-trials.md
- **Pattern Documentation**: docs/adr/ADR-001-event-sourcing-pattern.md
