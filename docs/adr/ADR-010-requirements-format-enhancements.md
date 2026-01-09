# ADR-010: Requirements Format Enhancements

**Date**: 2026-01-04
**Deciders**: Development Team
**Compliance**: FDA 21 CFR Part 11, Requirement Traceability

## Status

Accepted

---

## Context

The current assertion-based requirements format provides strong foundations:
- Clear separation between normative (Assertions) and informative (Rationale) content
- Labeled assertions (A, B, C...) enable precise traceability
- SHALL-based prescriptive language enforces testability
- Hash-based change detection provides tamper-evidence
- Three-tier hierarchy: PRD → OPS → DEV with `Implements:` references

However, gaps exist:
- **Cross-Cutting Concerns**: Security, compliance, multi-sponsor requirements scattered across files with no matrix view to see how functions span components
- **Verification Tracking**: No explicit field indicating how a requirement is validated; mix of testable requirements and declared axioms without distinction

Industry standards (IEEE 29148, EARS, INCOSE, Planguage, IEC 62304) were evaluated for potential enhancements.

---

## Decision

### 1. Add Type Field

Categorize requirements as artifacts (things) or functions (capabilities) to enable matrix views.

**Four Semantic Categories** (2 current, 2 reserved):

| Category | Status | Description | Allowed Synonyms |
| ---------- | -------- | ------------- | ------------------ |
| **Artifact** | Current | Instantiated, concrete things | `system`, `component`, `application`, `module`, `service` |
| **Function** | Current | Capabilities, characteristics | `feature`, `characteristic`, `capability`, `restriction`, `standard`, `regulation` |
| **Interface** | Reserved | Abstract definitions, not instantiated | TBD |
| **Constraint** | Reserved | Parameters separated from process | TBD |

**Matrix View Enabled**:
- Rows: Artifact-type requirements (system, component, ...)
- Columns: Function-type requirements (feature, regulation, ...)
- Cells: Child requirements that implement both an artifact AND a function

### 2. Add Validation Field (Optional)

Distinguish between testable requirements and declared axioms.

| Canonical | Synonyms | Status | Description |
| ----------- | ---------- | -------- | ------------- |
| `test` | `tested`, `testing` | Current | Verified through automated or manual testing |
| `inspect` | `inspected`, `inspection` | Current | Verified through document/code review |
| `analysis` | - | Reserved | Verified through static analysis, modeling |
| `demonstration` | - | Reserved | Verified through proof-of-concept |

**Default**: If validation is omitted, defaults to `test`. Most requirements are testable.

### 3. Bidirectional Traceability via Tooling

Two-way links in files are error-prone and create maintenance burden. Software can derive bidirectional views from one-way data.

- Files maintain one-way `Implements:` references (current approach)
- elspais generates reverse lookup tables at runtime
- Traceability views show both directions without file redundancy

### 4. Rejected Enhancements

| Enhancement | Decision | Rationale |
| ------------- | ---------- | ----------- |
| **Tags** | Omit | Type field handles cross-cutting via multi-parent Implements |
| **Priority** | Omit | All spec'd requirements are necessary; no decision value |
| **Risk** | Omit | Belongs in ADRs, applies to decisions not requirements |
| **EARS syntax** | Omit | Limited value; natural writing produces these patterns |
| **Planguage** | Omit | Verbosity harms readability |
| **Owner field** | Omit | Tracked in tickets/project management |

---

## Consequences

### Positive
- Matrix views enable cross-cutting concern visualization
- Validation field distinguishes testable from declared requirements
- Compact header format improves readability
- No file redundancy from bidirectional links
- Synonym support allows natural writing while enabling tooling

### Negative
- Existing requirements need backfilling with Type and Validation
- elspais tooling requires updates

### Neutral
- Reserved categories (Interface, Constraint) available for future needs
- Risk assessment continues to belong in ADRs

## References

### Industry Standards
- [IEEE SA - ISO/IEC/IEEE 29148-2018](https://standards.ieee.org/standard/29148-2018.html)
- [INCOSE Guide to Writing Requirements](https://www.incose.org/docs/default-source/working-groups/requirements-wg/rwg_products/incose_rwg_gtwr_summary_sheet_2022.pdf)

### Diagram Tools
- [PlantUML](https://plantuml.com/)
- [C4 Model with PlantUML](https://c4model.com/)

### Risk Management (for ADR context)
- [ISO 14971 - Medical Device Risk Management](https://www.iso.org/standard/72704.html)
- [FMEA Handbook](https://www.aiag.org/quality/automotive-core-tools/fmea)
