# Specification Hierarchy Reorganization Report

**Date**: 2025-12-13
**Ticket**: CUR-541
**Author**: Claude Code

## Executive Summary

This report documents the reorganization of PRD requirements into a clean hierarchical structure rooted in REQ-p00044 (Clinical Trial Diary Platform). The goal was to establish a defensible requirement hierarchy that flows from top-level platform requirements down through system components and compliance frameworks.

## Changes Made

### 1. Hierarchy Analysis Script Created

**File**: `tools/requirements/analyze_hierarchy.py`

A new analysis script that:
- Parses all PRD requirements from spec/
- Identifies orphaned requirements (missing or incorrect `implements` field)
- Proposes parent assignment based on content analysis using domain classification
- Generates reports of proposed changes

### 2. Hierarchy Application Script Created

**File**: `tools/requirements/apply_hierarchy_changes.py`

An application script that:
- Reads proposals from the analysis script
- Applies changes to the spec files
- Generates summary of modifications

### 3. Requirements Hierarchy Updates

**25 PRD requirements updated** across 6 files:

| Requirement | Previous Parent | New Parent | Rationale |
| ----------- | --------------- | ---------- | --------- |
| p00021 (Architecture Decision Documentation) | - | p00044 | Cross-cutting concern |
| p00041 (CDISC Standards Compliance) | - | p00044 | Cross-cutting concern |
| p00046 (Clinical Data Storage System) | p00045 | p00044 | Direct platform component |
| p01000-p01019 (Event Sourcing System) | - | p00046 | Database subsystem |
| p01020 (Privacy Policy) | - | p00010 | Compliance domain |
| p01021-p01022 (SLA Requirements) | - | p00048 | Operations domain |
| p01050 (Event Type Registry) | - | p00046 | Database subsystem |

### 4. Files Modified

1. `spec/prd-requirements-management.md` - Updated p00021 implements
2. `spec/prd-standards.md` - Updated p00041 implements
3. `spec/prd-database.md` - Updated p00046 implements
4. `spec/prd-event-sourcing-system.md` - Updated 19 requirements
5. `spec/prd-glossary.md` - Updated p01020 implements
6. `spec/prd-SLA.md` - Updated 2 requirements

## New Hierarchy Structure

### Level 1: Top-Level (implements: nothing)
```
REQ-p00044: Clinical Trial Diary Platform (Root)
REQ-p01041: Open Source Licensing (Parallel to Root)
```

### Level 2: Major System Components (implements: p00044)
```
├── REQ-p00043: Diary Mobile Application
├── REQ-p00045: Sponsor Portal Application
├── REQ-p00046: Clinical Data Storage System
├── REQ-p00047: Data Backup and Archival
├── REQ-p00048: Platform Operations and Monitoring
├── REQ-p00049: Ancillary Platform Services
├── REQ-p01042: Web Diary Application
├── REQ-p00001: Complete Multi-Sponsor Data Separation
├── REQ-p00010: FDA 21 CFR Part 11 Compliance
├── REQ-p00041: CDISC Standards Compliance
└── REQ-p00021: Architecture Decision Documentation
```

### Level 3+: Derived Requirements

#### Under p00046 (Data Storage System)
- p01000-p01019: Event Sourcing System (19 requirements)
- p01050-p01053: Event Type Registry (4 requirements)
- p00003: Separate Database Per Sponsor
- p00004: Immutable Audit Trail via Event Sourcing
- p00013: Complete Data Change History

#### Under p00010 (FDA Compliance)
- p00011: ALCOA+ Data Integrity Principles
- p00012: Clinical Data Retention Requirements
- p00016: Separation of Identity and Clinical Data
- p00020: System Validation and Traceability
- p01020: Privacy Policy and Regulatory Compliance Documentation
- p01025: Third-Party Timestamp Attestation

#### Under p00048 (Operations)
- p01021: Service Availability Commitment
- p01022: Incident Severity Classification
- p01023-p01038: SLA-related requirements

## Gap Analysis Summary

### High-Priority Gaps Identified

1. **Missing Compliance Requirements**
   - GDPR formalization (mentioned but no dedicated PRD)
   - HIPAA formalization (mentioned but no dedicated PRD)
   - SOC 2 Type II requirements
   - ISO 27001 alignment

2. **Missing System Components**
   - Diary Auth Service (mentioned in dev but no PRD)
   - Sponsor Portal Routing Service (implicit but not formalized)
   - EDC Integration Service (architecture only)
   - API Gateway / Reverse Proxy specification

3. **Incomplete Hierarchy Chains**
   - Event sourcing requirements too granular for PRD level
   - Missing ops-level database requirements
   - Security requirements fragmented across multiple files

### Recommended Future Requirements

| Priority | New Requirement | Suggested File |
| -------- | --------------- | -------------- |
| HIGH | GDPR Compliance | prd-compliance-gdpr.md |
| HIGH | HIPAA Compliance | prd-compliance-hipaa.md |
| HIGH | EDC Integration | prd-edc-integration.md |
| HIGH | Auth Service | prd-diary-web-auth.md |
| MEDIUM | Sponsor Routing | prd-services-sponsor-routing.md |
| MEDIUM | API Gateway | prd-api-gateway.md |
| MEDIUM | IRT Integration | prd-portal-irt-integration.md |

## Verification

### Index Regenerated
```
Total: 224 requirements parsed
- PRD: 91 requirements
- OPS: 67 requirements
- DEV: 66 requirements
```

### Traceability Report Generated
HTML report available at build time via:
```bash
python3 tools/requirements/generate_traceability.py --format html
```

## Research Sources

This reorganization was informed by:
- [FDA 21 CFR Part 11 guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [EMA Guidelines on Computerised Systems](https://www.ema.europa.eu/en/documents/regulatory-procedural-guideline/guideline-computerised-systems-and-electronic-data-clinical-trials_en.pdf)
- [CDISC Traceability Standards](https://www.cdisc.org/video/traceability)
- [Requirements Traceability Best Practices](https://www.jamasoftware.com/requirements-management-guide/requirements-traceability/four-best-practices-for-requirements-traceability/)

## Next Steps

1. Address high-priority gaps (GDPR, HIPAA, Auth Service)
2. Reorganize event sourcing requirements to proper audience level
3. Create compliance traceability matrix
4. Document system boundaries and integration points
