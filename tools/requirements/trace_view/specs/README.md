# trace_view Specifications

This directory contains formal requirements for the trace_view HTML generator refactoring and collaborative review system.

## Scope

These specifications define the requirements for:
1. Refactoring `trace_view/html/generator.py` from a 3,420-line monolithic class to a maintainable Jinja2-based template architecture
2. Adding a collaborative requirement review system with threaded comments, status workflows, and multi-user git-based synchronization

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

### HTML Generator (tv-p00001)

| File | Type | Description |
| ---- | ---- | ----------- |
| `tv-p00001-html-generator.md` | PRD | High-level HTML generation requirements |
| `tv-d00001-template-architecture.md` | Dev | Jinja2 template architecture |
| `tv-d00002-css-extraction.md` | Dev | CSS extraction and embedding |
| `tv-d00003-js-extraction.md` | Dev | JavaScript extraction and embedding |
| `tv-d00004-build-embedding.md` | Dev | Build-time asset embedding |
| `tv-d00005-test-format.md` | Dev | Test output format for elspais |

### Review System (tv-p00002)

| File | Type | Description |
| ---- | ---- | ----------- |
| `tv-p00002-review-system.md` | PRD | Collaborative requirement review system |
| `tv-d00010-review-data-models.md` | Dev | Thread, Comment, Position data models |
| `tv-d00011-review-storage.md` | Dev | Atomic JSON CRUD operations |
| `tv-d00012-position-resolution.md` | Dev | Position anchoring with drift handling |
| `tv-d00013-git-branches.md` | Dev | reviews/{package}/{user} branch management |
| `tv-d00014-review-api-server.md` | Dev | Flask API endpoints |
| `tv-d00015-status-modifier.md` | Dev | REQ status changes in spec files |
| `tv-d00016-js-integration.md` | Dev | JavaScript modules integration |

## Traceability

```
REQ-tv-p00001 (PRD: HTML Generator)
├── REQ-tv-d00001 (Template Architecture)
├── REQ-tv-d00002 (CSS Extraction)
├── REQ-tv-d00003 (JS Extraction)
├── REQ-tv-d00004 (Build Embedding)
└── REQ-tv-d00005 (Test Format)

REQ-tv-p00002 (PRD: Review System)
├── REQ-tv-d00010 (Data Models)
├── REQ-tv-d00011 (Storage Operations)
├── REQ-tv-d00012 (Position Resolution)
├── REQ-tv-d00013 (Git Branches)
├── REQ-tv-d00014 (API Server)
├── REQ-tv-d00015 (Status Modifier)
└── REQ-tv-d00016 (JS Integration)
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
