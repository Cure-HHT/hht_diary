# Clinical Trial Database Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: dev-database.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: prd-clinical-trials.md for compliance requirements

---

## Executive Summary

The database stores patient diary entries with complete history of all changes for regulatory compliance. Each sponsor operates an independent database, ensuring complete data isolation between different clinical trials.

**Key Features**:
- Complete audit trail of every change
- Multiple clinical sites supported
- Works with offline mobile app
- Automatic conflict resolution
- FDA compliant record keeping

---

## What Data Is Stored

### Patient Diary Entries

**Clinical Observations**:
- Daily symptom reports
- Activity logs
- Questionnaire responses

**Why This Matters**: This data forms the evidence base for clinical trial results. Accurate capture and preservation is critical for drug approval.

### REQ-p00013: Complete Data Change History

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

---

## Data Isolation Between Sponsors

### REQ-p00003: Separate Database Per Sponsor

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

---

## How the Database Works

**See**: prd-database-event-sourcing.md for detailed event sourcing architecture

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

**Audit Trail**: Complete history automatically maintained

**Electronic Signatures**: Every action linked to user identity

**System Validation**: Database behavior is tested and documented

**Data Integrity**: ALCOA+ principles enforced

### Long-Term Retention

**Regulatory Requirement**: Clinical trial data retained for 7+ years

**Our Approach**:
- Standard database formats ensure long-term accessibility
- Export tools for archival
- Data remains readable decades later

---

## Benefits

**For Regulators**:
- Complete audit trail available for inspection
- Confidence in data integrity
- Evidence of proper controls

**For Sponsors**:
- Reduced risk of study rejection
- Simplified regulatory submission
- Protection against compliance violations

**For Patients**:
- Data never lost
- Privacy protected
- Full transparency of who accessed their records

---

## References

- **Implementation**: dev-database.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Event Sourcing Pattern**: prd-database-event-sourcing.md
- **Security**: prd-security.md
- **Compliance**: prd-clinical-trials.md
