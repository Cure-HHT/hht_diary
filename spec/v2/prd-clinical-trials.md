# Clinical Trial Compliance Requirements

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-10-23
**Status**: Active

> **See**: dev-compliance-practices.md for implementation guidance
> **See**: prd-database-event-sourcing.md for Event Sourcing pattern
> **See**: ops-security.md for operational procedures

---

## Overview

This document defines the regulatory compliance requirements for clinical trial diary data systems. These requirements inform both product design and operational procedures.

**Primary Regulations**:
- FDA 21 CFR Part 11 (Electronic Records and Electronic Signatures)
- ALCOA+ Principles (Data Integrity)
- HIPAA (if applicable to study)
- GDPR (if EU participants)

---

## FDA 21 CFR Part 11 Compliance

### Electronic Records (§11.10)

**§11.10(a) - System Validation**
- System must be validated before deployment
- Validation documentation must be maintained
- Changes require revalidation

**§11.10(b) - Audit Trail**
- System must generate complete audit trail
- Audit trail cannot be modified
- Time-stamped with user identification
- Required for: All data creation, modification, deletion

**§11.10(c) - System Access Controls**
- Only authorized users can access system
- Access controls enforced at database level (RLS)
- Failed access attempts logged

**§11.10(d) - User Authentication**
- Verify identity of individuals
- Multi-factor authentication for privileged users
- Password complexity requirements

**§11.10(e) - Record Integrity**
- Operational checks to enforce permitted sequencing
- Authority checks to ensure only authorized individuals can use system
- Device checks (e.g., valid terminals)
- Education and experience checks

**§11.10(k) - System Documentation**
- Documentation of system design and validation
- Written policies for system operation
- Controls for document changes and revisions

### Electronic Signatures (§11.50)

**§11.50(a) - Signature Components**
- Signed electronic records must contain:
  - Name of signer (created_by)
  - Date and time of signature (server_timestamp)
  - Meaning of signature (operation, role)
  
**§11.50(b) - Signature Linking**
- Electronic signatures must be linked to respective records
- Cannot be excised, copied, or transferred
- Implementation: Cryptographic hash in event store

### Implementation via Event Sourcing

Our Event Sourcing architecture naturally satisfies FDA requirements:

**Audit Trail (§11.10(b))**:
- Event store provides immutable audit trail
- Every change captured as an event
- Cannot be modified (INSERT-only table)
- Includes who, what, when, why

**Record Integrity (§11.10(e))**:
- Database triggers enforce proper sequencing
- parent_audit_id tracks version history
- Cryptographic hashes detect tampering
- Row-level security enforces authorization

**Electronic Signatures (§11.50)**:
- Each event includes: created_by, role, server_timestamp, change_reason
- Cryptographic signature_hash links signature to record
- Hash cannot be copied or transferred

---

## ALCOA+ Principles

### Attributable
**Requirement**: All data must be attributable to the individual who created it.

**Implementation**:
- created_by field (user ID)
- role field (role at time of action)
- device_info (device metadata)
- ip_address (source IP)
- session_id (session tracking)

### Legible
**Requirement**: Data must be readable and understandable.

**Implementation**:
- JSONB format (human-readable, structured)
- Clear field names
- Timestamps in ISO 8601 format
- UTF-8 encoding

### Contemporaneous
**Requirement**: Data recorded at the time of observation.

**Implementation**:
- client_timestamp (when user recorded)
- server_timestamp (when server received)
- Timestamp comparison for validation

### Original
**Requirement**: Original record must be preserved.

**Implementation**:
- Event store is immutable (Event Sourcing pattern)
- Database rules prevent UPDATE/DELETE
- All changes append new events
- Original data always retrievable

### Accurate
**Requirement**: Data must be accurate and complete.

**Implementation**:
- Data validation via database triggers
- JSONB schema validation
- Cryptographic hashes verify integrity
- No unauthorized modifications possible

### Complete
**Requirement**: All data and metadata must be captured.

**Implementation**:
- Required fields enforced (NOT NULL)
- Metadata: who, what, when, why, where, how
- ALCOA+ fields: device_info, ip_address, session_id
- change_reason required for all modifications

### Consistent
**Requirement**: Data timing and sequence must be reliable.

**Implementation**:
- Event store maintains chronological order (audit_id)
- parent_audit_id tracks version lineage
- Server timestamps prevent clock manipulation
- Event Sourcing ensures consistency

### Enduring
**Requirement**: Records must be retained for required period.

**Implementation**:
- Event store never deleted (immutable)
- Minimum 7-year retention (FDA requirement)
- Archival strategy for old partitions
- Backup and disaster recovery

### Available
**Requirement**: Data must be available for review and audit.

**Implementation**:
- Read model for current state queries
- Event store for historical queries
- Audit functions for compliance reports
- Export capabilities for regulators

---

## Data Integrity Requirements

### Tamper Evidence
- Cryptographic hashes for all events
- Hash verification functions
- Sequence gap detection
- Integrity reports for auditors

### Version Control
- parent_audit_id creates version chain
- Conflict detection for multi-device sync
- Complete history reconstruction

### Deletion Handling
- Soft delete only (is_deleted flag in read model)
- Event store retains all deletion events
- Reason required for deletion
- Cannot truly delete from event store (regulatory requirement)

---

## Compliance Verification

### Automated Checks
- `check_audit_sequence_gaps()` - Detect missing events
- `validate_alcoa_compliance()` - Verify ALCOA+ for single event
- `generate_compliance_report()` - Overall compliance status
- `verify_audit_batch()` - Batch integrity verification

### Manual Audits
- Regulatory inspections (FDA, EMA)
- Internal compliance audits
- Third-party assessments
- Sponsor reviews

### Documentation Requirements
- Validation documentation
- Standard Operating Procedures (SOPs)
- Change control records
- Audit trail reports

---

## Risk Mitigation

### Technical Controls
- Immutable event store
- Row-level security
- Cryptographic hashing
- Automated integrity checks

### Operational Controls
- User training
- Access control policies
- Incident response procedures
- Regular compliance audits

### Administrative Controls
- Change control board
- Quality management system
- Document control
- Corrective and preventive actions (CAPA)

---

## References

- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [ALCOA+ Principles (MHRA)](https://www.gov.uk/guidance/gxp-data-integrity-guidance-and-definitions)
- **Implementation**: dev-compliance-practices.md
- **Technical Details**: prd-database-event-sourcing.md
- **Operations**: ops-security.md

---

**Source**: Extracted from db-spec.md (FDA Compliance section) and compliance requirements across specs
