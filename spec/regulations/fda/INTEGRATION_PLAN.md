# FDA Regulation Integration Plan

## Overview

This document outlines the plan to integrate FDA 21 CFR Part 11 regulation requirements (REQ-p8xxxx series) into the main HHT Diary Platform requirement graph.

**Key Constraint**: FDA regulation files are PRIMARY SOURCES and SHALL NOT be modified. All integration is done by updating existing platform requirements to reference the regulation requirements.

## Current State

### FDA Regulation Requirements (Primary Sources)
Located in `spec/regulations/fda/`:

| File | Requirements | Description |
| ---- | ------------ | ----------- |
| `prd-fda-21-cfr-11.md` | REQ-p80001 - REQ-p80005 | Core FDA regulations and GCP consolidated requirements |
| `prd-fda-part11-domains.md` | REQ-p80010 - REQ-p80060 | Domain-specific controls (Records, Signatures, Audit Trails, etc.) |
| `dev-fda-part11-technical-controls.md` | REQ-d80011 - REQ-d80063 | Technical implementation requirements |
| `ops-fda-part11-SOPs.md` | REQ-o80010 - REQ-o80030 | Operational SOP requirements |

### Existing Platform FDA Requirements
Located in main `spec/` directory:

| Requirement | Title | Current Implementation |
| ----------- | ----- | ---------------------- |
| REQ-p00010 | FDA 21 CFR Part 11 Compliance | 19 assertions, implements REQ-p00044 |
| REQ-p00011 | ALCOA+ Data Integrity Principles | 15 assertions, implements REQ-p00010 |
| REQ-p00004 | Immutable Audit Trail via Event Sourcing | 18 assertions |
| REQ-p00013 | Complete Data Change History | 51 assertions |

## Integration Strategy

### Phase 1: Link Platform PRD to FDA Regulations

Update existing platform requirements to `Implements:` or `Refines:` FDA regulation assertions.

#### REQ-p00010 (FDA 21 CFR Part 11 Compliance)
**Current**: Implements REQ-p00044
**Update to**: Implements REQ-p00044, REQ-p80002

Assertion mappings:
- p00010-A → Implements REQ-p80002 (general compliance)
- p00010-B → Implements REQ-p80002-PC-G (validation requirement)
- p00010-C → Implements REQ-p80002-A (accurate/complete copies)
- p00010-D → Implements REQ-p80002-B (record protection)
- p00010-E,F,G → Implements REQ-p80002-D (audit trails)
- p00010-H → Implements REQ-p80002-E (non-obscuring changes)
- p00010-I → Implements REQ-p80002-G (sequencing checks)
- p00010-J,K,L → Implements REQ-p80002-H (authority checks)
- p00010-M → Implements REQ-p80002-I (device checks)
- p00010-N,O → Implements REQ-p80002-Q,R,S,T (signature requirements)
- p00010-Q → Implements REQ-p80002-C,D (access controls)

#### REQ-p00011 (ALCOA+ Data Integrity Principles)
**Current**: Implements REQ-p00010
**Update to**: Implements REQ-p00010, REQ-p80005-A

The ALCOA+ requirement directly maps to GCP consolidated requirement REQ-p80005-A.

#### REQ-p00004 (Immutable Audit Trail)
**Update to**: Implements REQ-p80030

Maps to FDA Audit Trail Requirements (REQ-p80030).

#### REQ-p00013 (Complete Data Change History)
**Update to**: Implements REQ-p80030, REQ-p80040

Maps to both Audit Trail (p80030) and Data Correction Controls (p80040).

### Phase 2: Link Platform OPS to FDA Regulations

#### REQ-o00005 (Record Retention Procedures)
**Update to**: Implements REQ-o80020

#### REQ-o00041 (Compliance Monitoring)
**Update to**: Implements REQ-o80010

### Phase 3: Verify DEV Level Integration

The DEV-level FDA requirements (d80xxx) already correctly implement platform requirements:
- REQ-d80011 implements REQ-p00010 ✓
- REQ-d80063 implements REQ-p00010 ✓

Verify all other d80xxx requirements have proper implementations.

### Phase 4: Coverage Analysis

After integration, run coverage analysis to identify:
1. FDA regulation assertions with no platform implementation
2. Platform assertions not traced to FDA regulations
3. Gaps requiring new requirements

## Files to Modify

### Platform Requirements (to add FDA references)
1. `spec/prd-clinical-trials.md` - REQ-p00010, REQ-p00011, REQ-p00012
2. `spec/prd-database.md` - REQ-p00004, REQ-p00013
3. `spec/prd-security.md` - REQ-p00002 (MFA)
4. `spec/prd-security-RBAC.md` - REQ-p00005, REQ-p00014
5. `spec/ops-*.md` - Various operational requirements

### DO NOT Modify
- `spec/regulations/fda/*.md` - Primary sources, read-only
- `spec/regulations/fda/reference/*.pdf` - Source documents

## Execution Order

1. **Analyze** - Use elspais MCP to map all existing requirements to FDA assertions
2. **Document Gaps** - Create `FDA_SUGGESTIONS.md` with improvement notes
3. **Update PRD** - Modify platform PRD requirements to reference FDA
4. **Update OPS** - Modify platform OPS requirements to reference FDA
5. **Verify DEV** - Ensure DEV requirements are properly linked
6. **Validate** - Run elspais validation to confirm no errors
7. **Coverage Report** - Generate coverage report showing FDA traceability

## Success Criteria

- [ ] All platform FDA-related requirements reference appropriate FDA regulation assertions
- [ ] No validation errors in elspais
- [ ] Coverage report shows FDA requirement traceability
- [ ] `FDA_SUGGESTIONS.md` documents any gaps or improvements needed in regulation files
- [ ] No modifications to files in `spec/regulations/fda/`
