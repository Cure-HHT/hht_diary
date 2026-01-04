# trace_view Specifications

This directory contains formal requirements for the trace_view HTML generator refactoring.

## Scope

These specifications define the requirements for refactoring `trace_view/html/generator.py` from a 3,420-line monolithic class to a maintainable Jinja2-based template architecture.

## ID Convention

Requirements in this directory use a **local scope prefix** to distinguish them from main `spec/` requirements:

- **Format**: `REQ-tv-{p|d|o}{number}[-{assertion}]`
- **Prefix**: `tv-` (trace_view local scope)
- **Types**:
  - `p` = PRD (Product Requirements)
  - `d` = Dev (Development Specifications)
  - `o` = Ops (Operations Documentation)

**Examples**:
- `REQ-tv-p00001` - Product requirement for HTML generator
- `REQ-tv-d00003-B` - Assertion B of dev spec for JS extraction

## Specification Files

| File | Type | Description |
| ---- | ---- | ----------- |
| `tv-p00001-html-generator.md` | PRD | High-level HTML generation requirements |
| `tv-d00001-template-architecture.md` | Dev | Jinja2 template architecture |
| `tv-d00002-css-extraction.md` | Dev | CSS extraction and embedding |
| `tv-d00003-js-extraction.md` | Dev | JavaScript extraction and embedding |
| `tv-d00004-build-embedding.md` | Dev | Build-time asset embedding |
| `tv-d00005-test-format.md` | Dev | Test output format for elspais |

## Traceability

```
REQ-tv-p00001 (PRD: HTML Generator)
├── REQ-tv-d00001 (Template Architecture)
├── REQ-tv-d00002 (CSS Extraction)
├── REQ-tv-d00003 (JS Extraction)
├── REQ-tv-d00004 (Build Embedding)
└── REQ-tv-d00005 (Test Format)
```

## Standard Compliance

All specifications follow the `spec/requirements-spec.md` standard:

- Normative content uses **SHALL** language
- Assertions are labeled A-Z
- Each requirement has a content hash footer
- Rationale sections are non-normative

## Related Documents

- `/home/metagamer/.claude/plans/polymorphic-toasting-tiger.md` - Implementation plan
- `spec/requirements-spec.md` - Requirements specification standard
