# FDA Regulation Requirements - Suggestions for Improvement

This file documents gaps, inconsistencies, and improvement suggestions for the FDA regulation requirements in `spec/regulations/fda/`. These are SUGGESTIONS ONLY - the regulation files are primary sources and should not be modified during the integration phase.

> **Last Updated**: 2026-01-25
> **Graph Status**: 287 requirements, 3,551 assertions

## Format/Structure Issues

### 1. Missing Hierarchy Links ✓ RESOLVED

**File**: `prd-fda-21-cfr-11.md`
**Issue**: REQ-p80001 is the top-level requirement but has no explicit linkage to the platform root (REQ-p00044).
**Resolution**: Added `Implements: p00044` to REQ-p80001. FDA regulations are now connected to the platform hierarchy.

### 2. Cross-Reference Consistency — OPEN

**File**: `prd-fda-part11-domains.md`
**Issue**: Domain requirements (p80010-p80060) implement REQ-p80002 through REQ-p80005 but reference style varies.
**Suggestion**: Standardize reference style across all domain requirements.

## Content Gaps

### 1. DHT-Specific Requirements — OPEN

**Files**: Multiple
**Issue**: REQ-p80003 includes extensive DHT (Digital Health Technology) requirements but there's no explicit DEV-level implementation requirement for DHT data capture validation.
**Suggestion**: Add REQ-d80064 for DHT Data Validation Implementation covering:
- Data transmission validation
- Timestamping synchronization
- Data originator identification

*Note*: REQ-d80063 (Digital Health Technology Data Capture) exists but focuses on data capture controls rather than validation.

### 2. Biometric Signature Support — OPEN

**File**: `dev-fda-part11-technical-controls.md`
**Issue**: REQ-d80021 mentions biometric signatures (Assertion I) but lacks detailed technical implementation guidance.
**Suggestion**: Expand biometric signature technical controls or add separate requirement.

### 3. Time Zone Handling — OPEN

**File**: `prd-fda-21-cfr-11.md`
**Issue**: REQ-p80003-AM covers time zone requirements but technical implementation in DEV requirements doesn't address multi-timezone scenarios in detail.
**Suggestion**: Add specific DEV requirement for time zone normalization and storage (UTC vs local time handling).

## Mapping Gaps to Platform — OPEN

### Requirements Not Yet Covered by Platform

The following FDA regulation assertions don't have clear platform requirement mappings:

1. **REQ-p80002-K** (Documentation controls for system operation/maintenance) — OPEN
   - Platform has no explicit requirement for system documentation controls

2. **REQ-p80002-Y** (Loss management for compromised credentials) — OPEN
   - Platform mentions credential management but not explicit loss management procedures

3. **REQ-p80003-PC-P through PC-T** (IT Service Provider agreements) — OPEN
   - Platform doesn't have explicit vendor management requirements

4. **REQ-p80004-AF** (Blinding protection in audit trails) — OPEN
   - Platform has no explicit blinding support requirements

5. **REQ-p80005-S** (Prevent access to audit trail that might unblind data) — OPEN
   - Related to above, blinding-aware audit trail access

### Platform Requirements Without FDA Traceability — OPEN

The following platform requirements relate to FDA compliance but aren't explicitly traced:

1. **REQ-p00017** (Data Encryption) - Should trace to REQ-p80003-PC-L
2. **REQ-p01025** (Third-Party Timestamp Attestation) - Should trace to REQ-p80002-D
3. **REQ-p70006** (Comprehensive Audit Trail for Portal) - Should trace to REQ-p80030

## Procedural Control Gaps — OPEN

### SOP Requirements Needing Platform Support

The FDA regulations include Procedural Controls (PC-*) that require organizational/procedural support. The platform should document how these are addressed:

1. **Training Documentation** (REQ-p80003-PC-F,G,H,I) — OPEN
   - Platform needs training module or documentation requirement

2. **IT Service Provider Agreements** (REQ-p80003-PC-P,Q,R,S,T) — OPEN
   - Platform needs vendor management policy requirement

3. **Security Breach Reporting** (REQ-p80003-PC-M) — OPEN
   - Platform needs incident response requirement

## Recommendations for Future Updates — OPEN

1. **Add Status Field Validation**: Ensure all FDA requirements use valid status values (Draft, Active, Deprecated, Superseded)
   - *Note*: Roadmap files (p90xxx) have invalid "Roadmap" status (50 validation errors detected)

2. **Complete Hash Footers**: All requirements should have hash footers for change tracking
   - *Note*: FDA regulation requirements have proper hash footers

3. **Assertion Labeling**: Continue using consistent assertion labeling (A, B, C... AA, AB, AC...)
   - Validated: Assertions use A-Z, then AA, AB, AC... BC sequence

4. **Reference Formatting**: Standardize source reference formatting across files

---

## Phase 3 Integration Findings (DEV Level Verification)

### Orphan References in DEV FDA Requirements — OPEN (VERIFIED 2026-01-25)

The following DEV-level FDA requirements reference non-existent platform requirements. These appear to be typos where `p000xx` was used instead of `p800xx`:

