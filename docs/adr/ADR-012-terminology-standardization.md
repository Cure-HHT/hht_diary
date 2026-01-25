# ADR-012: Terminology Standardization

**Date**: 2026-01-25
**Status**: Accepted

---

## Context

The codebase has inconsistent terminology across documentation:
- "Clinical Diary Platform" vs "Diary Platform" vs "Diary System"
- "HHT Diary" branding mixed with generic platform references
- Mixed capitalization ("diary platform" vs "Diary Platform")

The glossary (spec/prd-glossary.md) establishes guidance:
- Preferred: "Diary Platform" (the complete product)
- Avoid: "Clinical Diary Platform" (implies clinical trials are primary use case)

This inconsistency creates confusion about whether we're referring to the top-level product, a subsystem, or a disease-specific deployment.

---

## Decision

### 1. Platform vs System Distinction

| Term | Usage | Examples |
| --- | --- | --- |
| **"Diary Platform"** | Top-level product name | "The Diary Platform supports multi-sponsor..." |
| **"* System"** | Subsystems/components only | "Clinical Data Storage System", "Questionnaire System" |

**Rationale**: The glossary uses "Platform" for formal specs and requirements (51+ refs). "System" is reserved for components. This creates clear hierarchy: Platform > Systems > Components.

### 2. No HHT Branding in Generic Documentation

- **Keep "HHT"** only for disease-specific content:
  - NOSE-HHT (validated instrument name)
  - HHT Epistaxis terminology
  - HHT Quality of Life Questionnaire
  - Hereditary Hemorrhagic Telangiectasia definitions

- **Remove "HHT"** from platform branding:
  - "HHT Diary Platform" → "Diary Platform"
  - "HHT Diary app" → "Diary app"
  - Replace sponsor examples (CureHHT) with `<SPONSOR>` placeholders

**Rationale**: The platform is disease-agnostic infrastructure. Sponsor-specific branding should live in sponsor directories only.

### 3. Capitalization Standard

- **"Diary Platform"** (title case) - defined term per glossary
- **"Diary app"** or **"Diary application"** (app lowercase)
- NOT: "diary platform" (lowercase) or "DIARY PLATFORM" (all caps)

### 4. Forbidden Terms

| Forbidden | Replacement |
| --- | --- |
| "Clinical Diary Platform" | "Diary Platform" |
| "Clinical Diary System" | "Diary Platform" |
| "Diary System" (top-level) | "Diary Platform" |

**Exception**: "* System" is acceptable for subsystems (e.g., "Questionnaire System", "Storage System").

---

## Consequences

### Positive
- Clear hierarchy: Platform (product) > Systems (subsystems) > Components
- Platform documentation is disease-agnostic
- Consistent capitalization improves readability
- Sponsor isolation reinforced by removing HHT branding from core docs

### Negative
- ~35 files require terminology updates
- Team must learn the distinction between Platform and System usage
- Some historical references in git history will use old terminology

---

## Implementation

Files updated across:
- `spec/` - Formal requirements
- `docs/` - Implementation documentation and ADRs
- Root-level READMEs

Disease-specific HHT references preserved in:
- `spec/prd-epistaxis-terminology.md` - HHT-specific terminology
- `spec/prd-questionnaire-qol.md` - HHT Quality of Life
- `spec/prd-questionnaire-epistaxis.md` - NOSE-HHT instrument
- Glossary definitions of HHT-related terms

---

**Review History**:
- 2026-01-25: Accepted