| Requirement | References | Should Reference | Status |
| ----------- | ---------- | ---------------- | ------ |
| REQ-d80021 | p00020 | p80020 (Electronic Signatures) | **STILL OPEN** |
| REQ-d80031 | p00030 | p80030 (Audit Trail Requirements) | **STILL OPEN** |
| REQ-d80041 | p00040 | p80040 (Data Correction Controls) | **STILL OPEN** |
| REQ-d80051 | p00050 | p80050 (System Access and Security Controls) | **STILL OPEN** |
| REQ-d80052 | p00050 | p80050 (System Access and Security Controls) | **STILL OPEN** |
| REQ-d80061 | p00060 | p80060 (Closed and Open System Controls) | **STILL OPEN** |
| REQ-d80062 | p00060 | p80060 (Closed and Open System Controls) | **STILL OPEN** |
| REQ-d80063 | p00030 | p80030 (Audit Trail Requirements) | **STILL OPEN** |

**Note**: REQ-d80011 and REQ-d80063 correctly implement REQ-p00010 (FDA Part 11 Compliance).

**Action Required**: Update `dev-fda-part11-technical-controls.md` to fix these references when FDA files become editable.

### Circular Dependency Issue Discovered

**Issue**: Adding `p80030` to REQ-p00004's Implements created a circular dependency:
- REQ-p00004 → p80030 → p00004

**Resolution**: The integration plan's approach of having platform requirements implement FDA regulations creates circular dependencies because FDA regulation requirements (p80xxx) already implement platform requirements (p000xx).

**Correct Hierarchy**: FDA regulation requirements (p80xxx) should implement platform requirements (p000xx), not vice versa. The FDA files already have this correct direction:
- REQ-p80030 (Audit Trail Requirements) implements p00004 (platform audit trail)
- REQ-p80040 (Data Correction Controls) implements p00004 (platform audit trail)

This means FDA traceability is already established in the reverse direction.

### Successfully Added References

The following platform requirements were successfully updated to reference FDA regulations:
- REQ-p00010: Added p80002 (21 CFR Part 11 Compliance)
- REQ-p00011: Added p80005-A (ALCOA+ principles)
- REQ-p00013: Added p80030, p80040 (Audit Trail & Data Correction)
- REQ-o00005: Added p80030 (Audit Trail Requirements)
- REQ-o00041: Added o80030 (Standard Operating Procedures)

---

## Phase 4 Coverage Analysis Results — VERIFIED 2026-01-25

### Graph Statistics
- Total requirements: 287
- Total assertions: 3,551
- Validation status: 50 errors (all in roadmap files - invalid "Roadmap" status)

### FDA Requirement Coverage Summary

#### Successfully Covered FDA Requirements (via inferred coverage)

| Requirement | Coverage | Assertions | Source |
| ----------- | -------- | ---------- | ------ |
| REQ-p80002 (21 CFR Part 11) | 100% | 27/27 | Inferred via REQ-p00010 |
| REQ-p80030 (Audit Trail Requirements) | 100% | - | Inferred via REQ-p00013, REQ-o00005 |
| REQ-p80040 (Data Correction Controls) | 100% | - | Inferred via REQ-p00013 |
| REQ-p80005 (GCP Consolidated Requirements) | 4% | - | Partially inferred via REQ-p00011 |

#### FDA Requirements Without Platform Coverage — OPEN

The following FDA requirements need platform implementations to be created:

| Requirement | Assertions | Coverage | Status |
| ----------- | ---------- | -------- | ------ |
| REQ-p80010 (Electronic Records Controls) | 4 | 0% | **OPEN** |
| REQ-p80020 (Electronic Signatures) | 5 | 0% | **OPEN** |
| REQ-p80050 (System Access and Security Controls) | - | 0% | **OPEN** |
| REQ-p80060 (Closed and Open System Controls) | - | 0% | **OPEN** |
| REQ-o80010 (Training and Personnel Qualification) | - | 0% | **OPEN** |
| REQ-o80020 (Record Retention and Archival) | - | 0% | **OPEN** |
| REQ-o80030 (Standard Operating Procedures) | - | partial | **OPEN** |
| REQ-p80003 (FDA Guidance on Electronic Records) | - | 0% | **OPEN** |
| REQ-p80004 (GCP Data Requirements) | - | 0% | **OPEN** |

### Recommendations — OPEN

1. **Create Platform Requirements for Uncovered FDA Requirements**:
   - REQ-p000xx for electronic records controls → implements REQ-p80010
   - REQ-p000xx for electronic signatures → implements REQ-p80020
   - REQ-o000xx for training/personnel → implements REQ-o80010
   - REQ-o000xx for record retention → implements REQ-o80020

2. **Fix Orphan References in DEV FDA Files** (when FDA files become editable):
   - Change d80xxx references from p000xx to p800xx
   - **File**: `dev-fda-part11-technical-controls.md`
   - 8 orphan references identified and verified (see Phase 3 section)

3. **Add Test Coverage**:
   - The "inferred" coverage indicates requirement relationships exist but no tests are linked
   - Add test references to validate FDA requirement assertions

---

## Summary of Open Items

| Category | Count | Priority |
| -------- | ----- | -------- |
| Orphan DEV References | 8 | High (blocks correct traceability) |
| Uncovered FDA Requirements | 9 | Medium (coverage analysis) |
| Content Gaps | 3 | Medium (DHT, Biometric, Time Zone) |
| Procedural Control Gaps | 3 | Medium (SOP, Training, Vendor) |
| Mapping Gaps | 8 | Low (platform → FDA traceability) |

---

*Last verified: 2026-01-25 via elspais MCP tools*
*Next review: After FDA files become editable*
